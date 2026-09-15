extends SceneTree

# Technical extraction only: use the actual production reader's role region.
# Run: godot --headless --path game --script ../docs/art/sources/carpenter-rest-v1/extract-current-carpenter.gd
const UnitSprites = preload("res://scripts/view/unit_sprite_library.gd")

func _initialize() -> void:
	var output: String = ProjectSettings.globalize_path("res://../docs/art/sources/carpenter-rest-v1")
	DirAccess.make_dir_recursive_absolute(output)
	var library = UnitSprites.new()
	var texture: AtlasTexture = library.texture_for("carpenter") as AtlasTexture
	assert(texture != null)
	var source: Image = texture.atlas.get_image()
	if source.is_compressed():
		source.decompress()
	var region := Rect2i(texture.region)
	var native: Image = source.get_region(region)
	assert(native.save_png(output + "/current-carpenter-native.png") == OK)
	var cell_region: Rect2i = library.atlas_cell_region("carpenter")
	assert(source.get_region(cell_region).save_png(output + "/current-carpenter-atlas-cell.png") == OK)
	var reference: Image = native.duplicate()
	reference.resize(native.get_width() * 2, native.get_height() * 2, Image.INTERPOLATE_NEAREST)
	assert(reference.save_png(output + "/current-carpenter-reference-2x.png") == OK)
	var world_size: Vector2 = library.sprite_size("carpenter")
	var record: Dictionary = {
		"date": "2026-09-12",
		"scope": "Technical extraction of existing original carpenter; no art changes",
		"reader": "game/scripts/view/unit_sprite_library.gd",
		"source": "game/art/units/civilians-basic-v1.png",
		"source_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path("res://art/units/civilians-basic-v1.png")),
		"role": "carpenter",
		"atlas_cell_region": [cell_region.position.x, cell_region.position.y, cell_region.size.x, cell_region.size.y],
		"actual_texture_region": [region.position.x, region.position.y, region.size.x, region.size.y],
		"alpha_threshold_for_region": 0.10,
		"native_canvas": [native.get_width(), native.get_height()],
		"world_size": [world_size.x, world_size.y],
		"native_sha256": FileAccess.get_sha256(output + "/current-carpenter-native.png"),
		"reference_2x_sha256": FileAccess.get_sha256(output + "/current-carpenter-reference-2x.png"),
		"enlargement": "2x nearest-neighbor only, no retouch or generated artwork",
		"normal_game_verified": false,
	}
	var file := FileAccess.open(output + "/current-carpenter-extraction.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "\t") + "\n")
	print(JSON.stringify(record))
	quit()
