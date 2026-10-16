extends SceneTree

var checks := 0
var failures := 0
var registries: Array[Node] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_potions()
	_test_attacks()
	_test_casts()
	_test_combinations()
	for registry in registries:
		registry.queue_free()
	await process_frame
	print("Action interval checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)


func _fixture() -> Dictionary:
	var registry = load("res://server/systems/player_registry.gd").new()
	root.add_child(registry)
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
	var early: Dictionary = registry.try_recovery_action(901, "mana_potion", 2, 10329)
	_check(not early.ok and player.current_mana == 2000, "Switching color cannot drink one millisecond before 330 ms")
	_check(registry.try_recovery_action(901, "mana_potion", 3, 10330).ok and player.current_mana == 2150, "Blue potion is accepted exactly at the new 330 ms boundary")
	_check(not registry.try_recovery_action(901, "mana_potion", 3, 10660).ok and player.current_mana == 2150, "Shorter intervals cannot replay the same potion request")
	_check(registry.try_recovery_action(901, "health_potion", 4, 10660).ok and player.current_health == 154, "Shared cooldown permits the next color at the next 330 ms boundary")


func _test_attacks() -> void:
	var f := _fixture()
	var registry = f.registry
	var target: PlayerState = f.target
	_check(registry.try_basic_attack(901, 10000) == target and target.current_health == 494, "First mage attack applies the equipped armor profile")
	_check(registry.try_basic_attack(901, 10649) == null and target.current_health == 494, "Physical attack rejects one millisecond before 650 ms")
	_check(registry.try_basic_attack(901, 10650) == target and target.current_health == 488, "Physical attack is accepted exactly at the new 650 ms boundary")
	_check(f.attacker.current_mana == 2000, "Faster physical attacks never consume mana")


func _test_casts() -> void:
	var f := _fixture()
	var registry = f.registry
	var target: PlayerState = f.target
	_check(registry.try_cast_spell(901, 1, target.grid_position, 1, 10000).ok, "First spell resolves normally")
	var health_before: int = target.current_health
	var early: Dictionary = registry.try_cast_spell(901, 1, target.grid_position, 2, 11099)
	_check(not early.ok and early.remaining_msec == 1 and target.current_health == health_before and f.attacker.current_mana == 1990, "A cast one millisecond early reports the remaining wait without cost or damage")
	_check(registry.try_cast_spell(901, 1, target.grid_position, 3, 11100).ok and f.attacker.current_mana == 1980, "Spell repetition is accepted at 1100 ms rather than the previous 1230 ms")
	_check(not registry.try_cast_spell(901, 1, target.grid_position, 3, 12200).ok and f.attacker.current_mana == 1980, "Faster spells cannot replay a successful request")
	var periodic: Dictionary = registry.try_cast_spell(901, 268, f.attacker.grid_position, 4, 13000)
	_check(periodic.ok, "Dart's spell ID cannot accidentally lock Restoration's distinct shared group")
	var repeat: Dictionary = registry.try_cast_spell(901, 268, f.attacker.grid_position, 5, 14100)
	_check(not repeat.ok and repeat.remaining_msec > 0, "An individual spell cooldown remains in force after the faster global interval")
	var shared: Dictionary = registry.try_cast_spell(901, 269, f.attacker.grid_position, 6, 15000)
	_check(not shared.ok and shared.remaining_msec > 0, "Switching Restoration variants cannot bypass their actual shared cooldown")
	_check(registry.try_cast_spell(901, 268, f.attacker.grid_position, 7, 43000).ok, "Restoration becomes available at its unchanged thirty-second boundary")


func _test_combinations() -> void:
	var f := _fixture()
	var registry = f.registry
	var target: PlayerState = f.target
	registry.try_basic_attack(901, 10000)
	var early: Dictionary = registry.try_cast_spell(901, 1, target.grid_position, 1, 10699)
	_check(not early.ok and early.remaining_msec == 1 and f.attacker.current_mana == 2000, "Attack-to-spell rejects one millisecond before 700 ms")
	_check(registry.try_cast_spell(901, 1, target.grid_position, 2, 10700).ok, "Attack-to-spell accepts exactly at 700 ms")
	var health_before: int = target.current_health
	_check(registry.try_basic_attack(901, 11399) == null and target.current_health == health_before, "Spell-to-attack rejects one millisecond before 700 ms")
	_check(registry.try_basic_attack(901, 11400) == target, "Spell-to-attack accepts exactly at 700 ms")
	_check(not registry.try_recovery_action(901, "health_potion", 1, 12099).ok and f.attacker.current_health == 100, "Attack-to-potion rejects one millisecond before 700 ms")
	_check(registry.try_recovery_action(901, "health_potion", 2, 12100).ok and f.attacker.current_health == 127, "Attack-to-potion accepts exactly at 700 ms")
	_check(registry.try_cast_spell(901, 1, target.grid_position, 3, 12100).ok, "Using a potion does not add a new potion-to-spell lock")
	_check(registry.try_recovery_action(901, "mana_potion", 3, 12430).ok, "Casting does not add a new spell-to-potion lock")
	f = _fixture()
	registry = f.registry
	registry.try_recovery_action(901, "health_potion", 1, 10000)
	_check(registry.try_basic_attack(901, 10000) == f.target, "Existing potion-to-attack behavior is preserved")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + message)
