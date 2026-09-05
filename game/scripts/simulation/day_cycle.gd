class_name DayCycle
extends RefCounted

# Calendar policy for the existing saved simulation tick. A full 24-hour
# cycle lasts 600 simulation seconds; speed and pause only schedule ticks.
# Keep this mapping stable for v12 saves when adding configurable calendars.
const TICK_SECONDS: float = 0.1
const TICKS_PER_DAY: int = 6000
const MINUTES_PER_DAY: int = 1440
const START_CLOCK_TICKS: int = 1250 # Day 1, 05:00.


@warning_ignore("integer_division")
static func at_tick(simulation_tick: int) -> Dictionary:
	var elapsed: int = maxi(0, simulation_tick)
	# Reduce before multiplying so even large valid JSON save ticks stay exact.
	var shifted_tick: int = elapsed % TICKS_PER_DAY + START_CLOCK_TICKS
	var day: int = elapsed / TICKS_PER_DAY + shifted_tick / TICKS_PER_DAY + 1
	var minute_of_day: int = (shifted_tick % TICKS_PER_DAY) * MINUTES_PER_DAY / TICKS_PER_DAY
	return {
		"day": day,
		"hour": minute_of_day / 60,
		"minute": minute_of_day % 60,
		"phase": _phase_at_minute(minute_of_day),
	}


static func is_night(simulation_tick: int) -> bool:
	var clock_tick: int = (maxi(0, simulation_tick) % TICKS_PER_DAY + START_CLOCK_TICKS) % TICKS_PER_DAY
	return clock_tick < 1250 or clock_tick >= 5000


static func _phase_at_minute(minute: int) -> String:
	if minute < 300 or minute >= 1200:
		return "night"
	if minute < 360:
		return "dawn"
	if minute < 1080:
		return "day"
	return "dusk"
