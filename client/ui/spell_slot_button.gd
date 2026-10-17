class_name SpellSlotButton
extends Button

signal spell_dropped(slot: int, dropped_spell_id: int)

var spell_id := 0
var hotkey_slot := -1
var class_id := 1
var _badge: Label
var _role_badge: Label


func configure(id: int, slot: int = -1, profile_id: int = 1) -> void:
	class_id = profile_id
	spell_id = id
	hotkey_slot = slot
	focus_mode = Control.FOCUS_NONE
	toggle_mode = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	expand_icon = true
	clip_text = true
	add_theme_font_size_override("font_size", 12)
	add_theme_constant_override("icon_max_width", 28)
	var spell := SpellCatalog.get_spell(id)
	if id == ClassCatalog.ATTACK_BINDING:
		text = ""
		var profile := ClassCatalog.get_profile(class_id)
		icon = AOResources.get_equipment_icon(int(profile.weapon))
		tooltip_text = "Disparar · CTRL / 3 → clic en un rival" if class_id == 8 else "Golpear · CTRL / 3"
	elif not spell.is_empty():
		text = "%s\n%d maná%s" % [spell.name, spell.mana, " · Pendiente" if not SpellCatalog.is_available(id) else ""] if slot < 0 else ""
		tooltip_text = "%s\n%s\n%d maná · Arrastrá el hechizo a un acceso para asignarlo." % [spell.name, spell.description, spell.mana]
		# The DAT's minor-heal icon points to a blank cell in the public atlas.
		# Use its existing blue healing icon without modifying the source data.
		var icon_grh := SpellCatalog.display_icon_grh(id)
		icon = AOResources.get_icon_texture(icon_grh) if icon_grh > 0 else null
		if not SpellCatalog.is_available(id):
			tooltip_text += "\n" + str(spell.unavailable_reason)
	else:
		text = ""
		icon = null
		tooltip_text = "Acceso sin asignar. Arrastrá un hechizo hasta acá."
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if slot >= 0 else HORIZONTAL_ALIGNMENT_LEFT
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	if slot >= 0:
		if _badge == null:
			_badge = Label.new()
			_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_badge.add_theme_font_size_override("font_size", 11)
			_badge.add_theme_color_override("font_shadow_color", Color.BLACK)
			_badge.add_theme_constant_override("shadow_offset_x", 1)
			_badge.add_theme_constant_override("shadow_offset_y", 1)
			add_child(_badge)
			_badge.position = Vector2(1, -3)
		_badge.text = str((slot + 1) % 10)
		if _role_badge == null:
			_role_badge = Label.new()
			_role_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_role_badge.add_theme_font_size_override("font_size", 9)
			_role_badge.add_theme_color_override("font_shadow_color", Color.BLACK)
			_role_badge.add_theme_constant_override("shadow_offset_x", 1)
			_role_badge.add_theme_constant_override("shadow_offset_y", 1)
			_role_badge.position = Vector2(1, 24)
			add_child(_role_badge)
		_role_badge.text = ""
		if slot < 4 and not spell.is_empty():
			_role_badge.text = {25: "PAR", 27: "REM"}.get(id, "CURA" if str(spell.effect) == "healing" else "DAÑO")
		if id == ClassCatalog.ATTACK_BINDING:
			_role_badge.text = "ARCO" if class_id == 8 else "GOLPE"
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("181813")
	normal.border_color = Color("534a36")
	normal.set_border_width_all(1)
	add_theme_stylebox_override("normal", normal)
	var selected := normal.duplicate() as StyleBoxFlat
	selected.border_color = Color("d3b878")
	selected.bg_color = Color("302a1e")
	add_theme_stylebox_override("pressed", selected)
	add_theme_stylebox_override("hover", selected)


func _get_drag_data(_position: Vector2) -> Variant:
	if not SpellCatalog.is_available(spell_id):
		return null
	var preview := Label.new()
	preview.text = str(SpellCatalog.get_spell(spell_id).name)
	set_drag_preview(preview)
	return {"type": "ao_spell", "spell_id": spell_id}


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return hotkey_slot >= 0 and data is Dictionary and data.get("type") == "ao_spell" and SpellCatalog.is_available(int(data.get("spell_id", 0)))


func _drop_data(_position: Vector2, data: Variant) -> void:
	spell_dropped.emit(hotkey_slot, int(data.spell_id))
