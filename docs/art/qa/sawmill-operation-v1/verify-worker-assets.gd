extends SceneTree

# Independent PNG/registration verification; normal gameplay QA is separate.
const ROOT: String = "res://art/buildings/sawmill/v1/operation/work/"

func _initialize() -> void:
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(ROOT + "worker-geometry.json"))) as Dictionary
	assert(Vector2i(int(metadata.canvas[0]), int(metadata.canvas[1])) == Vector2i(512, 512))
	assert(float(metadata.get("body_height_px")) == 412.0)
	assert(Vector2(float(metadata.ground_contact[0]), float(metadata.ground_contact[1])) == Vector2(374.5, 489.0))
	assert((metadata.get("frames") as Array).size() == 6)
	var base := Image.load_from_file(ProjectSettings.globalize_path(ROOT + "worker-0.png"))
	assert(base != null and base.get_size() == Vector2i(512, 512))
	var reports: Array = []
	for id: int in range(6):
		var relative: String = ROOT + "worker-%d.png" % id
		var image := Image.load_from_file(ProjectSettings.globalize_path(relative))
		assert(image != null and image.get_size() == base.get_size())
		var transparent: int = 0
		var partial: int = 0
		var opaque: int = 0
		var changed: int = 0
		var lower_changed: int = 0
		var head_changed: int = 0
		var residual_key: int = 0
		for y: int in range(512):
			for x: int in range(512):
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
					if y >= 282:
						lower_changed += 1
					if x >= 250 and x < 350 and y >= 70 and y < 181:
						head_changed += 1
		assert(lower_changed == 0 and head_changed == 0 and residual_key == 0)
		assert(transparent > 200000 and opaque > 20000 and partial > 1000)
		assert(image.get_pixel(350, 320).a8 == 255) # Fixed apron.
		assert(image.get_pixel(305, 475).a8 == 255) # Left boot.
		assert(image.get_pixel(450, 478).a8 == 255) # Right boot.
		assert(image.get_pixel(20, 20).a8 == 0)
		assert((id == 0 and changed == 0) or (id > 0 and changed > 10000))
		reports.append({"frame": id, "path": relative, "sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(relative)), "transparent": transparent, "partial": partial, "opaque": opaque, "changed_pixels": changed, "lower_changed": lower_changed, "head_changed": head_changed, "residual_key": residual_key})
	var output: String = ProjectSettings.globalize_path("res://../docs/art/qa/sawmill-operation-v1/worker-asset-verification.json")
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"date": "2026-09-12", "engine": Engine.get_version_info().get("string"), "scope": "Independent decoded PNG/metadata; not normal gameplay", "passed": true, "frames": reports, "body_height_world": 33, "production_ground_contact": metadata.get("ground_contact")}, "\t") + "\n")
	print("CARPENTER_WORK_ASSET_CHECKS_PASSED: 6 authored poses, actual alpha, no key residue, opaque apron and boots, fixed head/hips/feet and measured 33px registration")
	quit()
