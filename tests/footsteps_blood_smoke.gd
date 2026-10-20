extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool,message: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: ",message)
func _run() -> void:
	var world = load("res://client/scenes/client_world.gd").new()
	root.add_child(world)
	world._spawn_player(PlayerState.new(7,"Actor",Vector2i(4,5)).to_dictionary())
	world._spawn_player(PlayerState.new(8,"Rival",Vector2i(5,5)).to_dictionary())
	var actor = world._avatars[7]
	var rival = world._avatars[8]
	actor.set_process(false)
	rival.set_process(false)
	actor._process(0.5)
	check(world._footstep_audio.is_empty(),"idle creates no footfall")
	var turn: Dictionary = PlayerState.new(7,"Actor",Vector2i(4,5)).to_dictionary()
	turn.facing_direction = MovementRules.Direction.WEST
	world._on_player_moved(turn)
	actor._process(0.5)
	check(world._footstep_audio.is_empty(),"turn-only authoritative update creates no footfall")
	actor.apply_server_position(Vector2i(4,6),actor.position+Vector2(0,48))
	actor._process(MovementRules.MOVE_INTERVAL_SECONDS*0.5)
	check(world._footstep_audio.is_empty(),"interpolation does not play before the confirmed foot lands")
	actor._process(MovementRules.MOVE_INTERVAL_SECONDS*0.5)
	check(world._footstep_count.get(7,0)==1 and world._footstep_audio[7].playing,"one real completed tile plays one footfall")
	var audio: AudioStreamPlayer2D = world._footstep_audio[7]
	check(audio.get_parent()==actor and audio.max_distance==world.TILE_SIZE*8 and audio.panning_strength<1.0,"footfalls are spatial with bounded distance and moderate panning")
	actor._process(1)
	check(world._footstep_count[7]==1,"idle/grace frames do not repeat the footfall")
	actor.apply_server_position(Vector2i(4,7),actor.position+Vector2(0,48))
	actor.apply_server_position(Vector2i(4,8),actor.position+Vector2(0,96))
	actor._process(1)
	check(world._footstep_count[7]==1,"stalled frames cannot replay a backlog of footfalls")
	var paths: Array[String] = []
	for material: String in ["forest","desert","lava","duel_room"]:
		world._last_footstep[7] = -1000
		world._arena_id = material
		world._on_avatar_step(actor)
		paths.append(audio.stream.resource_path)
		check(audio.stream.get_length()>0.10 and audio.stream.get_length()<0.12 and audio.stream.resource_path.contains(material),"material-specific short footfall: "+material)
	check(paths.size()==4 and paths[0]!=paths[1] and paths[1]!=paths[2] and paths[2]!=paths[3],"each biome has a separate material recording")
	var before: int = world._footstep_count[7]
	world.set_game_paused(true)
	world._on_avatar_step(actor)
	check(world._footstep_count[7]==before and not audio.playing,"bot pause silences and blocks footfalls")
	world.set_game_paused(false)
	actor.is_ghost = true
	await create_timer(0.09).timeout
	world._on_avatar_step(actor)
	check(world._footstep_count[7]==before,"ghost footsteps remain silent")
	actor.is_ghost = false
	world._on_melee_resolved({"caster_id":7,"target_id":8,"amount":0})
	check(world._blood_impacts.is_empty(),"miss/rejection does not create melee blood")
	world._on_melee_resolved({"caster_id":7,"target_id":99,"amount":10})
	check(world._blood_impacts.is_empty(),"unrelated-room victim creates no blood")
	var hp: bool = rival.is_alive
	world._on_melee_resolved({"caster_id":7,"target_id":8,"amount":10})
	check(world._blood_impacts.size()==1 and rival.is_alive==hp,"confirmed melee creates one cosmetic blood impact without changing combat state")
	var blood = world._blood_impacts[0]
	blood.set_process(false)
	var position: Vector2 = blood.position
	rival.position += Vector2(24,0)
	blood._process(0.1)
	check(blood.position.is_equal_approx(position+Vector2(24,0)),"melee blood follows the rendered moving target")
	world.set_game_paused(true)
	var age: float = blood.age
	blood.set_process(true)
	await create_timer(0.1).timeout
	check(blood.age==age,"bot pause freezes blood with the world")
	world.set_game_paused(false)
	await create_timer(0.5).timeout
	check(world._blood_impacts.is_empty(),"blood cleans itself after its bounded lifetime")
	world.clear_session()
	await process_frame
	check(world._footstep_audio.is_empty() and world._blood_impacts.is_empty(),"leaving clears spatial audio and blood")
	world.queue_free()
	await process_frame
	print("Footsteps/blood checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
