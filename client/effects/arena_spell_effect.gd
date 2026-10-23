class_name ArenaSpellEffect
extends Node2D

const BloodImpact := preload("res://client/effects/arena_blood_impact.gd")

var managed_words := false
var event: Dictionary
var origin := Vector2.ZERO
var target := Vector2.ZERO
var origin_avatar: Node2D
var target_avatar: Node2D
var _elapsed := 0.0
var _lifetime := 1.1
var _sprite: ArenaSpellVisual
var _text: Label
var _words: Label
var _audio: AudioStreamPlayer
var _projectile: Sprite2D
var _is_shot := false
var _shot_sound_played := false
var _blood_active := false
var _blood_age := 0.0
var _blood_origin := Vector2.ZERO
var _blood_direction := Vector2.RIGHT
const BLOOD_SECONDS := 0.50
const BLOOD_ANCHOR_OFFSET := Vector2(0, 4)
const SHOT_TRAVEL_SECONDS := 0.18
const SHOT_IMPACT_SOUND := "res://assets/argentum/custom/audio/arrow_hit.wav"


func _ready() -> void:
	z_index = PlayerAvatar.EFFECT_Z_INDEX
	# Follow the same interpolated position rendered by PlayerAvatar this frame.
	process_priority = 50
	var spell := SpellCatalog.get_spell(int(event.spell_id))
	_is_shot = event.get("action", "") == "shot"
	if _is_shot:
		_lifetime = 0.65
		_projectile = Sprite2D.new()
		_projectile.texture = AOResources.get_equipment_icon(552)
		_projectile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_projectile.scale = Vector2.ONE * ClientWorld.VISUAL_SCALE
		add_child(_projectile)
	else:
		_sprite = ArenaLegacySpellVisual.new() if ArenaVisualSettings.uses_original_fx() else ArenaModernSpellVisual.new()
		_sprite.configure(spell)
		_lifetime = _sprite.lifetime
		add_child(_sprite)
	var value := ("+" if spell.effect == "healing" else "−") + str(event.amount)
	if spell.effect in ["status", "periodic"]:
		value = str(event.get("status_message", spell.name))
	if _is_shot and str(event.get("outcome","")) in ["evaded","blocked"]:
		value = "Bloqueó" if str(event.outcome)=="blocked" else "Esquivó"
	_text = _make_label(value, target + Vector2(-80, -75), 16)
	_text.size.x = 160
	_text.modulate = Color("a8f0a4") if spell.effect == "healing" else Color("ffb49c")
	_words = _make_label(str(event.words), origin + Vector2(-100, -97), 15)
	_words.size.x = 200
	_update_anchors()
	var sound_path := "res://assets/argentum/source/audio/%d.wav" % int(spell.sound_id)
	if int(spell.sound_id) > 0 and not ResourceLoader.exists(sound_path):
		sound_path = "res://assets/argentum/source/audio/16.wav"
	if _is_shot:
		sound_path = SHOT_IMPACT_SOUND
	if ResourceLoader.exists(sound_path):
		_audio = AudioStreamPlayer.new()
		_audio.stream = load(sound_path)
		_audio.volume_db = -12.0
		ArenaAudioMix.route(_audio)
		add_child(_audio)
		if _is_shot:
			_lifetime = maxf(_lifetime, SHOT_TRAVEL_SECONDS + _audio.stream.get_length() + 0.05)
		else:
			# Keep the original sound tail even when the new visual burst is shorter.
			# Visual opacity uses its own duration, so this never leaves text or FX behind.
			_lifetime = maxf(_lifetime, _audio.stream.get_length() + 0.05)
			_audio.play()


func _process(delta: float) -> void:
	_elapsed += delta
	_update_anchors()
	if _sprite != null and _elapsed < _sprite.lifetime + 0.1:
		_sprite.set_age(_elapsed)
	if _is_shot and not _shot_sound_played and _elapsed >= SHOT_TRAVEL_SECONDS:
		_shot_sound_played = true
		if is_instance_valid(target_avatar) and not target_avatar.is_queued_for_deletion():
			if _audio != null and int(event.get("amount",0)) > 0:
				_audio.play()
			if int(event.get("amount", 0)) > 0:
				_blood_active = true
				_blood_direction = (target - origin).normalized()
	if _blood_active:
		_blood_age = maxf(0.0, _elapsed - SHOT_TRAVEL_SECONDS)
		_blood_active = _blood_age < BLOOD_SECONDS and is_instance_valid(target_avatar) and not target_avatar.is_queued_for_deletion()
		queue_redraw()
	var fade_start := (_lifetime if _is_shot else _sprite.lifetime) - 0.4
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
	_words.visible = has_origin and not managed_words
	_text.visible = has_target
	if has_origin:
		origin = origin_avatar.position
		_words.position = origin + Vector2(-100, -107)
	if has_target:
		target = target_avatar.position
		_blood_origin = target + BLOOD_ANCHOR_OFFSET
		_text.position = target + Vector2(-80, -85 - _elapsed * 24.0)
	if _projectile != null:
		var fraction := minf(_elapsed / SHOT_TRAVEL_SECONDS, 1.0)
		_projectile.visible = has_origin and has_target and fraction < 1.0
		_projectile.position = origin.lerp(target, fraction) + Vector2(0, -18)
		_projectile.rotation = (target - origin).angle() + PI / 4.0
		_text.visible = has_target and fraction >= 1.0
	if _sprite != null:
		_sprite.visible = has_target
		if has_target:
			_sprite.position = target + PlayerAvatar.EFFECT_FOOT_POSITION
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


func _draw() -> void:
	if _blood_active:
		BloodImpact.draw_burst(self,_blood_origin,_blood_direction,_blood_age)
