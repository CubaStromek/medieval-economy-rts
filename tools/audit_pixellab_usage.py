#!/usr/bin/env python3
"""Audit saved PixelLab attempts without contacting the service.

Read ROOT/**/submitted.json, corresponding provenance/result/latest poll, and
ROOT/budget.json. Deduplicate server job IDs, include rejected art attempts,
and write ROOT/qa/cost-audit.json plus cost-audit.md. No media or auth values
are copied to the report. Global balance differences are not assigned to jobs.
"""

import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path


def read_json(path):
    return json.loads(path.read_text()) if path.exists() else {}


def usage_value(value):
    if not isinstance(value, dict):
        return None
    unit = value.get("type")
    key = {"generations": "generations", "usd": "usd"}.get(unit)
    amount = value.get(key) if key else None
    if not isinstance(amount, (int, float)) or not math.isfinite(amount) or amount < 0:
        return None
    # A generations record may have a USD field; it is not a conversion rate
    # or a second charge. Retain only the declared billing unit.
    return {"type": unit, key: amount}


def inspect_attempt(directory, root):
    submitted = read_json(directory / "submitted.json")
    provenance = read_json(directory / "provenance.json")
    result_path = directory / "result.json"
    latest_path = result_path
    if not result_path.exists():
        polls = sorted((directory / "polls").glob("*.json"))
        latest_path = polls[-1] if polls else directory / "submitted.json"
    latest = read_json(latest_path)
    last = latest.get("last_response") or {}
    job_id = submitted.get("background_job_id") or latest.get("id")
    endpoint = provenance.get("endpoint", "unknown")
    status = latest.get("status") or submitted.get("status")
    if status is None:
        if endpoint == "/remove-background" and isinstance(latest.get("image"), dict):
            status = "completed"
        elif submitted.get("transport_error"):
            status = "submission_uncertain"
        else:
            status = "submission_without_job_id"
    warnings = []
    if submitted.get("background_job_id") and latest.get("id") and submitted["background_job_id"] != latest["id"]:
        warnings.append("Submitted and returned job IDs disagree; inspect saved responses.")
    candidates = []
    billed = last.get("billing_charged")
    billing_usage = usage_value(last.get("billing_usage"))
    result_usage = usage_value(latest.get("usage"))
    last_usage = usage_value(last.get("usage"))
    if billing_usage and billed is True:
        candidates.append((3, "last_response.billing_usage; billing_charged=true", billing_usage))
    if result_usage and status == "completed" and billed is not False:
        candidates.append((2, "completed response.usage", result_usage))
    if last_usage and status == "completed" and billed is True:
        candidates.append((1, "completed last_response.usage; billing_charged=true", last_usage))
    chosen = max(candidates, key=lambda item: item[0]) if candidates else None
    if chosen:
        for _, source, value in candidates:
            if value["type"] == chosen[2]["type"] and value != chosen[2]:
                warnings.append(f"Billing figures disagree: {source}; higher-priority explicit charge used.")
    elif status == "completed":
        warnings.append("Completed attempt has no confirmed usage in saved fields; cost remains unknown.")
    relative = str(directory.relative_to(root))
    if job_id:
        operation_key = "job:" + job_id
    else:
        # Synchronous responses have no server job ID. Preserve that distinction
        # while deduplicating copied records with the same creation metadata.
        request_path = directory / "request.json"
        request_hash = hashlib.sha256(request_path.read_bytes()).hexdigest() if request_path.exists() else relative
        fingerprint = [provenance.get("created_at", relative), endpoint, request_hash]
        operation_key = "local:" + hashlib.sha256(json.dumps(fingerprint).encode()).hexdigest()[:24]
    reserve = provenance.get("budget", {}).get("reserve_generations", 0)
    if not isinstance(reserve, (int, float)) or not math.isfinite(reserve) or reserve < 0:
        reserve = 0
    return {"operation_key": operation_key, "job_id": job_id, "path": relative,
            "endpoint": endpoint, "created_at": provenance.get("created_at"), "status": status,
            "source_response": str(latest_path.relative_to(root)), "billing_charged": billed,
            "charge": chosen[2] if chosen else None, "charge_source": chosen[1] if chosen else None,
            "charge_evidence_priority": chosen[0] if chosen else 0,
            "reserve_generations": reserve, "warnings": warnings}


