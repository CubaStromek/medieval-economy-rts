# Third-party notices and provenance

## Project-created artwork — publication 2026-09-12

The current runtime terrain atlas, lumber hut layers and lumberjack animation
atlases are project-created outputs. Their recorded inputs and transformations
are documented in `docs/modern-terrain-textures.md`,
`docs/art/briefs/lumber-hut-construction-v1.md`,
`docs/art/briefs/lumber-hut-stock-v1-integration.md` and
`docs/art/briefs/lumberjack-pixellab-game-v1-integration.md`.
The PixelLab production set derives from this project's own lumberjack master,
not original KaM sprite inputs.

`docs/art/` also preserves earlier own-character redraw experiments that used
external KaM motion references, with their individual provenance and rejection
records. They are not the production PixelLab set or an approved reference.
The preserved Meshy GLB is a static, unrigged project experiment, not a runtime
model. Generated outputs and provenance records are not a guarantee of exclusive
rights; do not infer rights to original game assets from this engine's license.

Source game files, their direct sprite exports, imported map data and original
reference screenshots remain in ignored external directories. Raw API transport
and account logs are also excluded. Local file paths or historical links to
those directories in research documents do not redistribute their contents.

## KaM Remake

- Project: KaM Remake
- Repository: <https://github.com/reyandme/kam_remake>
- Reference commit: `a3b3e5268e1475460e4561f9143df6f1a532e681`
- Snapshot inspected: 2026-08-23
- License: GNU Affero General Public License v3.0
- Copyright: retained by the KaM Remake contributors

KaM Remake is used as a technical reference to understand system
responsibilities, economic rules, pathfinding, worker tasks, persistence and
deterministic multiplayer. Medieval Economy RTS is a new Godot/GDScript
implementation, not a build or modification of the Delphi project and not a
line-by-line translation.

The ignored `reference/kam_remake/` directory is a local, unmodified clone and
is not part of this repository's tracked source. Consult the upstream
repository for its full notices and history.

## Knights and Merchants assets

No original executable, source code, graphics, music, sound, map or campaign is
distributed with this public source. Optional local map imports, their source
binaries and converted data stay in ignored external directories. “Knights and Merchants” is used only to identify the reference game.
This project is unofficial and is not endorsed by the original rightsholders.

The terrain converter implements the documented binary layout and uses terrain
kind/tree-ID format tables from the KaM Remake reference above. Original game
maps retain their own asset rights; an engine license does not license those
maps. See [Mountainous Region provenance](docs/mountainous-region.md).

The optional graphics sandbox reimplements the reference terrain projection,
tile rotations and interpolated height-lighting rules in Godot. Its local
original texture atlas, cropped maps, object-position fixtures and screenshots
remain in ignored `game/external_assets/` directories and are not published.
The optional displayed tree art is this project's existing prototype artwork,
not original KaM tree sprites. See
[graphics sandbox provenance and limitations](docs/terrain-graphics-sandbox.md).
