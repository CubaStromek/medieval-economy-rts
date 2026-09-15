# Versioning and releases

Adopted on 2026-09-15 at the user's request, starting with release 0.6.0.
Tags `v0.1.0`–`v0.5.0` were added afterwards to the existing milestone commits.

## Version numbers

The project follows [Semantic Versioning](https://semver.org/) as a `0.y.z`
prototype:

- **Minor** (`0.y.0`) — a published milestone: new gameplay or artwork, removed
  mechanics, a save-format bump or other behavior players notice.
- **Patch** (`0.y.z`) — fixes and documentation on top of a release, with no new
  features and no save-format bump.
- **1.0.0** is reserved for the first release the user declares complete and
  playable end to end.

Before 1.0.0 a minor release may break compatibility. Its changelog entry must
say how, for example which saves migrate and what they lose.

The version appears in three places, which must agree:

| Where | Form |
|---|---|
| `game/project.godot` → `application/config/version` | `0.6.0` |
| `CHANGELOG.md` heading | `## [0.6.0] — 2026-09-15` |
| Annotated Git tag on the release commit | `v0.6.0` |

The save format has its own integer, `WorldSnapshot.SAVE_VERSION`, independent
of the game version. The changelog notes each release's save format.

## Changelog

[`CHANGELOG.md`](../CHANGELOG.md) follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Record every
user-visible change under `## [Unreleased]` in the same change that makes it,
grouped as Added, Changed, Deprecated, Removed or Fixed. Link the detailed
document instead of repeating it. Test counts and measurements belong in the
verification record and the dated test notes, not in changelog entries.

The dated sections of `README.md`, `tests/README.md` and `docs/` remain the
detailed history. The changelog is the index of what shipped in which release.

## Releasing

Releases, commits, tags and pushes happen only when the user asks for them
(see `AGENTS.md`). A release then follows these steps.

1. Run `git fetch origin`. `git rev-list --left-right --count HEAD...origin/main`
   must print `0 0`; otherwise integrate the newer remote work first.
2. Choose the version from the unreleased entries.
3. Run the checks from the repository root:

   ```sh
   ./tests/run-headless.sh
   godot --path game --audio-driver Dummy --windowed --resolution 1440x900 res://tests/refactor_runner.tscn
   node --test tools/export-painted-visual.test.cjs
   node --test tools/import-kam-terrain.test.cjs
   python3 -m unittest discover -s tools -p test_pixellab_client.py
   git diff --check
   ```

   The PixelLab client suite skips one case without Pillow; use a Python that
   has Pillow for the full run. Its tests mock the service and cost nothing.
4. Check publication hygiene before staging:
   - no original game data, and no byte-identical copies of the local external
     reference assets;
   - no credentials, tokens or signed URLs;
   - no file near GitHub's 100 MiB limit;
   - nothing that `.gitignore` keeps local. QA frame sequences in `frames/`,
     `motion/` and `*-motion/` stay local unless documentation references a
     frame, which is then added with `git add -f`.
5. Stage the release and test a clean copy made from the index:

   ```sh
   git checkout-index --all --prefix=/tmp/clean-copy/
   godot --headless --editor --path /tmp/clean-copy/game --import
   godot --headless --path /tmp/clean-copy/game --scene res://tests/test_runner.tscn
   ```

6. Write `docs/release-verification-YYYY-MM-DD.md`: version, baseline, commands,
   results, and anything skipped or not rerun.
7. Update the release documents:
   - move the `[Unreleased]` entries under `## [X.Y.Z] — YYYY-MM-DD`;
   - bump `config/version`;
   - archive the previous `HANDOVER.md` in `docs/handover-archive/` and refresh it;
   - update the README release summary.
8. Commit any uncommitted feature work first, then the release documents as
   `chore(release): X.Y.Z`.
9. Tag the release commit with
   `git tag -a vX.Y.Z -m "Medieval Economy RTS X.Y.Z"`.
10. Push the branch and the tag with `git push origin main vX.Y.Z`.
11. Publish a GitHub Release for the tag. Use the version's changelog section
    as the notes, with repository links made absolute and soft line breaks
    joined, because release notes render every newline:
    `gh release create vX.Y.Z --verify-tag --latest --title "Medieval Economy RTS X.Y.Z" --notes-file notes.md`.

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/) prefixes, as
the history already does: `feat:`, `fix:`, `perf:`, `docs:`, `test:`,
`refactor:` and `chore:`. The subject says what changed. The body lists notable
parts and any save migration.
