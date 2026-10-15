class_name ArenaSpellEffect
extends Node2D

var event: Dictionary
var origin := Vector2.ZERO
var target := Vector2.ZERO
var _elapsed := 0.0
var _lifetime := 1.1
var _sprite: AnimatedSprite2D
var _text: Label
var _words: Label
var _audio: AudioStreamPlayer


func _ready() -> void:
	z_index = 30
	var spell := SpellCatalog.get_spell(int(event.spell_id))
	var fx_id := int(spell.fx_id)
	# Minor heal has no FXgrh in the DAT; reuse AO20's healing visual.
	if fx_id == 0 and spell.effect == "healing":
		fx_id = 9
	var fx := ConfigFile.new()
	if fx.load("res://assets/argentum/source/data/FXs.ini") == OK and fx_id > 0:
		var section := "FX%d" % fx_id
		var animation := AOResources.get_grh_animation(int(fx.get_value(section, "Animacion", 0)))
		if not animation.is_empty():
			_lifetime = maxf(_lifetime, float(animation.frames.size()) / float(animation.fps))
			_sprite = AnimatedSprite2D.new()
			var frames := SpriteFrames.new()
			frames.set_animation_loop("default", false)
			frames.set_animation_speed("default", animation.fps)
			for frame: Dictionary in animation.frames:
				var texture := AtlasTexture.new()
				texture.atlas = AOResources.get_texture(int(frame.file_num))
				texture.region = frame.region
				frames.add_frame("default", texture)
			_sprite.sprite_frames = frames
			_sprite.position = target + Vector2(float(fx.get_value(section, "OffsetX", 0)), float(fx.get_value(section, "OffsetY", 0))) * ClientWorld.VISUAL_SCALE
			_sprite.scale = Vector2.ONE * ClientWorld.VISUAL_SCALE
			_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	_text.position.y -= delta * 24.0
	var fade_start := _lifetime - 0.4
	if _elapsed > fade_start:
		modulate.a = maxf(0.0, 1.0 - (_elapsed - fade_start) / 0.4)
	if _elapsed >= _lifetime:
		queue_free()


func _make_label(value: String, at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.size = Vector2(70, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	return label
