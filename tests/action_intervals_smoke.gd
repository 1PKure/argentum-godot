extends SceneTree

var checks := 0
var failures := 0
var registries: Array[Node] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_potions()
	_test_attacks()
	_test_arrows()
	_test_casts()
	_test_combinations()
	_test_click_use()
	for registry in registries:
		registry.queue_free()
	await process_frame
	print("Action interval checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)


func _fixture() -> Dictionary:
	var registry = load("res://tests/physical_avoidance_probe.gd").new()
	root.add_child(registry)
	registry.forced_outcome = "hit" # Cooldown fixture; real avoidance has dedicated seeded coverage.
	registries.append(registry)
	var attacker: PlayerState = registry.add_player(901)
	var target: PlayerState = registry.add_player(902)
	attacker.grid_position = Vector2i(4, 5)
	attacker.facing_direction = MovementRules.Direction.EAST
	target.grid_position = Vector2i(5, 5)
	attacker.current_health = 100
	attacker.current_mana = 2000
	return {"registry": registry, "attacker": attacker, "target": target}


func _test_potions() -> void:
	var f := _fixture()
	var registry = f.registry
	var player: PlayerState = f.attacker
	_check(registry.try_recovery_action(901, "health_potion", 1, 10000).ok and player.current_health == 127, "First red potion retains its original 27 HP gain")
	var early: Dictionary = registry.try_recovery_action(901, "mana_potion", 2, 10279)
	_check(not early.ok and player.current_mana == 2000, "Switching color cannot drink one millisecond before 280 ms")
	_check(registry.try_recovery_action(901, "mana_potion", 3, 10280).ok and player.current_mana == 2130, "Blue potion is accepted exactly at the new 280 ms boundary")
	_check(not registry.try_recovery_action(901, "mana_potion", 3, 10560).ok and player.current_mana == 2130, "Shorter intervals cannot replay the same potion request")
	_check(registry.try_recovery_action(901, "health_potion", 4, 10560).ok and player.current_health == 154, "Shared cooldown permits the next color at the next 280 ms boundary")


func _test_attacks() -> void:
	var f := _fixture()
	var registry = f.registry
	var target: PlayerState = f.target
	_check(registry.try_basic_attack(901, 10000) == target and target.current_health == 354, "First mage attack applies the equipped armor profile")
	_check(registry.try_basic_attack(901, 11199) == null and target.current_health == 354, "Physical attack rejects one millisecond before 1200 ms")
	_check(registry.try_basic_attack(901, 11200) == target and target.current_health == 353, "Physical attack is accepted exactly at the new 1200 ms boundary")
	_check(f.attacker.current_mana == 2000, "Physical attacks never consume mana")


func _test_arrows() -> void:
	# Both actors reach the same authority, with fresh nonces for every spammed RPC.
	for actor: int in [901, ArenaPracticeBot.BOT_ID]:
		var f := _fixture()
		var registry: PlayerRegistry = f.registry
		if actor != 901:
			registry.remove_player(901)
			registry.add_player(actor).is_bot = true
		registry.try_select_class(actor, 8, 10000)
		registry.get_player(actor).grid_position = Vector2i(4, 5)
		var target: PlayerState = f.target
		target.grid_position = Vector2i(6, 5)
		target.max_health = 10000
		target.current_health = 10000
		_check(registry.try_ranged_attack(actor, target.grid_position, 1, 10000).ok, "Hunter %d fires its first authoritative arrow" % actor)
		var health := target.current_health
		var early := registry.try_ranged_attack(actor, target.grid_position, 2, 11199)
		_check(not early.ok and early.remaining_msec == 1 and target.current_health == health, "Hunter %d rejects the 1199 ms boundary without damage" % actor)
		_check(registry.try_ranged_attack(actor, target.grid_position, 3, 11200).ok, "Hunter %d fires exactly at 1200 ms" % actor)
		health = target.current_health
		var accepted: Array[int] = []
		for index in range(2400):
			if index % 2 == 0:
				registry.try_basic_attack(actor, 11200 + index)
			if registry.try_ranged_attack(actor, target.grid_position, 4 + index, 11200 + index).ok:
				accepted.append(index)
		_check(accepted == [1200] and health - target.current_health >= 181 and health - target.current_health <= 200, "2400 fresh arrow requests plus legacy CTRL allow only one additional hit for hunter %d" % actor)
		_check(not registry.try_ranged_attack(actor, target.grid_position, 2403, 15000).ok, "Hunter %d cannot replay its latest arrow nonce after the interval" % actor)
	var fresh := _fixture()
	fresh.registry.try_select_class(901, 8, 0)
	_check(fresh.registry.try_ranged_attack(901, fresh.target.grid_position, 1, 0).ok, "A fresh hunter preset can fire immediately even at server startup")


func _test_casts() -> void:
	var f := _fixture()
	var registry = f.registry
	var target: PlayerState = f.target
	_check(registry.try_cast_spell(901, 1, target.grid_position, 1, 10000).ok, "First spell resolves normally")
	var health_before: int = target.current_health
	var early: Dictionary = registry.try_cast_spell(901, 1, target.grid_position, 2, 10949)
	_check(not early.ok and early.remaining_msec == 1 and target.current_health == health_before and f.attacker.current_mana == 1990, "A cast one millisecond early reports the remaining wait without cost or damage")
	_check(registry.try_cast_spell(901, 1, target.grid_position, 3, 10950).ok and f.attacker.current_mana == 1980, "Spell repetition is accepted at 950 ms rather than the previous 1000 ms")
	_check(not registry.try_cast_spell(901, 1, target.grid_position, 3, 12000).ok and f.attacker.current_mana == 1980, "Faster spells cannot replay a successful request")
	var periodic: Dictionary = registry.try_cast_spell(901, 268, f.attacker.grid_position, 4, 13000)
	_check(periodic.ok, "Dart's spell ID cannot accidentally lock Restoration's distinct shared group")
	var repeat: Dictionary = registry.try_cast_spell(901, 268, f.attacker.grid_position, 5, 14000)
	_check(not repeat.ok and repeat.remaining_msec > 0, "An individual spell cooldown remains in force after the faster global interval")
	var shared: Dictionary = registry.try_cast_spell(901, 269, f.attacker.grid_position, 6, 15000)
	_check(not shared.ok and shared.remaining_msec > 0, "Switching Restoration variants cannot bypass their actual shared cooldown")
	_check(registry.try_cast_spell(901, 268, f.attacker.grid_position, 7, 43000).ok, "Restoration becomes available at its unchanged thirty-second boundary")


func _test_combinations() -> void:
	var f := _fixture()
	var registry = f.registry
	var target: PlayerState = f.target
	registry.try_basic_attack(901, 10000)
	var early: Dictionary = registry.try_cast_spell(901, 1, target.grid_position, 1, 10599)
	_check(not early.ok and early.remaining_msec == 1 and f.attacker.current_mana == 2000, "Attack-to-spell rejects one millisecond before 600 ms")
	_check(registry.try_cast_spell(901, 1, target.grid_position, 2, 10600).ok, "Attack-to-spell accepts exactly at 600 ms")
	var health_before: int = target.current_health
	_check(registry.try_basic_attack(901, 11199) == null and target.current_health == health_before, "Spell-to-attack rejects one millisecond before 600 ms")
	_check(registry.try_basic_attack(901, 11200) == target, "Spell-to-attack accepts exactly at 600 ms")
	_check(not registry.try_recovery_action(901, "health_potion", 1, 11799).ok and f.attacker.current_health == 100, "Attack-to-potion rejects one millisecond before 600 ms")
	_check(registry.try_recovery_action(901, "health_potion", 2, 11800).ok and f.attacker.current_health == 127, "Attack-to-potion accepts exactly at 600 ms")
	_check(registry.try_cast_spell(901, 1, target.grid_position, 3, 11800).ok, "Using a potion does not add a new potion-to-spell lock")
	_check(registry.try_recovery_action(901, "mana_potion", 3, 12080).ok, "Casting does not add a new spell-to-potion lock")
	f = _fixture()
	registry = f.registry
	registry.try_recovery_action(901, "health_potion", 1, 10000)
	_check(registry.try_basic_attack(901, 10000) == f.target, "Existing potion-to-attack behavior is preserved")


func _test_click_use() -> void:
	var f := _fixture()
	var registry: PlayerRegistry = f.registry
	var player: PlayerState = f.attacker
	player.current_mana = 1000
	_check(registry.try_recovery_action(901, "health_potion", 1, 10000, "use").ok, "Use starts a normal potion lane")
	var health := player.current_health
	var early := registry.try_recovery_action(901, "mana_potion", 2, 10199, "click")
	_check(not early.ok and early.remaining_msec == 1 and player.current_mana == 1000, "Click cannot bypass the common floor one millisecond early")
	_check(registry.try_recovery_action(901, "mana_potion", 3, 10200, "click").ok, "A click can supplement Use at the explicit 200 ms combined boundary")
	_check(not registry.try_recovery_action(901, "health_potion", 4, 10280, "use").ok and player.current_health == health, "A ready Use lane still respects the last click's shared floor")
	_check(registry.try_recovery_action(901, "health_potion", 5, 10400, "direct").ok, "Direct hotkeys share the Use lane while alternating with click")
	_check(not registry.try_recovery_action(901, "health_potion", 6, 10600, "use").ok, "Q/E cannot create a third independent potion lane")
	_check(registry.try_recovery_action(901, "mana_potion", 7, 10600, "click").ok, "Switching color keeps click's own per-lane interval")
	_check(not registry.try_recovery_action(901, "health_potion", 7, 11000, "use").ok, "Switching lanes cannot replay a nonce")
	_check(not registry.try_recovery_action(901, "health_potion", 8, 11000, "extra").ok, "Unknown lanes cannot add potion capacity")
	# Compare equal windows with enough missing health to avoid clipping.
	var counts: Array[int] = []
	for combined in [false, true]:
		f = _fixture()
		registry = f.registry
		player = f.attacker
		player.max_health = 1000
		player.current_health = 100
		var accepted := 0
		for index in range(11):
			var channel := "click" if combined and index % 2 == 1 else "use"
			if registry.try_recovery_action(901, "health_potion", index + 1, 20000 + index * 200, channel).ok:
				accepted += 1
		counts.append(accepted)
	_check(counts[1] > counts[0] and counts[1] == 11, "Click plus Use is measurably faster in the same server-controlled window")
	registry.try_select_class(901, 1, 24000)
	player.current_health = 100
	_check(registry.try_recovery_action(901, "health_potion", 50, 24000, "click").ok, "Preset reset clears both potion lanes")
	registry.try_basic_attack(901, 25000)
	_check(not registry.try_recovery_action(901, "health_potion", 51, 25599, "use").ok, "Use does not bypass attack-to-potion")
	_check(registry.try_recovery_action(901, "health_potion", 52, 25600, "use").ok, "Use respects the same 600 ms attack gap")
	registry.remove_player(901)
	registry.add_player(901).current_health = 100
	_check(registry.try_recovery_action(901, "health_potion", 1, 25600, "click").ok, "Reconnect clears lane timers and request ownership")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + message)
