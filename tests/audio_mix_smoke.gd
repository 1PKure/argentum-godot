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
	check(is_equal_approx(AudioServer.get_bus_volume_db(bus),-3.0),"combat mix reserves headroom")
	var limiters := 0
	for i in AudioServer.get_bus_effect_count(0):
		var effect := AudioServer.get_bus_effect(0,i)
		if effect is AudioEffectHardLimiter:
			limiters += 1
			check(effect.ceiling_db <= -1.0 and effect.pre_gain_db==0.0,"master catches peaks without boosting sources")
	check(limiters==1,"repeated setup does not stack limiters")
	for path: String in ["res://assets/argentum/custom/audio/melee_hit.wav","res://assets/argentum/custom/audio/arrow_hit.wav","res://assets/argentum/source/audio/16.wav","res://assets/argentum/source/audio/113.wav","res://assets/argentum/source/audio/17.wav","res://assets/argentum/source/audio/18.wav"]:
		var stream := load(path) as AudioStreamWAV
		check(stream!=null and stream.format in [AudioStreamWAV.FORMAT_8_BITS,AudioStreamWAV.FORMAT_16_BITS],"uncompressed playback: "+path.get_file())
	var one := AudioStreamPlayer.new()
	root.add_child(one)
	one.volume_db = -12
	ArenaAudioMix.route(one)
	check(one.bus==&"Combat" and one.volume_db==-12 and one.pitch_scale==1.0,"routing preserves gain and speed")
	var two := AudioStreamPlayer2D.new()
	root.add_child(two)
	ArenaAudioMix.route(two)
	check(two.bus==&"Combat","positional footsteps share protected mix")
	one.queue_free(); two.queue_free()
	await process_frame
	print("Audio mix checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
