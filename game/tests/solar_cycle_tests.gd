extends RefCounted

const SolarCycle = preload("res://scripts/view/solar_cycle.gd")
const TEST_COUNT: int = 8


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_sun_tracks_civilian_day_boundaries,
		_test_shadow_tracks_sun_direction_and_height,
		_test_twilight_is_warm_and_night_remains_readable,
		_test_rendered_light_has_no_clock_boundary_jumps,
		_test_moon_crosses_midnight_without_reversing,
		_test_cycle_repeats_at_large_integer_ticks,
		_test_fractional_tick_interpolates_and_clamps,
		_test_full_cycle_stays_within_visual_limits,
	]:
		test.call(failures)
	return failures


static func _test_sun_tracks_civilian_day_boundaries(failures: Array[String]) -> void:
	var dawn: Dictionary = SolarCycle.sample(0)
	var noon: Dictionary = SolarCycle.sample(1875) # 12:30, midpoint of the 15-hour day.
	var sunset: Dictionary = SolarCycle.sample(3750)
	_check(dawn["sun_visible"] and is_zero_approx(dawn["sun_progress"])
		and is_zero_approx(dawn["elevation"]), "At 05:00 the sun must rise on the eastern horizon", failures)
	_check(noon["sun_visible"] and is_equal_approx(noon["sun_progress"], 0.5)
		and is_equal_approx(noon["elevation"], 1.0), "The sun must reach the top of its arc halfway through the working day", failures)
	_check(not sunset["sun_visible"] and is_equal_approx(sunset["sun_progress"], 1.0)
		and is_zero_approx(sunset["elevation"]), "At 20:00 the sun must disappear at the western horizon", failures)
	_check(not SolarCycle.sample(5999)["sun_visible"] and SolarCycle.sample(6000)["sun_visible"],
		"The next morning must begin at the same simulation boundary as the daily schedule", failures)


static func _test_shadow_tracks_sun_direction_and_height(failures: Array[String]) -> void:
	var morning: Vector2 = SolarCycle.sample(250)["shadow_vector"] # 06:00.
	var noon: Vector2 = SolarCycle.sample(1875)["shadow_vector"]
	var evening: Vector2 = SolarCycle.sample(3500)["shadow_vector"] # 19:00.
	_check(morning.x > 0.0 and evening.x < 0.0 and is_zero_approx(noon.x)
		and morning.y > 0.0 and noon.y > 0.0 and evening.y > 0.0,
		"Shadows must point away from the sun and rotate from right to left over the day", failures)
	_check(morning.length() > noon.length() * 4.0 and evening.length() > noon.length() * 4.0
		and is_equal_approx(morning.length(), evening.length()),
		"Low morning/evening sun must cast equal long shadows, while high sun casts short shadows", failures)
	_check(is_zero_approx(SolarCycle.sample(0)["shadow_opacity"])
		and is_zero_approx(SolarCycle.sample(3750)["shadow_opacity"])
		and is_equal_approx(SolarCycle.sample(1875)["shadow_opacity"], 0.20),
		"Sun shadows must fade out at both horizons and stay visible during the day", failures)


static func _test_twilight_is_warm_and_night_remains_readable(failures: Array[String]) -> void:
	var night: Color = SolarCycle.sample(4750)["ambient"]
	var dawn: Color = SolarCycle.sample(125)["ambient"]
	var dusk: Color = SolarCycle.sample(3625)["ambient"]
	var noon: Color = SolarCycle.sample(1875)["ambient"]
	_check(night.b > night.g and night.g > night.r and night.r >= 0.35,
		"Night must retain a readable blue ambient light instead of turning the map black", failures)
	_check(dawn.r > dawn.g and dawn.g > dawn.b and dusk.r > dusk.g and dusk.g > dusk.b,
		"Dawn and dusk must warm the map with an orange light", failures)
	_check(noon.r >= 0.95 and noon.g >= 0.95 and noon.b >= 0.90,
		"Full daylight must retain the original map colors near neutral white", failures)
	_check(SolarCycle.sample(4500)["ambient"] == night and SolarCycle.sample(5500)["ambient"] == night,
		"Deep night must keep a stable light baseline", failures)


