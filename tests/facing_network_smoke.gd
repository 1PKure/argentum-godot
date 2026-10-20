extends SceneTree
const PORT := 17896
var checks := 0
var failures := 0
var registry: PlayerRegistry
var actor_id := 0
var rival_id := 0
var snapshot: Array = []
var facing_events: Array = []
var hits: Array = []
func _initialize() -> void: call_deferred("_run")
func _check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: ",message)
func _run() -> void:
	var manager = root.get_node("NetworkManager")
	var network = root.get_node("PlayerNetwork")
	var args := OS.get_cmdline_user_args()
	if "--facing-server" in args:
		registry = PlayerRegistry.new()
		root.add_child(registry)
		manager.peer_connected.connect(func(id: int) -> void:
			var player := registry.add_player(id)
			if actor_id == 0:
				actor_id = id
				player.display_name = "Actor"
				player.grid_position = Vector2i(5,5)
				player.facing_direction = MovementRules.Direction.NORTH
			else:
				rival_id = id
				player.display_name = "Observer"
				player.grid_position = Vector2i(6,5)
				registry._status_system.effects[id] = [{"kind":"root","expires":Time.get_ticks_msec()+10000}]
				for recipient in [actor_id,rival_id]: network.send_snapshot_to(recipient,registry.get_snapshot())
		)
		network.move_requested.connect(func(id: int,direction: int) -> void:
			var changed := registry.try_move_player(id,direction)
			if changed != null: network.broadcast_player_moved(changed.to_dictionary())
		)
		network.basic_attack_requested.connect(func(id: int) -> void:
			var victim := registry.try_basic_attack(id)
			if victim != null: network.broadcast_player_stats_updated(victim.to_dictionary())
		)
		registry.basic_attack_resolved.connect(network.send_basic_attack_result)
		_check(manager.start_server(PORT,"127.0.0.1") == OK,"server starts")
		print("FACING SERVER READY")
		await create_timer(6).timeout
		manager.stop()
		quit(1 if failures else 0)
		return
	network.snapshot_received.connect(func(players: Array) -> void: snapshot = players)
	network.player_moved.connect(func(data: Dictionary) -> void: facing_events.append(data))
	network.basic_attack_resolved.connect(func(data: Dictionary) -> void: hits.append(data))
	manager.start_client("ws://127.0.0.1:%d" % PORT)
	var deadline := Time.get_ticks_msec()+4000
	while snapshot.size() < 2 and Time.get_ticks_msec() < deadline: await process_frame
	_check(snapshot.size() == 2,"two real WebSocket clients join authoritative registry")
	if snapshot.size() != 2: manager.stop(); quit(1); return
	var original: Dictionary = {}
	for data: Dictionary in snapshot:
		if data.display_name == "Actor": original = data
	_check(not original.is_empty(),"actor snapshot found")
	if original.is_empty(): manager.stop(); quit(1); return
	if "--facing-actor" in args:
		var input = load("res://client/input/local_input_controller.gd").new()
		root.add_child(input)
		Input.action_press("move_right")
		await create_timer(0.03).timeout
		Input.action_release("move_right")
		input.queue_free()
	deadline = Time.get_ticks_msec()+3000
	while facing_events.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	_check(facing_events.size() == 1,"one authoritative turn replicated to this client")
	if not facing_events.is_empty():
		var turn: Dictionary = facing_events[0]
		_check(turn.peer_id == original.peer_id and turn.grid_x == original.grid_x and turn.grid_y == original.grid_y and turn.facing_direction == MovementRules.Direction.EAST,"remote turn has unchanged tile and correct facing")
		var avatar = load("res://client/characters/player_avatar.tscn").instantiate()
		root.add_child(avatar)
		avatar.setup(PlayerState.from_dictionary(original),false,Vector2(240,240))
		avatar.apply_server_stats(PlayerState.from_dictionary(turn))
		avatar._process(0.1)
		_check(avatar._player_visual.current_direction == Vector2.RIGHT and avatar.position == Vector2(240,240),"remote client renders rotated avatar without movement")
		avatar.queue_free()
	if "--facing-actor" in args: network.request_basic_attack()
	deadline = Time.get_ticks_msec()+3000
	while hits.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	_check(hits.size() == 1 and int(hits[0].caster_id) == int(original.peer_id),"adjacent melee after turning resolves to both clients")
	# Keep the observer open while the actor leaves to avoid simultaneous-close
	# races in Godot's peer-presence notification during test teardown.
	await create_timer(0.1 if "--facing-actor" in args else 0.3).timeout
	manager.stop()
	await process_frame
	print("Facing WebSocket checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
