extends SceneTree

var _world
var _network
var _manager
var _events: Array[Dictionary] = []
var _failures := 0
var _healed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_network = root.get_node("PlayerNetwork")
	_manager = root.get_node("NetworkManager")
	var scene = load("res://client/scenes/client_main.tscn").instantiate()
	root.add_child(scene)
	_world = scene.get_node("ClientWorld")
	_network.spell_cast.connect(func(event: Dictionary) -> void: _events.append(event))
	if not await _wait(func() -> bool: return _world._local_state != null and _world._avatars.size() == 2, 8000):
		_expect(false, "Two real clients receive their actors.")
		_finish()
		return
	if "--spell-test-target" in OS.get_cmdline_user_args():
		await _run_target()
	else:
		await _run_caster()
	_finish()


func _run_target() -> void:
	var local_id: int = get_multiplayer().get_unique_id()
	if not await _wait(func() -> bool: return _world._local_state.current_health == 80, 8000):
		_expect(false, "The other client receives authoritative spell damage.")
		return
	_expect(_world._local_state.current_mana == 100, "Damage does not consume the victim's mana.")
	_world._spell_panel.spell_selected.emit(SpellCatalog.HEAL)
	_world._spell_panel._combat.toggled.emit(true)
	_world._request_spell(local_id)
	_expect(await _wait(func() -> bool: return _world._local_state.current_health == 100 and _world._local_state.current_mana == 88, 3000), "Direct combat click heals the actual client and synchronizes mana.")
	_expect(await _wait(func() -> bool: return _world._local_state.current_health == 80, 5000), "A repeated opposing cast reaches the second client.")
	await create_timer(2.0).timeout


func _run_caster() -> void:
	var target_id := 0
	for id: int in _world._avatars:
		if id != get_multiplayer().get_unique_id():
			target_id = id
	# Approach the original opposing spawn using the real movement RPC.
	for _step in range(5):
		_network.request_move(MovementRules.Direction.EAST)
		await create_timer(0.17).timeout
	_expect(_world._avatars[get_multiplayer().get_unique_id()].grid_position == Vector2i(9, 5), "Movement RPC positions the caster within spell range.")
	_world._spell_panel._launch.pressed.emit()
	_world._request_spell(target_id)
	_expect(await _wait(func() -> bool: return _world._local_state.current_mana == 85 and _world._spell_input.pending_request == 0, 3000), "Manual Lanzar reaches the server and acknowledges the client.")
	_expect(not _world._spell_input.manual_armed, "The accepted manual cast disarms the actual client.")
	_expect(await _wait(func() -> bool: return _events.any(func(event: Dictionary) -> bool: return int(event["spell_id"]) == SpellCatalog.HEAL), 3000), "The caster receives the remote player's healing effect.")
	await _wait(func() -> bool: return Time.get_ticks_msec() >= _world._spell_input.cooldown_until_msec, 2000)
	_world._spell_panel._combat.toggled.emit(true)
	_world._request_spell(target_id)
	_expect(await _wait(func() -> bool: return _world._local_state.current_mana == 70 and _world._spell_input.pending_request == 0, 3000), "Combat mode uses the same authoritative spell pipeline.")
	_world._spell_panel._combat.toggled.emit(false)
	_world._spell_panel._launch.pressed.emit()
	await _wait(func() -> bool: return Time.get_ticks_msec() >= _world._spell_input.cooldown_until_msec, 2000)
	_world._request_spell(get_multiplayer().get_unique_id())
	_expect(await _wait(func() -> bool: return _world._spell_input.pending_request == 0, 3000), "A rejected request is acknowledged and releases the pending state.")
	_expect(_world._local_state.current_mana == 70 and _world._spell_input.manual_armed and _world._spell_panel._status.text == SpellRules.get_message("self_target"), "The server's self-target rejection consumes no mana and keeps manual aiming active.")
	_world._cancel_spell()
	_expect(not _world._spell_input.is_targeting(), "Cancel exits targeting after a real network rejection.")


func _wait(predicate: Callable, timeout_msec: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await create_timer(0.01).timeout
	return bool(predicate.call())


func _expect(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		_failures += 1


func _finish() -> void:
	_manager.stop()
	print("Spell network client failures: %d" % _failures)
	quit(0 if _failures == 0 else 1)
