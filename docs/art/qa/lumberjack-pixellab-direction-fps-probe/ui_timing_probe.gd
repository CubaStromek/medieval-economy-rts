extends SceneTree
const Preview = preload("res://tools/preview_pixellab_lumberjack.tscn")
func _initialize() -> void:
    _run.call_deferred()
func _run() -> void:
    var view: Control = Preview.instantiate()
    root.add_child(view)
    view.set_process(false)
    view._elapsed_seconds = 0.35
    view._toggle_pause()
    view._process(0.5)
    var checks: Dictionary = {"mixed_pause_freezes_common_time": is_equal_approx(view._elapsed_seconds, 0.35)}
    view._step_frame()
    checks["step_uses_fastest_15fps"] = is_equal_approx(view._elapsed_seconds, 0.4000001)
    checks["stepped_S_frame4"] = view._library.frame_index("walk_axe", "S", view._elapsed_seconds) == 4
    checks["stepped_W_frame6"] = view._library.frame_index("walk_axe", "W", view._elapsed_seconds) == 6
    view._library.manifest["clips"]["walk_axe"]["rest_frame"] = 2
    view._show_rest()
    checks["rest_mode_enabled"] = view._at_rest
    checks["S_rest_frame2"] = view._library.frame_index("walk_axe", "S", view._elapsed_seconds, view._at_rest) == 2
    checks["W_rest_frame2"] = view._library.frame_index("walk_axe", "W", view._elapsed_seconds, view._at_rest) == 2
    view._toggle_pause()
    checks["resume_leaves_rest_mode"] = view._playing and not view._at_rest
    print(JSON.stringify(checks))
    quit(0 if checks.values().all(func(v: Variant) -> bool: return v == true) else 1)
