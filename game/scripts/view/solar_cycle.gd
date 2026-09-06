class_name SolarCycle
extends RefCounted

const DayCycle = preload("res://scripts/simulation/day_cycle.gd")

const SUNRISE_HOUR: float = 5.0
const SUNSET_HOUR: float = 20.0
const NIGHT_AMBIENT := Color(0.38, 0.46, 0.64)
const DAY_AMBIENT := Color(1.0, 0.98, 0.95)
const WARM_AMBIENT := Color(0.88, 0.48, 0.32)


# An art-directed light cycle, not an astronomical model. The saved simulation
# clock is its sole time source. Twilight deliberately spans the work/sleep
# boundary, so sunset cannot switch the map abruptly into its night palette.
# Callers may interpolate within one simulation tick, but own pause handling.
static func sample(simulation_tick: int, tick_fraction: float = 0.0) -> Dictionary:
	# Keep integer precision even for the largest supported saved tick values.
	var clock_tick: int = (maxi(0, simulation_tick) % DayCycle.TICKS_PER_DAY
		+ DayCycle.START_CLOCK_TICKS) % DayCycle.TICKS_PER_DAY
	var hour: float = fposmod(float(clock_tick) + clampf(tick_fraction, 0.0, 1.0),
		float(DayCycle.TICKS_PER_DAY)) * 24.0 / float(DayCycle.TICKS_PER_DAY)
	var sun_visible: bool = hour >= SUNRISE_HOUR and hour < SUNSET_HOUR
	var sun_progress: float = clampf((hour - SUNRISE_HOUR) / (SUNSET_HOUR - SUNRISE_HOUR), 0.0, 1.0)
	var elevation: float = maxf(0.0, sin(sun_progress * PI)) if sun_visible else 0.0
	var daylight: float = smoothstep(4.0, 7.0, hour) * (1.0 - smoothstep(18.0, 21.0, hour))
	var dawn_warmth: float = smoothstep(4.0, 5.5, hour) * (1.0 - smoothstep(5.5, 7.0, hour))
	var dusk_warmth: float = smoothstep(18.0, 19.5, hour) * (1.0 - smoothstep(19.5, 21.0, hour))
	var warmth: float = maxf(dawn_warmth, dusk_warmth)
	var ambient: Color = NIGHT_AMBIENT.lerp(DAY_AMBIENT, daylight).lerp(WARM_AMBIENT, warmth * 0.65)
	var sky_top: Color = Color(0.035, 0.065, 0.15).lerp(Color(0.16, 0.43, 0.66), daylight)
	sky_top = sky_top.lerp(Color(0.36, 0.19, 0.31), warmth * 0.45)
	var sky_horizon: Color = Color(0.13, 0.20, 0.32).lerp(Color(0.65, 0.83, 0.86), daylight)
	sky_horizon = sky_horizon.lerp(Color(0.98, 0.49, 0.23), warmth * 0.80)

	# Ground-space displacement per unit of object height, in grid cells. Avoid
	# physical tan(elevation), whose near-horizon shadows would cover the map.
	# A small southward offset keeps noon shadows legible in the top-down view.
	var shadow_vector := Vector2.ZERO
	if sun_visible:
		shadow_vector = Vector2(cos(sun_progress * PI) * (1.30 - 0.40 * elevation),
			0.16 + 0.25 * (1.0 - elevation))
	var shadow_opacity: float = 0.20 * smoothstep(0.0, 0.22, elevation)
	# The moon traverses the remaining nine hours; it is hidden by the caller
	# while the sun is visible, so its daytime progress has no visual meaning.
	var night_hour: float = hour + 24.0 if hour < SUNRISE_HOUR else hour
	var moon_progress: float = clampf((night_hour - SUNSET_HOUR) / 9.0, 0.0, 1.0)
	return {
		"sun_visible": sun_visible,
		"sun_progress": sun_progress,
		"elevation": elevation,
		"daylight": daylight,
		"ambient": ambient,
		"shadow_vector": shadow_vector,
		"shadow_opacity": shadow_opacity,
		"moon_progress": moon_progress,
		"sky_top": sky_top,
		"sky_horizon": sky_horizon,
	}