def audit(root):
    root = Path(root).resolve()
    groups = {}
    for submitted in sorted(root.rglob("submitted.json")):
        attempt = inspect_attempt(submitted.parent, root)
        groups.setdefault(attempt["operation_key"], []).append(attempt)
    operations = []
    status_priority = {"completed": 5, "failed": 4, "processing": 3,
                       "submission_uncertain": 2, "submission_without_job_id": 1}
    for copies in groups.values():
        best = max(copies, key=lambda item: (item["charge_evidence_priority"], status_priority.get(item["status"], 0)))
        record = dict(best)
        record["all_paths"] = sorted({item["path"] for item in copies})
        record["copy_count"] = len(copies)
        record["warnings"] = sorted({warning for item in copies for warning in item["warnings"]})
        confirmed_charges = {json.dumps(item["charge"], sort_keys=True) for item in copies if item["charge"]}
        if len(confirmed_charges) > 1:
            record["warnings"].append("Copies of this job report different charges; audit cannot reconcile them automatically.")
        operations.append(record)
    operations.sort(key=lambda item: (item["created_at"] or "", item["path"]))
    generations = sum(item["charge"].get("generations", 0) for item in operations if item["charge"])
    dollars = sum(item["charge"].get("usd", 0) for item in operations if item["charge"])
    pending = [item for item in operations if item["status"] == "processing"]
    pending_unbilled = [item for item in pending if not item["charge"]]
    reserved = sum(item["reserve_generations"] for item in pending_unbilled)
    budget = read_json(root / "budget.json")
    cap = budget.get("max_generations")
    unknown_completed = sum(item["status"] == "completed" and item["charge"] is None for item in operations)
    summary = {"unique_server_job_ids": len({item["job_id"] for item in operations if item["job_id"]}),
               "unique_operations_including_no_id_attempts": len(operations),
               "saved_submission_records": sum(item["copy_count"] for item in operations),
               "deduplicated_copies": sum(item["copy_count"] - 1 for item in operations),
               "operations_without_server_job_id": sum(not item["job_id"] for item in operations),
               "status_counts": dict(Counter(item["status"] for item in operations)),
               "confirmed_charged_generations": generations, "confirmed_charged_usd": dollars,
               "completed_operations_with_unknown_cost": unknown_completed,
               "pending_unbilled_reserve_generations": reserved, "production_cap_generations": cap,
               "generation_room_after_confirmed_charges": cap - generations if isinstance(cap, (int, float)) else None,
               "generation_room_after_confirmed_and_pending_reserves": cap - generations - reserved if isinstance(cap, (int, float)) else None}
    return {"created_at": datetime.now(timezone.utc).isoformat(), "root": str(root), "summary": summary,
            "method": ["Count each server job ID once, including all art attempts regardless of acceptance.",
                       "Prefer explicit billing_usage with billing_charged=true; corroborate with completed response.usage.",
                       "Global balance changes are not allocated to individual concurrent jobs.",
                       "USD totals use only explicitly USD-denominated usage; included generations are not converted to money.",
                       "Pending reserves are planning estimates, not charges or server-enforced price caps.",
                       "Uncertain submissions or missing usage may leave additional costs unknown."],
            "operations": operations}


def markdown(report):
    s = report["summary"]
    lines = ["# PixelLab · audit skutečné spotřeby", "", f"Vytvořeno {report['created_at']}.", "",
             f"- Unikátní serverové úlohy: **{s['unique_server_job_ids']}**.",
             f"- Stavy: {', '.join(f'{key}: {value}' for key, value in sorted(s['status_counts'].items()))}.",
             f"- Potvrzená spotřeba: **{s['confirmed_charged_generations']:g} zahrnutých generací**.",
             f"- Výslovně USD účtovaná spotřeba: **{s['confirmed_charged_usd']:g} USD**; cena předplatného se zde nepočítá.",
             f"- Rezervy nevyúčtovaných běžících úloh: {s['pending_unbilled_reserve_generations']:g} generací.",
             f"- Limit produkce: {s['production_cap_generations']}; prostor po potvrzených nákladech a rezervách: {s['generation_room_after_confirmed_and_pending_reserves']}.",
             f"- Dokončené úlohy s neznámou cenou: {s['completed_operations_with_unknown_cost']}; podání bez serverového ID: {s['operations_without_server_job_id']}.",
             "", "Zahrnuty jsou i výtvarně odmítnuté pokusy. Každé serverové ID se sčítá jen jednou. "
             "Poklesy globálního zůstatku se nepoužívají jako cena jednotlivých souběžných úloh. "
             "Nejasná podání a chybějící údaje mohou ponechat část nákladů neověřenou.", "",
             "| Pokus | Stav | Potvrzená spotřeba | Zdroj |", "|---|---|---:|---|"]
    for item in report["operations"]:
        charge = item["charge"]
        amount = (f"{charge.get('generations', charge.get('usd')):g} {'generací' if charge['type'] == 'generations' else 'USD'}"
                  if charge else "nepotvrzena")
        lines.append(f"| {item['path']} | {item['status']} | {amount} | {item['charge_source'] or '—'} |")
    warnings = [(item["path"], warning) for item in report["operations"] for warning in item["warnings"]]
    if warnings:
        lines.extend(["", "## Nejasnosti", ""])
        lines.extend(f"- {path}: {warning}" for path, warning in warnings)
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    args = parser.parse_args()
    report = audit(args.root)
    output = args.root.resolve() / "qa"
    output.mkdir(parents=True, exist_ok=True)
    (output / "cost-audit.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    (output / "cost-audit.md").write_text(markdown(report))
    print(json.dumps({"output": str(output), **report["summary"]}, indent=2))


if __name__ == "__main__":
    main()
