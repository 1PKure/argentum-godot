extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog = load("res://shared/gameplay/spell_catalog.gd")
	var rules = load("res://shared/gameplay/recovery_rules.gd")
	_check(catalog.all_ids().size() == 213, "Entire original catalog is parsed, including commented section headers")
	_check(catalog.loadout_ids().size() == 39, "Every enabled spell has a concrete PvP handler")
	_check(catalog.is_available(53) and catalog.get_spell(53).mana == 1000, "Apocalypse is usable with its original cost")
	_check(not catalog.is_available(7) and catalog.get_spell(7).unavailable_reason.contains("invocaciones"), "Summons disclose their missing subsystem")
	_check(not catalog.is_available(5) and not catalog.is_available(285), "NPC spells and recipes are not presented as executable PvP spells")
	_check(rules.get_potion("health_potion").min == 27 and rules.get_potion("mana_potion").percent == 5, "Potions are read from original OBJ38 and OBJ37 data")
	var registry = load("res://server/systems/player_registry.gd").new()
	root.add_child(registry)
	var caster = registry.add_player(701)
	var rival = registry.add_player(702)
	_check(caster.max_health == 500 and caster.max_mana == 3000, "Explicit test profile can fund the expensive original spells")
	caster.current_health = 400
	caster.current_mana = 2200
	var result: Dictionary = registry.try_recovery_action(701, "health_potion", 1, 10000)
	_check(result.ok and caster.current_health == 427 and caster.current_mana == 2200, "Red potion restores exactly 27 HP without touching mana")
	result = registry.try_recovery_action(701, "health_potion", 1, 11000)
	_check(not result.ok and caster.current_health == 427, "A repeated recovery request cannot restore twice")
	result = registry.try_recovery_action(701, "mana_potion", 2, 10100)
	_check(not result.ok and caster.current_mana == 2200, "Potion cooldown is shared across colors")
	result = registry.try_recovery_action(701, "mana_potion", 3, 10380)
	_check(result.ok and caster.current_mana == 2350, "Blue potion restores five percent of maximum mana")
	caster.current_mana = 2990
	result = registry.try_recovery_action(701, "mana_potion", 4, 10760)
	_check(result.ok and caster.current_mana == 3000 and result.event.amount == 10, "Potion restoration clamps to maximum and reports actual gain")
	result = registry.try_recovery_action(701, "mana_potion", 5, 11140)
	_check(not result.ok, "Full-resource potion use is rejected")
	caster.current_mana = 2000
	result = registry.try_recovery_action(701, "meditate", 6, 12000)
	_check(result.ok and caster.is_meditating and caster.current_mana == 2000, "Meditation starts without an instant resource grant")
	registry.advance_runtime(13999)
	_check(caster.current_mana == 2000, "Meditation respects its two-second warmup")
	registry.advance_runtime(14000)
	_check(caster.current_mana == 2150, "Server grants the first meditation tick after warmup")
	registry.advance_runtime(14000)
	_check(caster.current_mana == 2150, "The same time cannot award duplicate meditation ticks")
	registry.advance_runtime(15000)
	_check(caster.current_mana == 2300, "Meditation advances on a one-second cadence")
	caster.apply_damage(1)
	registry.advance_runtime(17000)
	_check(not caster.is_meditating and caster.current_mana == 2300, "Damage interrupts meditation and prevents later regeneration")
	registry.try_recovery_action(701, "meditate", 7, 18000)
	registry._last_move_time[701] = -1000
	registry.try_move_player(701, 1)
	_check(not caster.is_meditating, "An accepted move interrupts meditation")
	registry.try_recovery_action(701, "meditate", 8, 19000)
	registry.try_recovery_action(701, "mana_potion", 9, 19500)
	_check(not caster.is_meditating, "Drinking interrupts meditation")
	caster.current_mana = 2999
	registry.try_recovery_action(701, "meditate", 10, 21000)
	registry.advance_runtime(23000)
	_check(caster.current_mana == 3000 and not caster.is_meditating, "Meditation stops automatically at full mana")
	caster.current_mana = 3000
	registry._last_spell_time[701] = -5000
	result = registry.try_cast_spell(701, 25, rival.grid_position, 1)
	_check(result.ok and rival.active_effects.has("Paralizado") and caster.current_mana == 2625, "Paralyze applies original cost and synchronized status")
	registry._last_move_time[702] = -1000
	var tile: Vector2i = rival.grid_position
	_check(registry.try_move_player(702, 3) == null and rival.grid_position == tile, "Server rejects movement during paralysis")
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
	rival.current_mana = 3000
	result = registry.try_cast_spell(702, 243, caster.grid_position, 2)
	before = caster.current_health
	registry.advance_runtime(Time.get_ticks_msec() + 1500)
	_check(result.ok and caster.current_health < before and caster.active_effects.has("Putrefacción"), "Putrefaction applies server-authoritative periodic damage")
	registry._last_spell_time[701] = -5000
	caster.current_mana = 3000
	result = registry.try_cast_spell(701, 263, caster.grid_position, 5)
	_check(result.ok and not caster.active_effects.has("Putrefacción"), "Blessing removes an actual negative effect")
	caster.apply_damage(10000)
	result = registry.try_recovery_action(701, "health_potion", 11, 25000)
	_check(not result.ok and caster.current_health == 0, "Ghosts cannot drink or gain health")
	result = registry.try_recovery_action(701, "respawn", 12, 26000)
	_check(result.ok and caster.is_alive and caster.current_health == 500 and caster.current_mana == 3000 and caster.active_effects.is_empty(), "Arena respawn resets real combat state")
	_check(registry._spell_cooldowns[701].is_empty(), "Arena respawn clears per-spell cooldowns for a fresh test round")
	_check(not registry.try_recovery_action(701, "respawn", 13, 27000).ok, "Living players cannot use respawn as a refill")
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
