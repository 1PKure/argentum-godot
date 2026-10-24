extends SceneTree

const TEST_PORT := 7789

var registry: Node
var confirmed_positions: Array[Vector2i] = []
var confirmed_times: Array[int] = []
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager = root.get_node("NetworkManager")
	var player_network = root.get_node("PlayerNetwork")
	if "--movement-server" in OS.get_cmdline_user_args():
		registry = load("res://server/systems/player_registry.gd").new()
		root.add_child(registry)
		manager.peer_connected.connect(func(peer_id: int) -> void:
			registry.add_player(peer_id)
			player_network.send_snapshot_to(peer_id, registry.get_snapshot()))
		player_network.move_requested.connect(func(peer_id: int, direction: int) -> void:
			var player = registry.try_move_player(peer_id, direction)
			if player != null:
				player_network.broadcast_player_moved(player.to_dictionary()))
		var error: Error = manager.start_server(TEST_PORT, "127.0.0.1")
		if error != OK:
			quit(1)
			return
		print("MOVEMENT TEST SERVER READY")
		await create_timer(8.0).timeout
		manager.stop()
		quit()
		return
	player_network.player_moved.connect(func(player_data: Dictionary) -> void:
		var state := PlayerState.from_dictionary(player_data)
		confirmed_positions.append(state.grid_position)
		confirmed_times.append(Time.get_ticks_msec()))
	var received_snapshot := [false]
	player_network.snapshot_received.connect(func(_players: Array) -> void: received_snapshot[0] = true)
	manager.start_client("ws://127.0.0.1:%d" % TEST_PORT)
	var deadline := Time.get_ticks_msec() + 4000
	while not received_snapshot[0] and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(received_snapshot[0], "Real WebSocket client receives authoritative player snapshot")
	if not received_snapshot[0]:
		manager.stop()
		quit(1)
		return
	var controller = load("res://client/input/local_input_controller.gd").new()
	root.add_child(controller)
	Input.action_press("move_right")
	await create_timer(1.4).timeout
	Input.action_release("move_right")
	await create_timer(0.15).timeout
	_check(confirmed_positions.size() >= 11 and confirmed_positions.size() <= 13, "Held movement keeps its expected cadence across a real WebSocket connection")
	var consecutive := true
	var maximum_gap := 0
	for index in range(confirmed_positions.size()):
		if confirmed_positions[index] != Vector2i(5 + index, 5):
			consecutive = false
		if index > 0:
			maximum_gap = maxi(maximum_gap, confirmed_times[index] - confirmed_times[index - 1])
	_check(consecutive, "Every server-confirmed step remains one horizontal grid tile")
	_check(confirmed_times.size() > 1 and maximum_gap <= 180, "Native 60 FPS loopback has no rejected-step pause above180 ms")
	var stopped_count := confirmed_positions.size()
	await create_timer(0.2).timeout
	_check(confirmed_positions.size() == stopped_count, "Releasing the key stops movement over the actual connection")
	print("Movement WebSocket samples: %d; maximum gap: %d ms" % [confirmed_positions.size(), maximum_gap])
	controller.queue_free()
	manager.stop()
	print("Movement network checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + description)
