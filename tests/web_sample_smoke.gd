extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("_run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("FAIL: ",label)
func _run()->void:
	ArenaAudioMix._settings_path="user://sample_test.cfg"
	ArenaAudioMix._levels.clear()
	ArenaAudioMix._platform_web=true
	var player:=AudioStreamPlayer.new();root.add_child(player)
	player.volume_db=-12
	ArenaAudioMix.route(player)
	check(AudioServer.bus_count==1 and AudioServer.get_bus_name(0)==&"Master","web configuration never creates or reroutes buses")
	check(player.playback_type==AudioServer.PLAYBACK_TYPE_SAMPLE and player.bus==&"Master","web uses browser samples on Master")
	check(is_equal_approx(player.volume_db,-15),"web gains preserve source and combat headroom")
	ArenaAudioMix.route(player)
	check(is_equal_approx(player.volume_db,-15),"reused playback never accumulates attenuation")
	ArenaAudioMix.set_volume("effects",50)
	check(is_equal_approx(player.volume_db,-15+linear_to_db(.5)),"effects slider updates existing samples")
	var steps:=AudioStreamPlayer2D.new();root.add_child(steps);steps.volume_db=-8
	ArenaAudioMix.route(steps,3,&"Footsteps")
	check(is_equal_approx(steps.volume_db,-11+linear_to_db(.5*.85)),"steps combine effects and independent footstep slider")
	ArenaAudioMix.set_volume("footsteps",0)
	check(steps.volume_db < -100 and player.volume_db > -30,"steps can mute without silencing spells")
	player.queue_free();steps.queue_free();await process_frame
	ArenaAudioMix.set_volume("effects",100)
	check(ArenaAudioMix._web_players.is_empty(),"sample registry drops freed players")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ArenaAudioMix._settings_path))
	ArenaAudioMix._platform_web=false
	ArenaAudioMix._levels.clear();ArenaAudioMix._settings_path=ArenaAudioMix.SETTINGS_PATH
	print("Web sample checks: %d; failures: %d"%[checks,failures]);quit(1 if failures else 0)
