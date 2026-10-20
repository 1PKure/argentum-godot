extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func _run() -> void:
	ArenaAudioMix.configure()
	ArenaAudioMix.configure()
	var bus := AudioServer.get_bus_index(&"Combat")
	check(bus>=0 and AudioServer.get_bus_send(bus)==&"Master","combat routes to master")
	check(is_equal_approx(AudioServer.get_bus_volume_db(bus),-3.0),"previous combat mix has three dB of headroom")
	check(AudioServer.get_bus_name(0)==&"Master","bus insertion preserves Master index")
	check(AudioServer.get_bus_effect_count(0)==1 and AudioServer.get_bus_effect(0,0) is AudioEffectHardLimiter and AudioServer.get_bus_effect_count(bus)==0,"master retains single ceiling limiter without source EQ")
	for path: String in ["res://assets/argentum/custom/audio/melee_hit.wav","res://assets/argentum/custom/audio/arrow_hit.wav","res://assets/argentum/source/audio/16.wav","res://assets/argentum/source/audio/113.wav","res://assets/argentum/source/audio/17.wav","res://assets/argentum/source/audio/18.wav"]:
		var stream := load(path) as AudioStreamWAV
		check(stream!=null and stream.format in [AudioStreamWAV.FORMAT_8_BITS,AudioStreamWAV.FORMAT_16_BITS],"uncompressed playback: "+path.get_file())
	var one := AudioStreamPlayer.new()
	root.add_child(one)
	one.volume_db = 0
	ArenaAudioMix.route(one)
	check(one.bus==&"Combat" and one.volume_db==0 and one.pitch_scale==1.0 and one.playback_type==AudioServer.PLAYBACK_TYPE_STREAM,"routing preserves gain and speed")
	var two := AudioStreamPlayer2D.new()
	root.add_child(two)
	ArenaAudioMix.route(two,1,&"Footsteps")
	check(two.bus==&"Footsteps","positional footsteps have their own volume bus")
	check(two.playback_type==AudioServer.PLAYBACK_TYPE_STREAM,"spatial audio uses stable Stream transport on web too")
	check(ProjectSettings.get_setting("audio/driver/output_latency.web")==80 and ProjectSettings.get_setting("audio/general/default_playback_type.web")==0,"single-thread web reserves buffer and uses Stream rather than unsupported Sample effects")
	ArenaAudioMix.route(two,3)
	check(two.max_polyphony==3,"footfall tails can overlap without being cut off")
	one.queue_free(); two.queue_free()
	await process_frame
	print("Audio mix checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
