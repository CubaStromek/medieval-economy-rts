extends RefCounted

const FORMAT: String = "kam-graphics-sandbox-v1"
const DEFAULTS: Dictionary = {
	"patch": 0, "comparison": 2, "textures": true, "lighting": true,
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
	if DEFAULTS[key] is bool:
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
	reset()
	for key: Variant in document["settings"]:
		if key is String:
			set_value(key, document["settings"][key])
	return true
