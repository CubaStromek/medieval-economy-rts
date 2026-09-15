class_name Nutrition
extends RefCounted

## Balance values in economy.json keep their historical "days" of 6,000 ticks
## (10 minutes at 1x). This is only a time unit: the game has no calendar.
const BALANCE_DAY_TICKS: int = 6000
const FIXED_SCALE: int = 1000


static func max_deficit_ticks(world: Variant) -> int:
	return maxi(1, int(world.catalog.economy.get("nutrition_survival_days", 7))) * BALANCE_DAY_TICKS


static func max_recovery_remainder(world: Variant) -> int:
	return _daily_food_value(world) - 1


# Satiety is a daily appetite, not a death countdown. Every unfed tick
# still counts toward starvation.
static func tick_needs(world: Variant, worker: Dictionary) -> bool:
	if not _needs_active(world, worker):
		return false
	var limit: int = max_deficit_ticks(world)
	worker["nutrition_deficit_ticks"] = mini(limit, int(worker.get("nutrition_deficit_ticks", 0)) + 1)
	var decay: int = int(worker.get("condition_decay_remainder", 0)) + decay_milli_per_tick(world, worker)
	@warning_ignore("integer_division")
	var loss: int = decay / FIXED_SCALE
	worker["condition_decay_remainder"] = decay % FIXED_SCALE
	worker["hunger"] = maxi(0, int(worker.get("hunger", 0)) - loss)
	return int(worker["nutrition_deficit_ticks"]) >= limit


static func decay_milli_per_tick(world: Variant, _worker: Dictionary = {}) -> int:
	var fraction: float = maxf(0.001, float(world.catalog.economy.get("condition_daily_hunger_fraction", 1.0)))
	# One balance day consumes the configured share of the hungry-to-full range
	# at a constant rate. Defaults yield exactly 390 milli-condition per tick,
	# the same daily appetite as the removed 15 h awake / 9 h asleep schedule.
	return maxi(1, roundi(float(_daily_food_value(world) * FIXED_SCALE) / (float(BALANCE_DAY_TICKS) * fraction)))


# Use the actual nutrition restored by a paid course, even above the satiety
# cap. Fractional debt recovery survives saves; a crumb never resets the timer.
static func restore_food(world: Variant, worker: Dictionary, amount: int) -> void:
	if amount <= 0:
		return
	var maximum: int = maxi(1, int(world.catalog.economy.get("condition_max", 2700)))
	worker["hunger"] = mini(maximum, int(worker.get("hunger", 0)) + amount)
	var denominator: int = _daily_food_value(world)
	var recovered: int = int(worker.get("nutrition_recovery_remainder", 0)) + amount * BALANCE_DAY_TICKS
	@warning_ignore("integer_division")
	var restored_ticks: int = recovered / denominator
	var remaining: int = maxi(0, int(worker.get("nutrition_deficit_ticks", 0)) - restored_ticks)
	worker["nutrition_deficit_ticks"] = remaining
	# A well-fed citizen cannot bank future immunity by repeatedly overeating.
	worker["nutrition_recovery_remainder"] = recovered % denominator if remaining > 0 else 0


static func work_efficiency_permille(world: Variant, worker: Dictionary) -> int:
	if not world.economy_enabled or not world.is_local_entity(worker):
		return FIXED_SCALE
	var start: int = maxi(0, int(world.catalog.economy.get("nutrition_weakening_start_days", 2))) * BALANCE_DAY_TICKS
	var finish: int = maxi(start + 1, int(world.catalog.economy.get("nutrition_weakening_full_days", 4)) * BALANCE_DAY_TICKS)
	var minimum: int = clampi(int(world.catalog.economy.get("nutrition_min_work_efficiency_permille", 800)), 1, FIXED_SCALE)
	var deficit: int = int(worker.get("nutrition_deficit_ticks", 0))
	if deficit <= start:
		return FIXED_SCALE
	if deficit >= finish:
		return minimum
	@warning_ignore("integer_division")
	var reduction: int = (deficit - start) * (FIXED_SCALE - minimum) / (finish - start)
	return FIXED_SCALE - reduction


# Call only for a tick of productive work, never for movement or deliveries.
static func allow_work_tick(world: Variant, worker: Dictionary) -> bool:
	if not world.economy_enabled:
		return true
	var effort: int = int(worker.get("work_effort_remainder", 0)) + work_efficiency_permille(world, worker)
	worker["work_effort_remainder"] = effort % FIXED_SCALE
	return effort >= FIXED_SCALE


static func status(world: Variant, worker: Dictionary) -> Dictionary:
	var maximum: int = maxi(1, int(world.catalog.economy.get("condition_max", 2700)))
	var condition: int = clampi(int(worker.get("hunger", 0)), 0, maximum)
	var hungry: int = clampi(int(world.catalog.economy.get("condition_hungry", 360)), 0, maximum)
	var warning: int = clampi(int(world.catalog.economy.get("condition_warning", 1350)), hungry, maximum)
	var limit: int = max_deficit_ticks(world)
	var deficit: int = clampi(int(worker.get("nutrition_deficit_ticks", 0)), 0, limit)
	var efficiency: int = work_efficiency_permille(world, worker)
	var state: String = "Fed"
	if deficit >= maxi(0, limit - BALANCE_DAY_TICKS):
		state = "Starving"
	elif efficiency < FIXED_SCALE:
		state = "Weakened"
	elif condition <= hungry:
		state = "Hungry"
	elif condition <= warning:
		state = "Getting hungry"
	var hungry_ticks: int = 0
	var starve_ticks: int = limit - deficit
	if condition > hungry:
		var rate: int = decay_milli_per_tick(world, worker)
		var remaining: int = (condition - hungry) * FIXED_SCALE - int(worker.get("condition_decay_remainder", 0))
		hungry_ticks = ceili(float(remaining) / float(rate)) if rate > 0 else -1
	if not _needs_active(world, worker):
		if hungry_ticks > 0:
			hungry_ticks = -1
		starve_ticks = -1
	return {
		"satiety_percent": 100.0 * float(condition) / float(maximum),
		"state": state,
		"hungry_at": hungry,
		"remaining_to_hungry_ticks": hungry_ticks,
		"remaining_to_starve_ticks": starve_ticks,
		"deficit_days": float(deficit) / float(BALANCE_DAY_TICKS),
		"work_efficiency_percent": float(efficiency) / 10.0,
		"seven_day_limit": float(limit) / float(BALANCE_DAY_TICKS),
	}


static func _daily_food_value(world: Variant) -> int:
	var maximum: int = maxi(1, int(world.catalog.economy.get("condition_max", 2700)))
	var hungry: int = clampi(int(world.catalog.economy.get("condition_hungry", 360)), 0, maximum)
	return maxi(1, maximum - hungry)


static func _needs_active(world: Variant, worker: Dictionary) -> bool:
	return world.economy_enabled and world.is_local_entity(worker) and int(worker.get("meal_ticks_left", 0)) == 0
