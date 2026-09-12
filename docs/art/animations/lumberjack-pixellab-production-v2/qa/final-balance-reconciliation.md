# Final balance reconciliation — 2026-09-10

The final read-only `/balance` response reports an active Tier 2 Pixel Artisan
subscription with **4,440 of 5,000 included generations remaining**, and
**USD 0.00 credit balance**. The balance request used the existing local relay;
no key was copied, logged or passed in a command argument. The relay was left
running for the parent task to close later.

The production baseline was 5,000 included generations. Its final decrease
of **560** exactly matches the individual charge records for **55 unique,
completed jobs**, including rejected artwork and repair attempts. There are
no pending reserves and no completed jobs with unknown costs. The declared
800-generation production cap therefore has **240 generations unused**.

The job ledger records **USD 0 separately metered usage**. This does not mean
the paid subscription was free; the subscription purchase is outside this
generation-usage ledger. Included generations were not converted into dollars.
The complete balance decrease corroborates the job ledger; concurrent balance
changes were not assigned as the prices of individual jobs.

Evidence: `final-balance.json`, `final-balance-reconciliation.json`, and the
hashed `cost-audit.json` referenced by the reconciliation.
