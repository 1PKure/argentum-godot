extends Node2D
var target_avatar: Node2D
var outcome := "evaded"
var _age := 0.0
var _label: Label
func _ready() -> void:
 z_index = PlayerAvatar.OVERHEAD_Z_INDEX
 _label = Label.new()
 _label.text = "Bloqueó" if outcome == "blocked" else "Esquivó"
 _label.position = Vector2(-70,-50)
 _label.size.x = 140
 _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 _label.add_theme_font_size_override("font_size",14)
 _label.add_theme_color_override("font_color",Color("ecd391"))
 _label.add_theme_color_override("font_shadow_color",Color.BLACK)
 _label.add_theme_constant_override("shadow_offset_y",1)
 add_child(_label)
func _process(delta: float) -> void:
 _age += delta
 if _age>=0.7 or not is_instance_valid(target_avatar) or target_avatar.is_queued_for_deletion():
  queue_free(); return
 position = target_avatar.position + Vector2(0,-_age*18)
 modulate.a = minf(1, (0.7-_age)*5)
