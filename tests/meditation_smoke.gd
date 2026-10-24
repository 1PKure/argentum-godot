extends SceneTree

var checks := 0
var failures := 0
var registries: Array[Node] = []


func _initialize() -> void:
	call_deferred("_run")


func _fixture() -> Dictionary:
	var registry = load("res://server/systems/player_registry.gd").new()
	root.add_child(registry)
	registries.append(registry)
	var player: PlayerState = registry.add_player(701)
	var rival: PlayerState = registry.add_player(702)
	player.current_mana = 0
	player.current_health = 200
	return {"registry": registry, "player": player, "rival": rival}


func _run() -> void:
	var f := _fixture()
	var registry = f.registry
	var player: PlayerState = f.player
	_check(registry.try_recovery_action(701, "meditate", 1, 10000).ok and player.is_meditating and player.current_mana == 0, "Meditation begins immediately without an instant mana grant")
	registry.apply_damage(701, 1)
	_check(player.is_meditating and player.current_health == 199 and registry._next_meditation_tick[701] == 10500, "Living damage preserves meditation and its first500 ms deadline")
	registry.advance_runtime(10499)
	_check(player.current_mana == 0, "Meditation does not regenerate before the shorter warmup expires")
	registry.advance_runtime(10500)
	_check(player.current_mana == 130, "Mage receives its first130 mana after500 ms")
	registry.advance_runtime(10500)
	_check(player.current_mana == 130, "Reprocessing one clock cannot duplicate a meditation tick")
	registry.apply_damage(701, 1)
	registry.advance_runtime(10999)
	_check(player.is_meditating and player.current_mana == 130, "Repeated living damage neither stops meditation nor accelerates its ticks")
	registry.advance_runtime(11000)
	_check(player.current_mana == 260 and player.is_meditating, "Mage recovers260 mana during its first second")
	var state := PlayerState.from_dictionary(player.to_dictionary())
	_check(state.is_meditating and state.current_health == 198 and state.current_mana == 260, "Damaged meditation state survives authoritative snapshot serialization")
	registry.apply_damage(701, 10000)
	registry.advance_runtime(11500)
	_check(not player.is_alive and not player.is_meditating and player.current_mana == 260, "Death still clears meditation and prevents the next tick")
	f = _fixture()
	registry = f.registry
	player = f.player
	registry.try_recovery_action(701, "meditate", 1, 10000)
	_check(registry.try_recovery_action(701, "mana_potion", 2, 10100).ok and player.is_meditating and player.current_mana == 130, "A blue potion remains available during the new warmup")
	_check(registry.try_recovery_action(701, "health_potion", 3, 10420).ok and player.is_meditating and player.current_health == 227, "A red potion also preserves active meditation")
	_check(registry._next_meditation_tick[701] == 10500, "Neither potion resets or advances the meditation deadline")
	registry.advance_runtime(10500)
	_check(player.current_mana == 260 and player.is_meditating, "Potion recovery and the first scheduled meditation tick combine normally")
	player.current_mana = player.max_mana - 1
	registry.advance_runtime(11000)
	_check(player.current_mana == player.max_mana and not player.is_meditating, "Regeneration clamps and ends meditation at full mana")
	f = _fixture()
	registry = f.registry
	player = f.player
	registry.try_recovery_action(701, "meditate", 1, 10000)
	var result = registry.try_move_player(701, MovementRules.Direction.NORTH, 10100)
	registry.advance_runtime(10500)
	_check(result == player and not player.is_meditating and player.current_mana == 0, "Accepted movement still cancels meditation before its first tick")
	f = _fixture()
	registry = f.registry
	player = f.player
	player.current_mana = 1000
	registry.try_recovery_action(701, "meditate", 1, 10000)
	_check(not registry.try_cast_spell(701, 999, f.rival.grid_position, 1, 10100).ok and player.is_meditating, "A rejected cast does not cancel meditation")
	_check(registry.try_cast_spell(701, 51, f.rival.grid_position, 2, 10200).ok and not player.is_meditating, "An accepted cast still cancels meditation")
	registry.advance_runtime(10500)
	_check(player.current_mana == 540, "Casting cannot receive a stale pending meditation tick")
	for item in registries:
		item.queue_free()
	await process_frame
	print("Meditation checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + message)
