class_name RoundCountdown
extends Control

# Driven by authoritative status ticks. Tween/audio are presentation only.
var title: Label
var detail: Label
var _card: PanelContainer
var _audio: AudioStreamPlayer
var _tween: Tween
var _last_round := ""
var _last_count := -1
var _last_phase := "idle"
var _generation := 0
var _tick_sound: AudioStreamWAV
var _go_sound: AudioStreamWAV

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 80
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.custom_minimum_size = Vector2(300, 140)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.03, 0.04, 0.92)
	style.border_color = Color("d6b66a")
	style.set_border_width_all(2)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_card.add_theme_stylebox_override("panel", style)
	center.add_child(_card)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(content)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color("ebce88"))
	content.add_child(title)
	detail = Label.new()
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 15)
	content.add_child(detail)
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -14
	add_child(_audio)
	_tick_sound = _tone(520.0, 0.09)
	_go_sound = _tone(880.0, 0.22)
	hide()

func update_status(state: Dictionary, local_peer_id: int) -> void:
	var phase := str(state.get("phase", "idle"))
	var round_id := str(state.get("round_id", ""))
	var count := int(state.get("countdown", 0))
	if local_peer_id == 0 or int(state.get("owner_id", 0)) != local_peer_id or not bool(state.get("enabled", false)):
		clear()
		return
	if phase == "countdown" and (round_id != _last_round or count != _last_count):
		_present(str(count), "La ronda empieza en…", _tick_sound)
	elif phase == "active" and _last_phase == "countdown" and round_id == _last_round:
		_present("¡YA!", "", _go_sound, 0.65)
	elif phase in ["won", "lost"] and (phase != _last_phase or round_id != _last_round):
		_present("Victoria" if phase == "won" else "Derrota", "+1 victoria · Mirá tus Skins" if phase == "won" else "Podés volver a intentarlo desde Bot", null, 3.0)
	_last_round = round_id
	_last_count = count
	_last_phase = phase

func _present(text_value: String, subtitle: String, sound: AudioStream, duration: float = 0) -> void:
	_generation += 1
	var generation := _generation
	if _tween != null:
		_tween.kill()
	title.text = text_value
	title.add_theme_font_size_override("font_size", 52 if text_value.length() <= 4 else 34)
	detail.text = subtitle
	show()
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2.ONE * 1.12
	_card.modulate.a = 0.6
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_card, "modulate:a", 1.0, 0.15)
	_audio.stop()
	_audio.stream = sound
	if sound != null:
		_audio.play()
	if duration > 0:
		await get_tree().create_timer(duration).timeout
		if is_inside_tree() and generation == _generation:
			hide()

func clear() -> void:
	_generation += 1
	if _tween != null:
		_tween.kill()
	if _audio != null:
		_audio.stop()
		_audio.stream = null
	_last_round = ""
	_last_count = -1
	_last_phase = "idle"
	hide()

func _exit_tree() -> void:
	clear()

static func _tone(frequency: float, seconds: float) -> AudioStreamWAV:
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var samples := int(seconds * sound.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	for i in range(samples):
		var envelope := minf(1.0, i / 120.0) * minf(1.0, (samples - i) / 220.0)
		bytes.encode_s16(i * 2, int(sin(TAU * frequency * i / sound.mix_rate) * 10000 * envelope))
	sound.data = bytes
	return sound
