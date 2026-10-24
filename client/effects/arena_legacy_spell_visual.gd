class_name ArenaLegacySpellVisual
extends ArenaSpellVisual
## Original AO atlas animation, without procedural redraws.
var sprite: AnimatedSprite2D
func configure(spell: Dictionary) -> void:
	spell_id = int(spell.get("id", 0))
	source_fx_id = int(spell.get("fx_id", 0))
	if source_fx_id == 0 and spell.get("effect", "") == "healing": source_fx_id = 9
	family = family_for_spell(spell)
	concept = "original_ao_atlas"
	set_meta("modern_fx", false)
	set_meta("procedural_only", false)
	set_meta("foot_anchored", true)
	sprite = AOResources.create_fx_sprite(source_fx_id, false, true) if source_fx_id > 0 else null
	if sprite != null:
		sprite.scale = Vector2.ONE * ClientWorld.VISUAL_SCALE
		add_child(sprite)
		lifetime = sprite.sprite_frames.get_frame_count("default") / sprite.sprite_frames.get_animation_speed("default")
	lifetime = maxf(lifetime, 0.4)
func set_age(seconds: float) -> void:
	_age = maxf(seconds, 0)
	if sprite == null: return
	var frames := sprite.sprite_frames
	var index := mini(int(_age * frames.get_animation_speed("default")), frames.get_frame_count("default") - 1)
	if sprite.frame != index: sprite.frame = index
	sprite.visible = _age < lifetime
func _draw() -> void:
	pass
