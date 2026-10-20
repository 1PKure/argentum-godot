extends SceneTree
var checks := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func _check(value: bool, label: String) -> void:
	checks += 1
	if not value: failed += 1; print("FAIL: ",label)
func _run() -> void:
	var world = load("res://client/scenes/client_world.gd").new()
	root.add_child(world)
	world._spawn_player(PlayerState.new(7,"A",Vector2i(4,5)).to_dictionary())
	world._spawn_player(PlayerState.new(8,"B",Vector2i(5,5)).to_dictionary())
	world._on_melee_resolved({"caster_id":7,"target_id":8,"amount":0})
	_check(world._melee_audio.is_empty(),"miss has no impact sound")
	world._on_melee_resolved({"caster_id":7,"target_id":9,"amount":10})
	_check(world._melee_audio.is_empty(),"unrelated room has no impact sound")
	world._on_melee_resolved({"caster_id":7,"target_id":8,"amount":10})
	_check(world._melee_audio.size()==1 and world._melee_audio[0].playing and world._melee_audio[0].volume_db==0.0,"confirmed melee hit plays sound")
	_check(is_equal_approx(world.MELEE_IMPACT_SOUND.get_length(),1.0),"contact preserves the supplied full one-second original")
	world.set_game_paused(true)
	_check(world.process_mode==Node.PROCESS_MODE_DISABLED and world._melee_audio[0].stream_paused,"bot pause freezes world and impact audio")
	world.set_game_paused(false)
	_check(world.process_mode==Node.PROCESS_MODE_INHERIT and not world._melee_audio[0].stream_paused,"resume restores world audio")
	world.clear_session()
	await process_frame
	_check(world._melee_audio.is_empty() and world._avatars.is_empty(),"leaving clears pending impact and avatars")
	world.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	print("Melee feedback checks: %d; failures: %d"%[checks,failed])
	quit(1 if failed else 0)
