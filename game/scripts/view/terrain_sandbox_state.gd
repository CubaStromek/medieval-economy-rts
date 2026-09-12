extends RefCounted

const FORMAT: String = "kam-graphics-sandbox-v1"
const TEXTURE_PACKS: Array[String] = ["classic", "modern"]
const DEFAULTS: Dictionary = {
	"patch": 0, "comparison": 1, "texture_pack": "modern", "textures": true, "lighting": true,
	"light_strength": 1.0, "relief_scale": 1.0, "linear_filter": false,
	"trees": false, "shadows": false, "markers": false, "grid": false,
	"tree_scale": 1.0, "zoom": 1.0,
}
const RANGES: Dictionary = {
	"light_strength": Vector2(0, 1.5), "relief_scale": Vector2(0, 1.5),
	"tree_scale": Vector2(0.5, 1.5), "zoom": Vector2(0.5, 3),
}
var values: Dictionary = DEFAULTS.duplicate(true)

func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		return
	if key == "texture_pack":
		if value is String and value in TEXTURE_PACKS:
			values[key] = value
	elif DEFAULTS[key] is bool:
		if value is bool:
			values[key] = value
	elif RANGES.has(key):
		if (value is float or value is int) and is_finite(float(value)):
			var limits: Vector2 = RANGES[key]
			values[key] = clampf(float(value), limits.x, limits.y)
	elif (value is float or value is int) and is_finite(float(value)) and float(value) == floorf(float(value)):
		values[key] = clampi(int(value), 0, 1 if key == "patch" else 2)

func reset() -> void:
	values = DEFAULTS.duplicate(true)

func snapshot() -> Dictionary:
	return {"format": FORMAT, "settings": values.duplicate(true)}

func restore(document: Variant) -> bool:
	if not document is Dictionary or document.get("format") != FORMAT or not document.get("settings") is Dictionary:
		return false
	var settings: Dictionary = document["settings"]
	if settings.has("texture_pack"):
		var texture_pack: Variant = settings["texture_pack"]
		if not texture_pack is String or texture_pack not in TEXTURE_PACKS:
			return false
	reset()
	# v1 presets saved before texture packs existed used the original atlas.
	if not settings.has("texture_pack"):
		values["texture_pack"] = "classic"
	for key: Variant in settings:
		if key is String:
			set_value(key, settings[key])
	return true
