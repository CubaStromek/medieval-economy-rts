extends SceneTree

# Independent Godot PNG decoder verification, not a native gameplay render.
const ROOT: String = "res://art/buildings/sawmill/v1/life/"

func _initialize() -> void:
	var base := Image.load_from_file(ProjectSettings.globalize_path(ROOT + "resting_carpenter.png"))
	assert(base != null and base.get_size() == Vector2i(256, 256))
	var reports: Dictionary = {}
	for id: String in ["left", "center", "right"]:
		var relative: String = ROOT + "look/" + id + ".png"
		var image := Image.load_from_file(ProjectSettings.globalize_path(relative))
		assert(image != null and image.get_size() == base.get_size())
		var same_body: bool = true
		var same_feet: bool = true
		var changed: int = 0
		var transparent: int = 0
		var partial: int = 0
		var opaque: int = 0
		var residual_key: int = 0
		for y: int in range(256):
			for x: int in range(256):
				var pixel: Color = image.get_pixel(x, y)
				if pixel.a8 == 0:
					transparent += 1
				elif pixel.a8 == 255:
					opaque += 1
				else:
					partial += 1
				if pixel.a8 > 25 and mini(pixel.r8, pixel.b8) - pixel.g8 > 45:
					residual_key += 1
				if pixel != base.get_pixel(x, y):
					changed += 1
					if y >= 79:
						same_body = false
					if y >= 160:
						same_feet = false
		assert(same_body and same_feet and residual_key == 0)
		assert(transparent > 59000 and opaque > 4500 and partial > 1000)
		assert(image.get_pixel(128, 112).a8 == 255) # Positive torso control.
		assert(image.get_pixel(134, 203).a8 == 255) # Positive sole control.
		assert(image.get_pixel(64, 64).a8 == 0)
		assert((id == "center" and changed == 0) or (id != "center" and changed > 800))
		reports[id] = {
			"path": relative,
			"sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(relative)),
			"changed_pixels_from_base": changed,
			"same_body_y_ge_79": same_body,
			"same_feet_y_ge_160": same_feet,
			"transparent": transparent, "partial": partial, "opaque": opaque,
			"residual_key_pixels_dominance_gt45_alpha_gt25": residual_key,
			"positive_controls": {"torso_128_112": true, "sole_134_203": true},
		}
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(ROOT + "resting_carpenter.json"))) as Dictionary
	assert(float(metadata.get("production_body_height_px", 0.0)) == 165.0)
	assert(metadata.get("production_ground_contact") == [133.02734375, 205.1171875])
	assert(is_equal_approx(float(metadata.get("recommended_source_px_to_world", 0.0)), 0.2))
	var output: String = ProjectSettings.globalize_path("res://../docs/art/qa/carpenter-rest-v1/asset-verification.json")
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"date": "2026-09-12", "engine": Engine.get_version_info().get("string"), "scope": "Independent decoded PNG/metadata, not rendering or normal game", "passed": true, "frames": reports, "body_height_world": 33, "production_ground_contact": metadata.get("production_ground_contact")}, "\t") + "\n")
	print("CARPENTER_ASSET_CHECKS_PASSED: 3 poses, actual alpha, empty background, opaque body/sole positive controls, unchanged torso/boots, own 33px registration")
	quit()
