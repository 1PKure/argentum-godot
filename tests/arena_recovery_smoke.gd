extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog = load("res://shared/gameplay/spell_catalog.gd")
	var rules = load("res://shared/gameplay/recovery_rules.gd")
	_check(catalog.all_ids().size() == 213, "Entire original catalog is parsed, including commented section headers")
	_check(catalog.loadout_ids().size() == 38, "Every enabled spell has a concrete PvP handler")
	_check(catalog.is_available(53) and catalog.get_spell(53).mana == 1000, "Apocalypse is usable with its original cost")
	_check(not catalog.is_available(7) and catalog.get_spell(7).unavailable_reason.contains("invocaciones"), "Summons disclose their missing subsystem")
	_check(not catalog.is_available(5) and not catalog.is_available(285), "NPC spells and recipes are not presented as executable PvP spells")
	_check(rules.get_potion("health_potion").min == 27 and rules.get_potion("mana_potion").percent == 5, "Potions are read from original OBJ38 and OBJ37 data")
	var registry = load("res://server/systems/player_registry.gd").new()
	root.add_child(registry)
	var caster = registry.add_player(701)
	var rival = registry.add_player(702)
	_check(caster.max_health == 355 and caster.max_mana == 2600, "Explicit test profile can fund the expensive original spells")
	caster.current_health = 263
	caster.current_mana = 2200
	var result: Dictionary = registry.try_recovery_action(701, "health_potion", 1, 10000)
	_check(result.ok and caster.current_health == 290 and caster.current_mana == 2200, "Red potion restores exactly 27 HP without touching mana")
	result = registry.try_recovery_action(701, "health_potion", 1, 11000)
	_check(not result.ok and caster.current_health == 290, "A repeated recovery request cannot restore twice")
	result = registry.try_recovery_action(701, "mana_potion", 2, 10100)
	_check(not result.ok and caster.current_mana == 2200, "Potion cooldown is shared across colors")
	result = registry.try_recovery_action(701, "mana_potion", 3, 10380)
	_check(result.ok and caster.current_mana == 2330, "Blue potion restores five percent of maximum mana")
	caster.current_mana = caster.max_mana - 10
	result = registry.try_recovery_action(701, "mana_potion", 4, 10760)
	_check(result.ok and caster.current_mana == 2600 and result.event.amount == 10, "Potion restoration clamps to maximum and reports actual gain")
	result = registry.try_recovery_action(701, "mana_potion", 5, 11140)
	_check(not result.ok, "Full-resource potion use is rejected")
	caster.current_mana = 2000
	result = registry.try_recovery_action(701, "meditate", 6, 12000)
	_check(result.ok and caster.is_meditating and caster.current_mana == 2000, "Meditation starts without an instant resource grant")
	registry.advance_runtime(13999)
	_check(caster.current_mana == 2000, "Meditation respects its two-second warmup")
	registry.advance_runtime(14000)
	_check(caster.current_mana == 2130, "Server grants the first meditation tick after warmup")
	registry.advance_runtime(14000)
	_check(caster.current_mana == 2130, "The same time cannot award duplicate meditation ticks")
	registry.advance_runtime(15000)
	_check(caster.current_mana == 2260, "Meditation advances on a one-second cadence")
	caster.apply_damage(1)
	registry.advance_runtime(17000)
	_check(not caster.is_meditating and caster.current_mana == 2260, "Damage interrupts meditation and prevents later regeneration")
	registry.try_recovery_action(701, "meditate", 7, 18000)
	registry._last_move_time[701] = -1000
	registry.try_move_player(701, 1)
	_check(not caster.is_meditating, "An accepted move interrupts meditation")
	caster.current_mana = 2000
	caster.current_health = 263
	registry.try_recovery_action(701, "meditate", 8, 19000)
	result = registry.try_recovery_action(701, "mana_potion", 9, 19500)
	_check(result.ok and caster.is_meditating and caster.current_mana == 2130, "Blue potion restores mana without interrupting meditation")
	result = registry.try_recovery_action(701, "health_potion", 10, 19880)
	_check(result.ok and caster.is_meditating and caster.current_health == 290, "Red potion restores health without interrupting meditation")
	result = registry.try_recovery_action(701, "health_potion", 11, 19900)
	_check(not result.ok and caster.is_meditating and caster.current_health == 290, "Meditation does not bypass the shared potion cooldown")
	registry.advance_runtime(20999)
	_check(caster.current_mana == 2130, "Drinking cannot grant an early meditation tick")
	registry.advance_runtime(21000)
	_check(caster.current_mana == 2260 and caster.is_meditating, "Drinking preserves the original meditation warmup and tick schedule")
	caster.current_mana = caster.max_mana - 1
	result = registry.try_recovery_action(701, "mana_potion", 12, 21380)
	_check(result.ok and caster.current_mana == 2600 and not caster.is_meditating, "A blue potion that fills mana ends meditation immediately")
	caster.current_mana = caster.max_mana - 1
	registry.try_recovery_action(701, "meditate", 13, 22000)
	registry.advance_runtime(24000)
	_check(caster.current_mana == 2600 and not caster.is_meditating, "Meditation stops automatically at full mana")
	caster.current_mana = caster.max_mana
	registry._last_spell_time[701] = -5000
	result = registry.try_cast_spell(701, 25, rival.grid_position, 1)
	_check(result.ok and rival.active_effects.has("Paralizado") and caster.current_mana == 2225, "Paralyze applies original cost and synchronized status")
	registry._last_move_time[702] = -1000
	var tile: Vector2i = rival.grid_position
	_check(registry.try_move_player(702, 3) != null and rival.grid_position == tile and rival.facing_direction == 3, "Paralysis blocks translation but permits an authoritative turn")
	registry._last_spell_time[702] = -5000
	result = registry.try_cast_spell(702, 27, rival.grid_position, 1)
	_check(result.ok and rival.active_effects.is_empty(), "A paralyzed player can cast Remove Paralysis on self")
	registry._last_move_time[702] = -1000
	_check(registry.try_move_player(702, 3) != null, "Movement resumes after removal")
	registry._last_spell_time[701] = -5000
	result = registry.try_cast_spell(701, 350, rival.grid_position, 2)
	var now := Time.get_ticks_msec()
	registry.advance_runtime(now + 5001)
	_check(result.ok and rival.active_effects.is_empty(), "Root duration expires according to the original five-second data")
	registry._last_spell_time[701] = -5000
	rival.current_health = 350
	result = registry.try_cast_spell(701, 268, rival.grid_position, 3)
	var before: int = rival.current_health
	registry.advance_runtime(Time.get_ticks_msec() + 3000)
	_check(result.ok and rival.current_health > before, "Restoration actually heals on its original EOT tick")
	registry._last_spell_time[701] = -5000
	result = registry.try_cast_spell(701, 268, rival.grid_position, 4)
	_check(not result.ok and result.remaining_msec > 0, "Per-spell cooldown survives clearing the global cast interval")
	registry._last_spell_time[702] = -5000
	rival.current_mana = rival.max_mana
	result = registry.try_cast_spell(702, 243, caster.grid_position, 2)
	before = caster.current_health
	registry.advance_runtime(Time.get_ticks_msec() + 1500)
	_check(result.ok and caster.current_health < before and caster.active_effects.has("Putrefacción"), "Putrefaction applies server-authoritative periodic damage")
	registry._last_spell_time[701] = -5000
	caster.current_mana = caster.max_mana
	result = registry.try_cast_spell(701, 263, caster.grid_position, 5)
	_check(result.ok and not caster.active_effects.has("Putrefacción"), "Blessing removes an actual negative effect")
	caster.apply_damage(10000)
	result = registry.try_recovery_action(701, "health_potion", 14, 25000)
	_check(not result.ok and caster.current_health == 0, "Ghosts cannot drink or gain health")
	result = registry.try_recovery_action(701, "respawn", 15, 26000)
	_check(result.ok and caster.is_alive and caster.current_health == 355 and caster.current_mana == 2600 and caster.active_effects.is_empty(), "Arena respawn resets real combat state")
	_check(registry._spell_cooldowns[701].is_empty(), "Arena respawn clears per-spell cooldowns for a fresh test round")
	_check(not registry.try_recovery_action(701, "respawn", 16, 27000).ok, "Living players cannot use respawn as a refill")
	var serialized: Dictionary = caster.to_dictionary()
	serialized.is_meditating = true
	serialized.active_effects = ["Inmovilizado"]
	var restored := PlayerState.from_dictionary(serialized)
	_check(restored.is_meditating and restored.active_effects.has("Inmovilizado"), "Recovery and statuses survive snapshot serialization")
	registry.queue_free()
	await process_frame
	print("Recovery/catalog checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + message)
