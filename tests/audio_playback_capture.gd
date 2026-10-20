extends SceneTree
var checks := 0
var failures := 0
var record: AudioEffectRecord
var _voices: Array[AudioStreamPlayer] = []
var folder := "/tmp/argentum-audio-capture"
func _initialize() -> void: call_deferred("_run")
func check(value: bool,message: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: ",message)
func capture(label: String) -> void:
	record.set_recording_active(false)
	var wav := record.get_recording()
	wav.save_to_wav(folder.path_join(label+".wav"))
	var peak := 0.0
	var square := 0.0
	var nonzero := 0
	for index in range(0,wav.data.size(),2):
		var value := wav.data.decode_s16(index)/32768.0
		peak = maxf(peak,absf(value))
		square += value*value
		if value!=0: nonzero += 1
	var rms := sqrt(square/maxi(1,wav.data.size()/2))
	print("CAPTURE ",label," duration=",wav.get_length()," peak=",peak," rms=",rms," samples=",nonzero)
	check(wav.get_length()>0.5 and nonzero>1000,"real mixer contains audible samples: "+label)
	check(peak<0.892,"post-mixer output remains below -1dBFS: "+label)
func player(path: String,volume: float = -12.0) -> AudioStreamPlayer:
	var audio := AudioStreamPlayer.new()
	audio.stream = load(path)
	audio.volume_db = volume
	root.add_child(audio)
	_voices.append(audio)
	audio.tree_exited.connect(func() -> void: _voices.erase(audio))
	ArenaAudioMix.route(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()
	return audio
func _run() -> void:
	var configured := OS.get_environment("AO_AUDIO_CAPTURE_DIR")
	if not configured.is_empty(): folder = configured
	DirAccess.make_dir_recursive_absolute(folder)
	ArenaAudioMix.configure()
	var bus := AudioServer.get_bus_index(&"Master")
	record = AudioEffectRecord.new()
	record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus,record)
	for name: String in ["17","18"]:
		var stream := load("res://assets/argentum/source/audio/"+name+".wav") as AudioStreamWAV
		var file := FileAccess.open(folder.path_join("import-"+name+".pcm"),FileAccess.WRITE)
		file.store_buffer(stream.data)
		file.close()
		check(stream.format==AudioStreamWAV.FORMAT_16_BITS,"PCM32 source is actually decoded to 16-bit: "+name)
	record.set_recording_active(true)
	player("res://assets/argentum/source/audio/17.wav",0.0)
	await create_timer(1.8).timeout
	capture("source17-playback")
	record.set_recording_active(true)
	for iteration in range(12):
		# Deliberately exceed legal duel concurrency to exercise the final limiter.
		for source: String in ["113","18","17"]: player("res://assets/argentum/source/audio/"+source+".wav")
		player("res://assets/argentum/custom/audio/melee_hit.wav")
		player("res://assets/argentum/custom/audio/arrow_hit.wav")
		await create_timer(0.12).timeout
	await create_timer(0.35).timeout
	capture("stress-mix")
	for voice in _voices.duplicate():
		if is_instance_valid(voice):
			voice.stop()
			voice.queue_free()
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	record = null
	await create_timer(0.2).timeout
	print("Playback capture checks: %d; failures: %d"%[checks,failures])
	quit(1 if failures else 0)
