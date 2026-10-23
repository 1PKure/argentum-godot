class_name ArenaModernSpellVisual
extends ArenaSpellVisual
## Approved procedural animation, baked offline at24fps into a shared atlas.
var sprite: AnimatedSprite2D
func configure(spell: Dictionary) -> void:
 super.configure(spell)
 set_meta("procedural_only",false)
 set_meta("baked_procedural",true)
 var data:=ArenaBakedSpellAtlas.entry(spell_id)
 var frames:=ArenaBakedSpellAtlas.frames(spell_id)
 if frames==null:return
 lifetime=float(data.lifetime)
 sprite=AnimatedSprite2D.new();sprite.sprite_frames=frames;sprite.centered=false
 sprite.position=Vector2(data.offset[0],data.offset[1])
 add_child(sprite)
func set_age(seconds:float)->void:
 _age=maxf(seconds,0)
 if sprite==null:return
 sprite.frame=mini(int(_age*24),sprite.sprite_frames.get_frame_count("default")-1)
 sprite.visible=_age<lifetime
func _draw()->void:
 pass
