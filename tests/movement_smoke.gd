extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_input_cadence()
	_test_authoritative_timing()
	_test_registry_collisions()
	await _test_avatar()
	print("Movement checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)


func _test_input_cadence() -> void:
	var input_probe = load("res://tests/movement_input_probe.gd")
	var controller = input_probe.new()
	root.add_child(controller)
	controller.set_process(false)
	Input.action_press("move_right")
	var accepted := 0
	var last_accepted := 0
	var request_times: Array[int] = []
	for frame in range(180):
		var before: int = controller.request_directions.size()
		controller._process(1.0 / 60.0)
		if controller.request_directions.size() != before:
			var now := 1000 + roundi((frame + 1) * 1000.0 / 60.0)
			request_times.append(now)
			if MovementRules.is_move_ready(now, last_accepted):
				accepted += 1
				last_accepted = MovementRules.get_accepted_move_time(now, last_accepted)
	_check(request_times.size() >= 25 and request_times.size() <= 26, "Held input keeps 120 ms cadence at 60 FPS without frame drift")
	_check(accepted == request_times.size(), "Normal frame quantization does not silently discard held steps")
	_check(controller.request_directions[0] == MovementRules.Direction.EAST, "Held input sends the actual pressed direction")
	for frame_rate: int in [20, 30, 75, 144]:
		var sample = input_probe.new()
		root.add_child(sample)
		sample.set_process(false)
		var sample_accepted := 0
		var sample_last := 0
		for frame in range(frame_rate * 6):
			var before: int = sample.request_directions.size()
			sample._process(1.0 / frame_rate)
			if sample.request_directions.size() == before:
				continue
			var now := 1000 + roundi((frame + 1) * 1000.0 / frame_rate)
			if MovementRules.is_move_ready(now, sample_last):
				sample_accepted += 1
				sample_last = MovementRules.get_accepted_move_time(now, sample_last)
		_check(sample_accepted == sample.request_directions.size(), "Held steps remain accepted at %d FPS without a full-step gap" % frame_rate)
		sample.queue_free()
	Input.action_release("move_right")
	controller._move_timer = 0.07
	var count_before: int = controller.request_directions.size()
	controller._process(0.016)
	_check(controller.request_directions.size() == count_before, "Releasing movement immediately stops requests")
	Input.action_press("move_up")
	controller._process(0.016)
	_check(controller.request_directions.size() == count_before, "Release/repress preserves the remaining authoritative cooldown instead of sending a rejected early turn")
	controller._process(0.04)
	_check(controller.request_directions.size() == count_before + 1 and controller.request_directions[-1] == MovementRules.Direction.NORTH, "The new direction is requested at the next valid movement interval")
	count_before = controller.request_directions.size()
	controller._process(1.0)
	controller._process(0.016)
	_check(controller.request_directions.size() == count_before + 1, "A long/background frame does not replay a burst of old inputs")
	Input.action_release("move_up")
	controller.queue_free()


func _test_authoritative_timing() -> void:
	var interval := MovementRules.MOVE_INTERVAL_MSEC
	var tolerance := MovementRules.MOVE_TIMING_TOLERANCE_MSEC
	_check(not MovementRules.is_move_ready(1000 + interval - tolerance - 1, 1000), "Server rejects movement earlier than its bounded tolerance")
	_check(MovementRules.is_move_ready(1000 + interval - tolerance, 1000), "Server accepts a request at the jitter boundary")
	var scheduled := MovementRules.get_accepted_move_time(1000 + interval - tolerance, 1000)
	_check(scheduled == 1000 + interval, "An early request retains the original scheduled movement time")
	_check(not MovementRules.is_move_ready(1000 + interval - tolerance, scheduled), "A direction change cannot produce two movements at the same time")
	var accepted_times: Array[int] = []
	var last_time := 1000
	for now in range(1001, 13001):
		if MovementRules.is_move_ready(now, last_time):
			accepted_times.append(now)
			last_time = MovementRules.get_accepted_move_time(now, last_time)
	_check(accepted_times.size() == 100, "Spamming one request every millisecond does not increase 120 ms movement speed")
	_check(last_time == 13000, "Jitter tolerance cannot accumulate into a faster logical clock")
	var directions := [MovementRules.Direction.NORTH, MovementRules.Direction.EAST, MovementRules.Direction.SOUTH, MovementRules.Direction.WEST]
	var position := Vector2i(5, 5)
	last_time = 1000
	var same_time_moves := 0
	for direction: int in directions:
		if MovementRules.is_move_ready(1120, last_time):
			position += MovementRules.get_offset(direction)
			last_time = MovementRules.get_accepted_move_time(1120, last_time)
			same_time_moves += 1
	_check(same_time_moves == 1 and position == Vector2i(5, 4), "Rapid direction changes share the same authoritative movement limit")


func _test_registry_collisions() -> void:
	var registry = load("res://server/systems/player_registry.gd").new()
	root.add_child(registry)
	var player = registry.add_player(71)
	var rival = registry.add_player(72)
	player.grid_position = Vector2i(4, 5)
	rival.grid_position = Vector2i(6, 5)
	var before := Time.get_ticks_msec()
	registry._last_move_time[71] = before - MovementRules.MOVE_INTERVAL_MSEC + MovementRules.MOVE_TIMING_TOLERANCE_MSEC
	var result = registry.try_move_player(71, MovementRules.Direction.EAST)
	_check(result != null and player.grid_position == Vector2i(5, 5), "Actual server registry accepts a slightly early valid step")
	_check(registry._last_move_time[71] >= before + MovementRules.MOVE_TIMING_TOLERANCE_MSEC, "Actual registry retains the scheduled timestamp for an early step")
	result = registry.try_move_player(71, MovementRules.Direction.NORTH)
	_check(result == null and player.grid_position == Vector2i(5, 5), "Actual registry rejects an immediate second step in a different direction")
	registry._last_move_time[71] = Time.get_ticks_msec() - MovementRules.MOVE_INTERVAL_MSEC
	result = registry.try_move_player(71, MovementRules.Direction.EAST)
	_check(result == null and player.grid_position == Vector2i(5, 5), "Smoothing does not let a living player cross another living player")
	player.grid_position = Vector2i(1, 2)
	registry._last_move_time[71] = Time.get_ticks_msec() - MovementRules.MOVE_INTERVAL_MSEC
	result = registry.try_move_player(71, MovementRules.Direction.EAST)
	_check(player.grid_position == Vector2i(1, 2) and player.facing_direction == MovementRules.Direction.EAST, "Smoothing preserves the arena obstacle while permitting facing toward tile2,2")
	player.grid_position = Vector2i(0, 5)
	registry._last_move_time[71] = Time.get_ticks_msec() - MovementRules.MOVE_INTERVAL_MSEC
	result = registry.try_move_player(71, MovementRules.Direction.WEST)
	_check(result != null and player.grid_position == Vector2i(0, 5) and player.facing_direction == MovementRules.Direction.WEST, "Map boundaries block translation while allowing an authoritative turn")
	registry.queue_free()


func _test_avatar() -> void:
	var avatar = load("res://client/characters/player_avatar.tscn").instantiate()
	root.add_child(avatar)
	await process_frame
	avatar.set_process(false)
	var state := PlayerState.new(71, "Movimiento", Vector2i(4, 5))
	avatar.setup(state, true, Vector2(216, 264))
	var start: Vector2 = avatar.position
	avatar.apply_server_position(Vector2i(5, 5), start + Vector2(48, 0))
	avatar._process(MovementRules.MOVE_INTERVAL_SECONDS / 2.0)
	_check(avatar.position.is_equal_approx(start + Vector2(24, 0)), "A confirmed tile is interpolated rather than teleported")
	avatar._process(MovementRules.MOVE_INTERVAL_SECONDS / 2.0)
	_check(avatar.position.is_equal_approx(start + Vector2(48, 0)), "Visual movement finishes on the same 120 ms cadence as the server")
	avatar._process(0.25)
	_check(avatar.position.is_equal_approx(start + Vector2(48, 0)), "The avatar never moves beyond its last confirmed tile")
	state.is_bot = true
	avatar.setup(state, false, start)
	avatar.apply_server_position(Vector2i(5, 5), start + Vector2(48, 0))
	avatar._process(0.06)
	_check(avatar.position.is_equal_approx(start + Vector2(24, 0)), "Bot presentation uses the same 120 ms tile interpolation as the human")
	avatar._process(0.06)
	_check(avatar.position.is_equal_approx(start + Vector2(48, 0)), "Bot reaches its exact confirmed tile on the same cadence as the player")
	state.is_bot = false
	avatar.apply_server_stats(state)
	_check(is_equal_approx(avatar._move_speed, avatar.MOVE_SPEED), "A human state restores the unchanged 120 ms interpolation")
	avatar.queue_free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + description)
