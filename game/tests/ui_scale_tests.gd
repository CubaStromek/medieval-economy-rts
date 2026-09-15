extends RefCounted

const UiScale = preload("res://scripts/view/ui_scale.gd")
const GameHudClass = preload("res://scripts/view/game_hud.gd")
const TEST_COUNT: int = 7


# The HUD must grow more slowly than the window, so a larger monitor buys map
# area instead of larger buttons. These are pure arithmetic checks on the
# policy; window_layout_tests covers the panels that consume it.
static func run() -> Array[String]:
	var failures: Array[String] = []
	_check_base_size(failures)
	_check_sublinear_growth(failures)
	_check_cap(failures)
	_check_small_windows(failures)
	_check_content_scale_factor(failures)
	_check_sidebar_share(failures)
	_check_apply(failures)
	return failures


static func _check_base_size(failures: Array[String]) -> void:
	_expect(is_equal_approx(UiScale.target_factor(UiScale.BASE_HEIGHT), 1.0),
		"The base 720-pixel window must render the HUD at its authored size", failures)
	_expect(is_equal_approx(UiScale.content_scale_factor(UiScale.BASE_HEIGHT), 1.0),
		"The base window must not need any extra content scaling", failures)


static func _check_sublinear_growth(failures: Array[String]) -> void:
	for height: float in [900.0, 1080.0, 1440.0, 2160.0]:
		var natural: float = UiScale.natural_factor(height)
		var target: float = UiScale.target_factor(height)
		_expect(target > 1.0 and target < natural,
			"A taller window must enlarge the HUD, but by less than the raw stretch would: %d" % int(height), failures)
		_expect(UiScale.logical_height(height) > UiScale.BASE_HEIGHT,
			"The saved scale must become extra logical height for the map: %d" % int(height), failures)


static func _check_cap(failures: Array[String]) -> void:
	_expect(UiScale.target_factor(4320.0) <= UiScale.MAX_FACTOR + 0.001,
		"HUD growth must stop at the documented maximum instead of tracking the window forever", failures)
	_expect(UiScale.target_factor(2160.0) >= 1.5,
		"A 4K window must still render text large enough to read, not pinned to base pixels", failures)


static func _check_small_windows(failures: Array[String]) -> void:
	# Below the base height the engine's own stretch already shrinks everything;
	# overriding it further would make the text unreadable.
	for height: float in [480.0, 600.0, 719.0]:
		_expect(is_equal_approx(UiScale.content_scale_factor(height), 1.0),
			"A window shorter than the base must keep the engine's own scale: %d" % int(height), failures)


static func _check_content_scale_factor(failures: Array[String]) -> void:
	for height: float in [900.0, 1080.0, 1440.0]:
		var combined: float = UiScale.content_scale_factor(height) * UiScale.natural_factor(height)
		_expect(is_equal_approx(combined, UiScale.target_factor(height)),
			"The stacked stretch and content factors must land exactly on the target scale: %d" % int(height), failures)


static func _check_sidebar_share(failures: Array[String]) -> void:
	# The sidebar is a fixed number of logical pixels, so its share of the
	# screen has to fall as the logical viewport grows.
	var base_share: float = GameHudClass.DOCK_WIDTH / (1152.0 / UiScale.target_factor(720.0))
	for size: Vector2 in [Vector2(1920.0, 1080.0), Vector2(2560.0, 1440.0)]:
		var logical_width: float = size.x / UiScale.target_factor(size.y)
		_expect(GameHudClass.DOCK_WIDTH / logical_width < base_share,
			"A larger monitor must leave the sidebar a smaller share of the width: %d" % int(size.x), failures)


# The policy must actually reach a window, and applying it twice must settle.
static func _check_apply(failures: Array[String]) -> void:
	var window := Window.new()
	window.size = Vector2i(1920, 1080)
	UiScale.apply(window)
	var applied: float = window.content_scale_factor
	_expect(is_equal_approx(applied, UiScale.content_scale_factor(1080.0)),
		"Applying the policy must set the window's content scale factor", failures)
	UiScale.apply(window)
	_expect(is_equal_approx(window.content_scale_factor, applied),
		"Re-applying at the same size must be a no-op", failures)
	window.size = Vector2i(1280, 720)
	UiScale.apply(window)
	_expect(is_equal_approx(window.content_scale_factor, 1.0),
		"Shrinking back to the base height must restore the unmodified scale", failures)
	UiScale.apply(null)
	window.free()


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