static func _test_rendered_light_has_no_clock_boundary_jumps(failures: Array[String]) -> void:
	# Includes twilight edges, sunrise, named clock phases, sunset and midnight.
	for tick: int in [0, 250, 500, 3250, 3750, 4000, 4750, 5750, 6000]:
		var before: Dictionary = SolarCycle.sample((tick + 5999) % 6000, 0.999)
		var after: Dictionary = SolarCycle.sample(tick)
		for key: String in ["ambient", "sky_top", "sky_horizon"]:
			_check(_color_distance(before[key], after[key]) < 0.0001,
				"%s must remain continuous across boundary tick %d" % [key, tick], failures)
		_check(absf(float(before["daylight"]) - float(after["daylight"])) < 0.0001
			and absf(float(before["shadow_opacity"]) - float(after["shadow_opacity"])) < 0.0001,
			"Light and visible shadow intensity must not jump at tick %d" % tick, failures)


static func _test_moon_crosses_midnight_without_reversing(failures: Array[String]) -> void:
	_check(is_zero_approx(SolarCycle.sample(3750)["moon_progress"]),
		"The moon must start its night arc at 20:00", failures)
	var before: float = SolarCycle.sample(4749)["moon_progress"]
	var after: float = SolarCycle.sample(4750)["moon_progress"]
	_check(before < after and after - before < 0.001 and after > 0.40 and after < 0.50,
		"Midnight must continue the moon arc smoothly, without resetting or reversing it", failures)
	_check(float(SolarCycle.sample(5999)["moon_progress"]) > 0.999,
		"The moon must complete its journey just before the sun rises", failures)


static func _test_cycle_repeats_at_large_integer_ticks(failures: Array[String]) -> void:
	for tick: int in [0, 1875, 3750, 4750, 5999, 9007199254740991, 9223372036854775000]:
		var expected: Dictionary = SolarCycle.sample(tick % 6000, 0.375)
		_check(SolarCycle.sample(tick, 0.375) == expected,
			"A saved tick of %d must produce exactly the same lighting as its small cycle remainder" % tick, failures)
	_check(SolarCycle.sample(7500, 0.5) == SolarCycle.sample(1500, 0.5),
		"Repeating a full day must not change lighting or shadow placement", failures)


static func _test_fractional_tick_interpolates_and_clamps(failures: Array[String]) -> void:
	var start: Dictionary = SolarCycle.sample(300)
	var middle: Dictionary = SolarCycle.sample(300, 0.5)
	var end: Dictionary = SolarCycle.sample(301)
	_check(float(start["sun_progress"]) < float(middle["sun_progress"])
		and float(middle["sun_progress"]) < float(end["sun_progress"])
		and float(start["elevation"]) < float(middle["elevation"])
		and float(middle["elevation"]) < float(end["elevation"]),
		"Rendering between simulation ticks must move the sun forward smoothly", failures)
	_check(SolarCycle.sample(300, -1.0) == start and SolarCycle.sample(300, 2.0) == end,
		"Fractional rendering must clamp to the current and next simulation ticks", failures)
	_check(SolarCycle.sample(4749, 1.0) == SolarCycle.sample(4750)
		and SolarCycle.sample(-100) == SolarCycle.sample(0),
		"Interpolation must wrap correctly at midnight and negative elapsed time must clamp to the initial clock", failures)


static func _test_full_cycle_stays_within_visual_limits(failures: Array[String]) -> void:
	for tick: int in range(6000):
		var light: Dictionary = SolarCycle.sample(tick, 0.5)
		for key: String in ["sun_progress", "elevation", "daylight", "moon_progress"]:
			var value: float = light[key]
			if not is_finite(value) or value < 0.0 or value > 1.0:
				failures.append("%s escaped its normalized visual range at tick %d" % [key, tick])
				return
		for key: String in ["ambient", "sky_top", "sky_horizon"]:
			var color: Color = light[key]
			if color.r < 0.0 or color.r > 1.0 or color.g < 0.0 or color.g > 1.0 or color.b < 0.0 or color.b > 1.0 or color.a != 1.0:
				failures.append("%s escaped its opaque display color range at tick %d" % [key, tick])
				return
		var shadow: Vector2 = light["shadow_vector"]
		if shadow.length() > 1.4 or float(light["shadow_opacity"]) < 0.0 or float(light["shadow_opacity"]) > 0.20:
			failures.append("A shadow exceeded its readability limits at tick %d" % tick)
			return
		if not light["sun_visible"] and not is_zero_approx(light["shadow_opacity"]):
			failures.append("A sun shadow remained visible during night at tick %d" % tick)
			return


static func _color_distance(first: Color, second: Color) -> float:
	return Vector3(first.r - second.r, first.g - second.g, first.b - second.b).length()


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
