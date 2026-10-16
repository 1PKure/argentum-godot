extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_camera()
	await _test_confirmed_corners()
	_test_direction_change()
	_test_first_frame_cadence()
	print("Camera/movement checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)


func _test_camera() -> void:
	var game_area := Control.new()
	game_area.position = Vector2(44, 72)
	game_area.size = Vector2(900, 576)
	game_area.scale = Vector2(0.8, 0.8)
	game_area.clip_contents = true
	root.add_child(game_area)
	var world = load("res://client/scenes/client_world.gd").new()
	game_area.add_child(world)
	world.set_process(false)
	world.configure_viewport(game_area.size)
	var local_id: int = world.multiplayer.get_unique_id()
	var local_state := PlayerState.new(local_id, "Cámara", Vector2i(4, 5))
	var rival := PlayerState.new(local_id + 1, "Rival", Vector2i(6, 5))
	world._on_snapshot_received([local_state.to_dictionary(), rival.to_dictionary()])
	var avatar = world._avatars[local_id]
	var other = world._avatars[local_id + 1]
	avatar.set_process(false)
	other.set_process(false)
	_check(world.scale == Vector2.ONE, "Map uses native tile scale rather than shrinking the whole arena")
	_check(_is_centered(world, game_area, avatar), "Local player's tile is centered immediately after snapshot")
	_check(world.process_priority > avatar.process_priority, "Camera follows after avatar interpolation in each render frame")
	var fixed_hud_position := game_area.global_position
	var start: Vector2 = avatar.position
	avatar.apply_server_position(Vector2i(5, 5), start + Vector2(48, 0))
	avatar._process(0.06)
	world._process(0.06)
	_check(_is_centered(world, game_area, avatar) and avatar.position == start + Vector2(24, 0), "Camera follows the interpolated half-step without snapping to the target tile")
	_check(game_area.global_position == fixed_hud_position, "Following the map leaves the HUD parent stationary")
	var pointer: Vector2 = world.get_global_transform() * (other.position + Vector2(0, -25))
	_check(world.target_grid_at(pointer) == rival.grid_position, "Avatar targeting stays exact after scrolling inside the scaled HUD")
	var empty_tile := Vector2i(8, 7)
	pointer = world.get_global_transform() * world._grid_to_world(empty_tile)
	_check(world.target_grid_at(pointer) == empty_tile, "Ground targeting uses the inverse world transform after scrolling")
	for edge: Vector2i in [Vector2i(0, 0), Vector2i(19, 11)]:
		local_state.grid_position = edge
		avatar.setup(local_state, true, world._grid_to_world(edge))
		world._process(0.0)
		_check(_is_centered(world, game_area, avatar), "Local player stays centered at map edge %s" % edge)
	game_area.size = Vector2(1060, 680)
	game_area.scale = Vector2(1.1, 1.1)
	world.resize_viewport(game_area.size)
	_check(_is_centered(world, game_area, avatar), "Resizing the game area immediately recalculates the camera center")
	pointer = world.get_global_transform() * (avatar.position + Vector2(0, -25))
	_check(world.target_grid_at(pointer) == local_state.grid_position, "Self-targeting remains exact after viewport resize")
	world.clear_session()
	_check(world._local_avatar_peer_id == 0 and world._avatars.is_empty(), "Disconnect clears the old camera target")
	local_state.grid_position = Vector2i(10, 6)
	world._on_snapshot_received([local_state.to_dictionary()])
	avatar = world._avatars[local_id]
	_check(_is_centered(world, game_area, avatar), "Reconnect centers the new local avatar instead of a freed previous target")
	game_area.queue_free()
	await process_frame


func _is_centered(world, game_area: Control, avatar) -> bool:
	var actual: Vector2 = world.get_global_transform() * avatar.position
	var expected := game_area.get_global_transform() * (game_area.size * 0.5)
	return actual.is_equal_approx(expected)


func _test_confirmed_corners() -> void:
	var avatar = load("res://client/characters/player_avatar.tscn").instantiate()
	root.add_child(avatar)
	avatar.set_process(false)
	var state := PlayerState.new(71, "Esquinas", Vector2i(4, 5))
	var start := Vector2(240, 288)
	avatar.setup(state, true, start)
	avatar.apply_server_position(Vector2i(5, 5), start + Vector2(48, 0))
	avatar._process(0.10)
	avatar.apply_server_position(Vector2i(5, 4), start + Vector2(48, -48))
	avatar._process(0.03)
	_check(avatar.position.is_equal_approx(start + Vector2(48, -4)), "Confirmed turn reaches its orthogonal corner before advancing, using leftover frame time")
	avatar._process(0.11)
	_check(avatar.position.is_equal_approx(start + Vector2(48, -48)), "Two confirmed tiles still take exactly 240 ms")
	avatar._process(1.0)
	_check(avatar.position.is_equal_approx(start + Vector2(48, -48)), "Smoothing cannot advance past the last server-confirmed position")
	avatar.setup(state, true, start)
	_check(avatar._movement_waypoints.is_empty() and avatar.position == start, "A fresh spawn resets queued visual movement")
	avatar.queue_free()
	await process_frame


func _test_direction_change() -> void:
	var controller = load("res://tests/movement_input_probe.gd").new()
	root.add_child(controller)
	controller.set_process(false)
	Input.action_press("move_right")
	controller._process(0.0)
	_check(controller.request_directions.size() == 1, "First held direction requests a step immediately")
	Input.action_release("move_right")
	Input.action_press("move_up")
	controller._process(0.06)
	_check(controller.request_directions.size() == 1, "Turning halfway through a step does not send a request that the server would reject")
	controller._process(0.06)
	_check(controller.request_directions.size() == 2 and controller.request_directions[-1] == MovementRules.Direction.NORTH, "Turn is sent at 120 ms instead of delaying until 180 ms after an early rejected request")
	Input.action_release("move_up")
	controller.queue_free()


func _test_first_frame_cadence() -> void:
	var controller = load("res://tests/movement_input_probe.gd").new()
	root.add_child(controller)
	controller.set_process(false)
	Input.action_press("move_right")
	controller._process(0.04)
	var now := 1040
	var last_accepted := now
	var rejected := 0
	for frame in range(60):
		var before: int = controller.request_directions.size()
		controller._process(1.0 / 60.0)
		now = 1040 + roundi((frame + 1) * 1000.0 / 60.0)
		if controller.request_directions.size() != before:
			if MovementRules.is_move_ready(now, last_accepted):
				last_accepted = MovementRules.get_accepted_move_time(now, last_accepted)
			else:
				rejected += 1
	_check(rejected == 0 and controller.request_directions.size() >= 9, "A 40 ms startup frame does not shorten the first interval and trigger a rejected repeat")
	Input.action_release("move_right")
	controller.queue_free()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + description)
