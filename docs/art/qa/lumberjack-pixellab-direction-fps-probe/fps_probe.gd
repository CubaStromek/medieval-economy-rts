extends SceneTree
const Library = preload("res://scripts/view/lumberjack_animation_library.gd")
var checks: Dictionary = {}
func _initialize() -> void:
    _run.call_deferred()
func _run() -> void:
    var library := Library.new()
    checks["loaded"] = library.load_manifest()
    checks["clip_fallback_12"] = library.fps("walk_axe") == 12.0
    checks["S_override_10"] = library.fps("walk_axe", "S") == 10.0
    checks["W_override_15"] = library.fps("walk_axe", "W") == 15.0
    checks["S_at_0_35_is_3"] = library.frame_index("walk_axe", "S", 0.35) == 3
    checks["W_at_0_35_is_5"] = library.frame_index("walk_axe", "W", 0.35) == 5
    checks["S_double_step_0_8_is_8"] = library.frame_index("walk_axe", "S", 0.8001) == 8
    checks["W_double_step_0_8_is_12"] = library.frame_index("walk_axe", "W", 0.8001) == 12
    checks["S_wrap_2_4"] = library.frame_index("walk_axe", "S", 2.4001) == 0
    checks["W_wrap_1_6"] = library.frame_index("walk_axe", "W", 1.6001) == 0
    var original: Dictionary = library.manifest.duplicate(true)
    var path: String = Library.MANIFEST_PATH.get_base_dir().path_join("probe-mutated.json")
    var no_override: Dictionary = original.duplicate(true)
    no_override["clips"]["walk_axe"]["directions"]["S"].erase("fps")
    save_json(path, no_override)
    checks["omitted_direction_falls_back"] = library.load_manifest(path) and library.fps("walk_axe", "S") == 12.0
    for invalid: Variant in [0, -1, "fast", null, true]:
        var data: Dictionary = original.duplicate(true)
        data["clips"]["walk_axe"]["directions"]["W"]["fps"] = invalid
        save_json(path, data)
        checks["reject_" + str(invalid)] = not library.load_manifest(path) and not library.errors.is_empty()
    var infinite: String = JSON.stringify(original).replace('"fps":15.0', '"fps":1e999').replace('"fps":15,', '"fps":1e999,')
    var handle := FileAccess.open(path, FileAccess.WRITE)
    handle.store_string(infinite)
    handle.close()
    checks["reject_non_finite"] = not library.load_manifest(path)
    checks["valid_reload"] = library.load_manifest()
    print(JSON.stringify(checks))
    quit(0 if checks.values().all(func(v: Variant) -> bool: return v == true) else 1)
func save_json(path: String, value: Dictionary) -> void:
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_string(JSON.stringify(value))
    file.close()
