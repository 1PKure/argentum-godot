extends SceneTree

var checks := 0
var failures := 0
var registries: Array[Node] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_profiles()
	_test_distribution()
	_test_melee()
	_test_arrows()
	_test_magic()
	_test_bot_movement()
	_test_semi_magic()
	for registry in registries:
		registry.queue_free()
	await process_frame
	print("Physical avoidance checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)


func _fixture(outcome: String = "hit") -> Dictionary:
	var registry = load("res://tests/physical_avoidance_probe.gd").new()
	root.add_child(registry)
	registries.append(registry)
	registry.forced_outcome = outcome
	registry._physical_rng.seed = 1
	var attacker: PlayerState = registry.add_player(501)
	var target: PlayerState = registry.add_player(502)
	attacker.grid_position = Vector2i(4, 5)
	attacker.facing_direction = MovementRules.Direction.EAST
	target.grid_position = Vector2i(5, 5)
	return {"registry": registry, "attacker": attacker, "target": target}


func _test_profiles() -> void:
	for id: int in ClassCatalog.all_ids():
		var equipped := ClassCatalog.default_equipment(id)
		var profile := ClassCatalog.get_equipped_profile(id, equipped)
		_check(int(profile.evasion_percent) > 0 and int(profile.evasion_percent) <= 14, "Class%d has a bounded real evasion chance" % id)
		var shield_percent := int(profile.shield_block_percent)
		_check((shield_percent > 0) == equipped.has("shield"), "Class%d blocks only with its legal equipped shield" % id)
		equipped.erase("shield")
		_check(int(ClassCatalog.get_equipped_profile(id, equipped).shield_block_percent) == 0, "Class%d immediately loses block chance when its shield is removed" % id)
	var mage := ClassCatalog.default_equipment(1)
	mage.shield = 2933
	_check(not ClassCatalog.has_legal_shield(1, mage) and int(ClassCatalog.get_equipped_profile(1, mage).shield_block_percent) == 0, "An injected silver shield cannot grant a mage an illegal block")
	var warrior := ClassCatalog.default_equipment(3)
	warrior.shield = 1719
	_check(not ClassCatalog.has_legal_shield(3, warrior) and int(ClassCatalog.get_equipped_profile(3, warrior).shield_block_percent) == 0, "A foreign class shield does not grant block chance")
	warrior = ClassCatalog.default_equipment(3)
	_check(ClassCatalog.has_legal_shield(3, warrior) and int(ClassCatalog.get_equipped_profile(3, warrior).shield_block_percent) == 15, "The warrior's equipped legal shield restores its fifteen-percent second roll")
	_check(ClassCatalog.physical_avoidance_outcome(3, warrior, 0, 0) == "evaded", "Evasion resolves before the shield roll")
	_check(ClassCatalog.physical_avoidance_outcome(3, warrior, 100, 0) == "blocked", "Shield blocking is available after evasion fails")
	_check(ClassCatalog.physical_avoidance_outcome(3, warrior, 12, 15) == "hit", "Exact percentage boundaries do not add an extra chance point")
	_check(ClassCatalog.physical_avoidance_outcome(1, ClassCatalog.default_equipment(1), 100, 0) == "hit", "A mage cannot block even with a zero shield roll")


func _test_distribution() -> void:
	var registry = load("res://server/systems/player_registry.gd").new()
	root.add_child(registry)
	registries.append(registry)
	var target: PlayerState = registry.add_player(601)
	for id: int in ClassCatalog.all_ids():
		registry.try_select_class(601, id, 10000)
		registry._physical_rng.seed = 0xC0FFEE + id
		var observed := {"hit": 0, "evaded": 0, "blocked": 0}
		for sample in range(10000):
			observed[registry._roll_physical_outcome(target)] += 1
		var profile := ClassCatalog.get_equipped_profile(id, target.equipped_items)
		var evasion := float(profile.evasion_percent)
		var block := (1.0 - evasion / 100.0) * float(profile.shield_block_percent)
		_check(absf(float(observed.evaded) / 100.0 - evasion) < 1.3, "Class%d seeded server rolls reproduce its evasion rate" % id)
		_check(absf(float(observed.blocked) / 100.0 - block) < 1.3, "Class%d shield rate is conditional on a failed evade" % id)
		print("Class%d sample10000: evaded%d blocked%d hit%d" % [id, observed.evaded, observed.blocked, observed.hit])


func _test_melee() -> void:
	for outcome: String in ["hit", "evaded", "blocked"]:
		var f := _fixture(outcome)
		var registry = f.registry
		var attacker: PlayerState = f.attacker
		var target: PlayerState = f.target
		var events: Array[Dictionary] = []
		registry.basic_attack_resolved.connect(func(event: Dictionary) -> void: events.append(event))
		attacker.is_meditating = true
		target.is_meditating = true
		var health := target.current_health
		_check(registry.try_basic_attack(501, 10000) == target and events.size() == 1, "Melee %s remains a successfully resolved physical action" % outcome)
		_check(events[0].outcome == outcome and int(events[0].amount) == health - target.current_health, "Melee %s replicates its authoritative outcome and actual health delta" % outcome)
		_check((target.current_health < health) == (outcome == "hit"), "Melee %s changes health only on a hit" % outcome)
		_check(target.is_meditating and not attacker.is_meditating, "Melee %s preserves target meditation while stopping the attacker's meditation" % outcome)
		var after := target.current_health
		_check(registry.try_basic_attack(501, 11199) == null and events.size() == 1 and target.current_health == after, "Melee %s still consumes the full physical cooldown" % outcome)
		_check(not registry.try_cast_spell(501, 1, target.grid_position, 1, 10599).ok, "Melee %s preserves attack-to-spell timing" % outcome)
		attacker.current_health = 100
		_check(not registry.try_recovery_action(501, "health_potion", 1, 10599).ok, "Melee %s preserves attack-to-potion timing" % outcome)
		_check(registry.try_basic_attack(501, 11200) == target and events.size() == 2, "Melee %s allows exactly one new action at its normal boundary" % outcome)


func _test_arrows() -> void:
	for outcome: String in ["hit", "evaded", "blocked"]:
		var f := _fixture(outcome)
		var registry = f.registry
		registry.try_select_class(501, 8, 10000)
		var target: PlayerState = f.target
		var health := target.current_health
		var result: Dictionary = registry.try_ranged_attack(501, target.grid_position, 1, 10000)
		_check(result.ok and result.event.outcome == outcome, "Arrow %s is accepted with its authoritative outcome" % outcome)
		_check(int(result.event.amount) == health - target.current_health and ((int(result.event.amount) > 0) == (outcome == "hit")), "Arrow %s does not synthesize damage on avoidance" % outcome)
		var after := target.current_health
		_check(not registry.try_ranged_attack(501, target.grid_position, 2, 11199).ok and target.current_health == after, "Arrow %s retains its full cooldown even with zero damage" % outcome)
		_check(not registry.try_ranged_attack(501, target.grid_position, 1, 11200).ok, "Arrow %s cannot be replayed after its interval" % outcome)
		_check(registry.try_ranged_attack(501, target.grid_position, 3, 11200).ok, "Arrow %s becomes available at the unchanged interval" % outcome)


func _test_magic() -> void:
	var f := _fixture("blocked")
	var registry = f.registry
	registry.try_select_class(502, 3, 10000)
	var target: PlayerState = f.target
	var before := target.current_health
	var result: Dictionary = registry.try_cast_spell(501, 51, target.grid_position, 1, 10000)
	_check(result.ok and target.current_health < before and registry.outcome_rolls == 0, "Magic bypasses physical evasion and shield block rolls")


func _test_bot_movement() -> void:
	var f := _fixture()
	var registry = f.registry
	var human: PlayerState = f.attacker
	var bot: PlayerState = f.target
	bot.is_bot = true
	human.grid_position = Vector2i(4, 5)
	bot.grid_position = Vector2i(10, 5)
	registry._last_move_time[501] = 1000
	registry._last_move_time[502] = 1000
	_check(registry.try_move_player(502, MovementRules.Direction.EAST, 1111) == null, "Bot movement rejects one millisecond before its bounded tolerance")
	_check(registry.try_move_player(502, MovementRules.Direction.EAST, 1112) == bot and registry._last_move_time[502] == 1132, "Bot movement uses its own132 ms authoritative interval")
	_check(registry.try_move_player(501, MovementRules.Direction.EAST, 1112) == null, "A human cannot use the bot's slightly faster movement interval")
	_check(registry.try_move_player(501, MovementRules.Direction.EAST, 1120) == human and registry._last_move_time[501] == 1140, "Human movement retains its unchanged140 ms cadence")
	_check(registry.try_move_player(502, MovementRules.Direction.WEST, 1112) == null, "Faster bot movement cannot stack two turns at the same clock")
	for interval: int in [MovementRules.MOVE_INTERVAL_MSEC, MovementRules.PRACTICE_BOT_MOVE_INTERVAL_MSEC]:
		var accepted := 0
		var last := 1000
		for now in range(1001, 15001):
			if MovementRules.is_move_ready(now, last, interval):
				accepted += 1
				last = MovementRules.get_accepted_move_time(now, last, interval)
		_check(accepted <= 14000 / interval + 1 and last == 1000 + accepted * interval, "Interval%d has no cumulative acceleration under one-millisecond spam" % interval)


func _test_semi_magic() -> void:
	for class_id: int in [4, 7, 12]:
		var profile := ClassCatalog.get_profile(class_id)
		_check(ClassCatalog.can_cast(class_id, 51) and ClassCatalog.combat_book_ids(class_id).has(51) and int(profile.bindings[2]) == 51, "Semimagical class%d gets Descarga in its book and default damage macro" % class_id)
		var f := _fixture()
		f.registry.try_select_class(501, class_id, 10000)
		_check(f.registry.try_cast_spell(501, 51, f.target.grid_position, 1, 10000).ok and f.attacker.current_mana == f.attacker.max_mana - 460, "Semimagical class%d uses the same real Descarga cost" % class_id)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + message)
