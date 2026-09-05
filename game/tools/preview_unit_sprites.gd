extends SceneTree

# Run with Godot's normal rendering driver (not --headless):
# godot --path game --script res://tools/preview_unit_sprites.gd -- --output=/absolute/path/unit-sprites.jpg
# This contact sheet uses the same imported textures and world-scale dimensions
# as the game. It never crops, edits, or rewrites the original sprite atlases.
const UnitSpriteLibraryClass = preload("res://scripts/view/unit_sprite_library.gd")
const DefinitionCatalogClass = preload("res://scripts/simulation/definition_catalog.gd")
const SHEET_SIZE: Vector2i = Vector2i(1440, 1000)
const SPRITE_SCALE: float = 3.0
const ROLE_COUNT: int = 29


class ContactSheet:
	extends Node2D

	const COLUMN_COUNT: int = 6
	const CELL_SIZE: Vector2 = Vector2(240, 200)
	const BACKGROUND: Color = Color("#17211e")
	const INK: Color = Color("#e9e9dc")
	const MUTED: Color = Color("#a0aba4")
	const SHADOW: Color = Color(0.02, 0.035, 0.025, 0.48)
	var sprite_library: UnitSpriteLibraryClass
	var roles: Array[String] = []
	var catalog: DefinitionCatalogClass

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(SHEET_SIZE)), BACKGROUND)
		var font: Font = ThemeDB.fallback_font
		for index: int in range(roles.size()):
			var column: int = index % COLUMN_COUNT
			var row: int = index / COLUMN_COUNT
			var cell_origin: Vector2 = Vector2(column, row) * CELL_SIZE
			var feet: Vector2 = cell_origin + Vector2(CELL_SIZE.x * 0.5, 153)
			var role: String = roles[index]
			var sprite: Texture2D = sprite_library.texture_for(role)
			var dimensions: Vector2 = sprite_library.sprite_size(role) * SPRITE_SCALE
			var mounted: bool = role in UnitSpriteLibraryClass.MOUNTED_ROLES
			var shadow_size: Vector2 = Vector2(36, 7) if mounted else Vector2(23, 5)
			draw_set_transform(feet + Vector2(0, 1), 0.0, shadow_size)
			draw_circle(Vector2.ZERO, 1.0, SHADOW)
			draw_set_transform(Vector2.ZERO)
			var sprite_rect: Rect2 = Rect2(feet - Vector2(dimensions.x * 0.5, dimensions.y), dimensions)
			draw_texture_rect(sprite, sprite_rect, false)
			var definition: Dictionary = catalog.unit(role)
			var label: String = String(definition.get("display_name", role.capitalize()))
			draw_string(font, cell_origin + Vector2(10, 184), label,
				HORIZONTAL_ALIGNMENT_CENTER, CELL_SIZE.x - 20, 15, INK)
		var last_cell: Vector2 = Vector2(5, 4) * CELL_SIZE
		draw_string(font, last_cell + Vector2(10, 98), "Basic sprites · 29 roles",
			HORIZONTAL_ALIGNMENT_CENTER, CELL_SIZE.x - 20, 15, INK)
		draw_string(font, last_cell + Vector2(10, 124), "3× game scale",
			HORIZONTAL_ALIGNMENT_CENTER, CELL_SIZE.x - 20, 15, MUTED)


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	var output: String = OS.get_temp_dir().path_join("unit-sprites-preview.jpg")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var extension: String = output.get_extension().to_lower()
	if not output.is_absolute_path() or extension not in ["jpg", "jpeg", "png"]:
		_fail("Preview output must be an absolute .jpg, .jpeg, or .png path: " + output)
		return
	if DisplayServer.get_name() == "headless":
		_fail("Sprite preview requires a real rendering driver. Run this command without --headless.")
		return
	var sprite_library := UnitSpriteLibraryClass.new()
	var roles: Array[String] = []
	roles.append_array(UnitSpriteLibraryClass.CIVILIAN_ROLES)
	roles.append_array(UnitSpriteLibraryClass.MILITARY_ROLES)
	if roles.size() != ROLE_COUNT:
		_fail("Expected 29 sprite roles, received %d." % roles.size())
		return
	var catalog := DefinitionCatalogClass.new()
	for role: String in roles:
		if not sprite_library.has_role(role) or sprite_library.texture_for(role) == null:
			_fail("Sprite missing for role '%s'. Import both authored atlases before rendering." % role)
			return
		if catalog.unit(role).is_empty():
			_fail("Sprite role has no matching unit definition: " + role)
			return
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	if directory_error != OK:
		_fail("Cannot create preview output directory: " + error_string(directory_error))
		return

	root.title = "Basic unit sprites — preview"
	root.size = Vector2i(1152, 800)
	var viewport := SubViewport.new()
	viewport.name = "UnitSpriteContactSheet"
	viewport.size = SHEET_SIZE
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sheet := ContactSheet.new()
	sheet.sprite_library = sprite_library
	sheet.roles = roles
	sheet.catalog = catalog
	sheet.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	viewport.add_child(sheet)
	var preview := TextureRect.new()
	preview.texture = viewport.get_texture()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(preview)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var result: Image = viewport.get_texture().get_image()
	if result == null or result.is_empty() or result.get_size() != SHEET_SIZE:
		_fail("Rendering did not return a complete 1440×1000 preview image.")
		return
	var save_error: Error = result.save_png(output) if extension == "png" else result.save_jpg(output, 0.95)
	if save_error != OK:
		_fail("Cannot save sprite preview: " + error_string(save_error))
		return
	print("UNIT SPRITE PREVIEW: %d roles, 1440×1000, 3× scale → %s" % [roles.size(), output])
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
