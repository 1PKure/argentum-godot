class_name ArenaSpellEffect
extends Node2D

var event: Dictionary
var origin := Vector2.ZERO
var target := Vector2.ZERO
var origin_avatar: Node2D
var target_avatar: Node2D
var _elapsed := 0.0
var _lifetime := 1.1
var _sprite: AnimatedSprite2D
var _text: Label
var _words: Label
var _audio: AudioStreamPlayer


func _ready() -> void:
	z_index = PlayerAvatar.EFFECT_Z_INDEX
	# Follow the same interpolated position rendered by PlayerAvatar this frame.
	process_priority = 50
	var spell := SpellCatalog.get_spell(int(event.spell_id))
	var fx_id := int(spell.fx_id)
	# Minor heal has no FXgrh in the DAT; reuse AO20's healing visual.
	if fx_id == 0 and spell.effect == "healing":
		fx_id = 9
	if fx_id > 0:
		_sprite = AOResources.create_fx_sprite(fx_id, false)
		if _sprite != null:
			var frames := _sprite.sprite_frames
			_lifetime = maxf(_lifetime, frames.get_frame_count("default") / frames.get_animation_speed("default"))
			_sprite.scale = Vector2.ONE * ClientWorld.VISUAL_SCALE
			add_child(_sprite)
			_sprite.play()
	var value := ("+" if spell.effect == "healing" else "−") + str(event.amount)
	if spell.effect in ["status", "periodic"]:
		value = str(event.get("status_message", spell.name))
	_text = _make_label(value, target + Vector2(-80, -75), 16)
	_text.size.x = 160
	_text.modulate = Color("a8f0a4") if spell.effect == "healing" else Color("ffb49c")
	_words = _make_label(str(event.words), origin + Vector2(-100, -97), 15)
	_words.size.x = 200
	_update_anchors()
	var sound_path := "res://assets/argentum/source/audio/%d.wav" % int(spell.sound_id)
	if int(spell.sound_id) > 0 and not ResourceLoader.exists(sound_path):
		sound_path = "res://assets/argentum/source/audio/16.wav"
	if ResourceLoader.exists(sound_path):
		_audio = AudioStreamPlayer.new()
		_audio.stream = load(sound_path)
		_audio.volume_db = -12.0
		add_child(_audio)
		_audio.play()


func _process(delta: float) -> void:
	_elapsed += delta
	_update_anchors()
	var fade_start := _lifetime - 0.4
	if _elapsed > fade_start:
		modulate.a = maxf(0.0, 1.0 - (_elapsed - fade_start) / 0.4)
	if _elapsed >= _lifetime:
		queue_free()


func _exit_tree() -> void:
	if is_instance_valid(_audio):
		_audio.stop()
		_audio.stream = null


func _update_anchors() -> void:
	# Caster words and target impact use separate anchors, including when the
	# two players move in different directions. Never rebind a reused peer ID.
	var has_origin := is_instance_valid(origin_avatar) and not origin_avatar.is_queued_for_deletion()
	var has_target := is_instance_valid(target_avatar) and not target_avatar.is_queued_for_deletion()
	_words.visible = has_origin
	_text.visible = has_target
	if has_origin:
		origin = origin_avatar.position
		_words.position = origin + Vector2(-100, -107)
	if has_target:
		target = target_avatar.position
		_text.position = target + Vector2(-80, -85 - _elapsed * 24.0)
	if _sprite != null:
		_sprite.visible = has_target
		if has_target:
			_sprite.position = target + PlayerAvatar.EFFECT_FOOT_POSITION + Vector2(_sprite.get_meta("source_offset", Vector2.ZERO)) * ClientWorld.VISUAL_SCALE
	if not has_origin and not has_target:
		queue_free()


func _make_label(value: String, at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.size = Vector2(70, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = PlayerAvatar.OVERHEAD_Z_INDEX - PlayerAvatar.EFFECT_Z_INDEX
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	return label
