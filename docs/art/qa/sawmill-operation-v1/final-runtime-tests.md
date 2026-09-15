# Sawmill operation runtime verification — 2026-09-12

The final imported operation assets passed the focused headless suite **20/20**,
the complete required headless suite **849/849**, and the focused native suite
**20/20** on Godot 4.7.2. All three commands exited successfully. Their complete
logs contain no `SCRIPT ERROR`, `ERROR:`,
`WARNING:`, failed cases or missing-resource messages.

| Verification | Actual evidence |
| --- | --- |
| Focused production state and art checks, 20 cases | [final-focused-headless.txt](final-focused-headless.txt) |
| Focused native art and actual framebuffer checks, 20 cases | [final-focused-native.txt](final-focused-native.txt) |
| Required complete game suite, 849 cases | [final-full-headless.txt](final-full-headless.txt) |
| All 11 final PNG hashes match the operation manifest | [final-asset-hashes.json](final-asset-hashes.json) |
| Earlier isolated state proof, 12 cases | [state-adapter-tests.md](state-adapter-tests.md) |

The final focused run adds actual imported-resource controls to the state
coverage: six distinct worker poses, shared textures and alpha masks, every
visible log/plank increment after foreground compositing, all 35 combined stock
states, a neutral backplate for unknown foreign buildings, truthful capacity
fallback labels, retained workpiece without a paused worker, stable authored
foot registration at 33 world pixels of body height, rejection of each missing
frame and malformed nested metadata, and real MainView working-carpenter hit
selection. Negative resource cases first prove the same actual assets load
through an independent valid manifest, so a broken positive path cannot pass
them accidentally.

The complete run also passed the existing sawmill sprite integration, generic
production-building home life, lumber-hut construction/stock/life, lumberjack
animation, fog, terrain, footprint, save, nutrition, production-chain and HUD
regressions. No additional runtime or simulation changes were needed after the
final focused and complete runs; repeating those covered regressions separately
would add no new coverage.

The native run used the Compatibility renderer on Apple M4, OpenGL 4.1 Metal.
It executed the framebuffer comparison that is conditionally skipped in
headless mode: several actual opaque carpenter pixels drawn in the normal
building painter row matched an independently unobstructed layer at the same
registration. The same normal MainView path also selected the real sawmill from
those working-carpenter pixels. The native result covers these automated pixel
checks; the separate visual QA record covers human inspection of motion and
the normal playable journey. The already-passed complete headless suite was
not repeated after the native run, and no artwork or runtime changes were
needed.
