extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool,message: String) -> void:
	checks += 1
	if not value: failures+=1; print("FAIL: ",message)
func _run() -> void:
	var original := "res://assets/argentum/custom/audio/originals/melee_firefly.wav.source"
	var runtime := "res://assets/argentum/custom/audio/melee_hit.wav"
	check(FileAccess.get_sha256(original)=="fa459580bffd66be4c77a34c242463444439895a7bf994da2dc9ac33903c8b65","supplied original is retained unchanged")
	check(FileAccess.get_sha256(runtime)=="37e371af124d8a75c4072aaf436e26616a04e9d973fe22d7464ca663e203b039","runtime melee matches accepted pre-restoration version")
	var wave := load(runtime) as AudioStreamWAV
	check(wave.stereo and wave.mix_rate==48000 and is_equal_approx(wave.get_length(),0.513),"accepted stereo melee take keeps previous timing")
	check(FileAccess.get_sha256("res://assets/argentum/custom/audio/arrow_hit.wav")=="a0eb5fb1bcbf65291f62ee701d465bec66a8a95aa10dc2b76da8297c91877ed0","approved original arrow bytes stay intact")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/argentum/source/data/footstep_sources.json"))
	check(manifest.client_definition.contains("CargarPasos") and manifest.client_commit=="4364692d990bab56d2ea56b38ae069030e62bd64","step IDs have a pinned official client provenance")
	for file: Dictionary in manifest.files:
		check(FileAccess.get_sha256("res://assets/argentum/source/audio/"+file.file)==file.sha256,"AO20 original footstep has exact resource bytes: "+file.file)
	for arena: String in ["forest","desert","lava","duel_room"]:
		var pattern := ArenaFootstepAudio.pattern_for(arena)
		check(pattern.streams_count==4 and pattern.playback_mode==AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS,"previous four material variants restored: "+arena)
	ArenaAudioMix.configure()
	var bus := AudioServer.get_bus_index(&"Combat")
	check(is_equal_approx(AudioServer.get_bus_volume_db(bus),-3.0) and AudioServer.get_bus_effect_count(bus)==0 and AudioServer.get_bus_effect_count(0)==1,"previous protected mix is restored")
	print("Original audio checks: %d; failures: %d"%[checks,failures])
	quit(1 if failures else 0)
