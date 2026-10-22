extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool,message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func _run() -> void:
	ArenaAudioMix._settings_path = "user://audio_test_%s.cfg" % Crypto.new().generate_random_bytes(6).hex_encode()
	ArenaAudioMix._levels.clear()
	ArenaAudioMix.configure()
	check(ArenaAudioMix.volume("footsteps")==85,"footsteps default to a clearer 85 percent")
	check(ArenaAudioMix.set_volume("effects",45)==OK,"volume preferences save")
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Combat")),-3+linear_to_db(0.45)),"effect gain reaches active bus immediately")
	check(ArenaAudioMix.set_volume("footsteps",0)==OK and AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Footsteps")),"zero mutes all active/new footfalls")
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Combat")),"step mute leaves spell/impact audio available")
	ArenaAudioMix._levels.clear()
	ArenaAudioMix.configure()
	check(ArenaAudioMix.volume("effects")==45 and ArenaAudioMix.volume("footsteps")==0,"preferences reload on fresh audio state")
	check(ArenaAudioMix.set_volume("master",0)==OK and AudioServer.is_bus_mute(0),"master zero mutes every source")
	ArenaAudioMix.set_volume("master",200)
	check(ArenaAudioMix.volume("master")==100 and not AudioServer.is_bus_mute(0),"values clamp and can unmute")
	check(ArenaAudioMix.set_volume("unknown",10)==ERR_INVALID_PARAMETER and ArenaAudioMix.set_volume("master",NAN)==ERR_INVALID_PARAMETER,"invalid preferences never corrupt bus")
	var effect := AudioStreamPlayer.new()
	ArenaAudioMix.route(effect)
	check(effect.bus==&"Combat" and ArenaAudioMix.volume("effects")==45,"new playback does not reset chosen volume")
	effect.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ArenaAudioMix._settings_path))
	ArenaAudioMix._settings_path = ArenaAudioMix.SETTINGS_PATH
	ArenaAudioMix._levels.clear()
	ArenaAudioMix.configure()
	print("Audio preference checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
