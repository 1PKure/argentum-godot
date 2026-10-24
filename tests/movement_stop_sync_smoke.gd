extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:failures += 1;print("FAIL: ",label)
func _run() -> void:
	var world = load("res://client/scenes/client_world.gd").new()
	root.add_child(world)
	world.set_process(false)
	var bot := PlayerState.new(-1000,"Bot",Vector2i(4,5))
	bot.is_bot = true
	var human := PlayerState.new(1,"Jugador",Vector2i(2,2))
	world._on_snapshot_received([bot.to_dictionary(),human.to_dictionary()])
	var avatar = world._avatars[-1000]
	avatar.set_process(false)
	var footfalls: Array[int] = []
	avatar.step_landed.connect(func() -> void:footfalls.append(1))
	for step in range(1,7):
		bot.grid_position = Vector2i(4+step,5)
		world._on_player_moved(bot.to_dictionary())
	check(avatar._movement_waypoints.size() == 6,"fixture reproduces a backed-up movement stream")
	bot.active_effects.assign(["Paralizado"])
	world._on_player_stats_updated(bot.to_dictionary())
	var stopped: Vector2 = world._grid_to_world(bot.grid_position)
	check(avatar._movement_waypoints.is_empty() and avatar.position == stopped,"paralysis cancels queued interpolation at the authoritative tile")
	check(avatar._visual_movement_grace_timer == 0,"paralysis cancels the walking grace animation")
	avatar._process(1.0)
	check(avatar.position == stopped and footfalls.is_empty(),"no post-paralysis motion or late footsteps")
	avatar.apply_server_position(Vector2i(11,5),stopped+Vector2(48,0))
	check(avatar._movement_waypoints.is_empty() and avatar.position == stopped,"blocked avatars do not accumulate more interpolation")
	bot.active_effects.clear()
	bot.grid_position = Vector2i(11,5)
	world._on_player_moved(bot.to_dictionary())
	check(avatar._movement_waypoints.size() == 1,"a movement packet that clears paralysis keeps its first valid step")
	avatar._process(MovementRules.MOVE_INTERVAL_SECONDS+0.02)
	check(avatar.position == world._grid_to_world(bot.grid_position),"movement resumes normally after Remove")
	bot.active_effects.assign(["Inmovilizado"])
	bot.facing_direction = MovementRules.Direction.WEST
	world._on_player_moved(bot.to_dictionary())
	check(avatar._movement_waypoints.is_empty() and avatar._player_visual.current_direction == Vector2.LEFT,"immobilization still allows an authoritative turn without walking")
	bot.active_effects.clear()
	world._on_player_stats_updated(bot.to_dictionary())
	for step in range(1,5):
		bot.grid_position = Vector2i(11,5+step)
		world._on_player_moved(bot.to_dictionary())
	check(avatar._movement_waypoints.size() == 4,"fixture queues confirmed steps before the killing hit")
	bot.apply_damage(100000)
	world._on_player_stats_updated(bot.to_dictionary())
	stopped = world._grid_to_world(bot.grid_position)
	check(avatar.position == stopped and avatar._movement_waypoints.is_empty() and avatar.is_ghost,"dead bot becomes a stationary ghost immediately")
	var before: int = footfalls.size()
	avatar._process(2.0)
	check(avatar.position == stopped and footfalls.size() == before,"death cannot replay movement or footsteps")
	var player = world._avatars[1]
	player.set_process(false)
	human.grid_position = Vector2i(3,2)
	world._on_player_moved(human.to_dictionary())
	human.apply_damage(100000)
	world._on_player_stats_updated(human.to_dictionary())
	check(player._movement_waypoints.is_empty() and player.position == world._grid_to_world(human.grid_position),"human death cancels old living steps too")
	human.grid_position = Vector2i(4,2)
	world._on_player_moved(human.to_dictionary())
	player._process(MovementRules.MOVE_INTERVAL_SECONDS)
	check(player.is_ghost and player.position == world._grid_to_world(human.grid_position),"a human ghost can still move after the death transition")
	bot.current_health = bot.max_health
	bot.is_alive = true
	bot.grid_position = Vector2i(4,5)
	world._on_player_stats_updated(bot.to_dictionary())
	check(not avatar._movement_blocked and avatar.position == world._grid_to_world(bot.grid_position),"a new round resets the dead bot stop flag")
	world.queue_free()
	await process_frame
	print("Movement stop checks: %d; failures: %d"%[checks,failures])
	quit(1 if failures else 0)
