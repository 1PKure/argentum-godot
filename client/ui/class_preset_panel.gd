class_name ClassPresetPanel
extends CanvasLayer

signal opened_changed(opened: bool)
var selector: OptionButton
var apply_button: Button
var details: Label
var message: Label
var _gear: VBoxContainer
var _preview: PlayerVisual
var _current_class := 1
var _pending := false
var _request_generation := 0


func _ready() -> void:
	layer = 15
	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.025, 0.02, 0.85)
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(550, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("151812")
	style.border_color = Color("756441")
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var title := Label.new()
	title.text = "Clases y presets de arena"
	title.add_theme_font_size_override("font_size", 23)
	content.add_child(title)
	selector = OptionButton.new()
	selector.name = "ClassSelector"
	selector.focus_mode = Control.FOCUS_NONE
	for id: int in ClassCatalog.all_ids():
		selector.add_item(str(ClassCatalog.get_profile(id).name), id)
	selector.item_selected.connect(func(_index: int) -> void: _show_selected())
	content.add_child(selector)
	var row := HBoxContainer.new()
	content.add_child(row)
	var preview_area := Control.new()
	preview_area.custom_minimum_size = Vector2(110, 130)
	preview_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(preview_area)
	_preview = load("res://client/characters/player_visual.tscn").instantiate()
	preview_area.add_child(_preview)
	_preview.position = Vector2(55, 70)
	details = Label.new()
	details.custom_minimum_size = Vector2(360, 130)
	details.add_theme_font_size_override("font_size", 15)
	row.add_child(details)
	_gear = VBoxContainer.new()
	_gear.custom_minimum_size.y = 150
	content.add_child(_gear)
	var note := Label.new()
	note.text = "Humano · Nivel 50 · Fuerza preparada 28\nCambio libre de preset · Pociones y flechas ilimitadas"
	note.add_theme_font_size_override("font_size", 13)
	content.add_child(note)
	message = Label.new()
	message.custom_minimum_size = Vector2(490, 42)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 13)
	content.add_child(message)
	var buttons := HBoxContainer.new()
	content.add_child(buttons)
	var close := Button.new()
	close.text = "Volver"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_panel)
	buttons.add_child(close)
	apply_button = Button.new()
	apply_button.name = "ApplyClass"
	apply_button.text = "Usar este preset"
	apply_button.focus_mode = Control.FOCUS_NONE
	apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_button.pressed.connect(_apply)
	buttons.add_child(apply_button)
	RecoveryNetwork.action_resolved.connect(_on_result)
	RecoveryNetwork.action_rejected.connect(_on_rejection)
	hide()


func open_panel(class_id: int) -> void:
	_current_class = class_id
	selector.select(selector.get_item_index(class_id))
	message.text = "Tu clase actual: %s." % ClassCatalog.get_profile(class_id).name
	_show_selected()
	show()
	opened_changed.emit(true)


func close_panel() -> void:
	hide()
	opened_changed.emit(false)


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			close_panel()
		get_viewport().set_input_as_handled()


func _show_selected() -> void:
	var profile := ClassCatalog.get_profile(selector.get_selected_id())
	_preview.set_class_id(int(profile.id))
	_preview.set_movement(Vector2.DOWN, true)
	details.text = "Vida: %d · Maná: %d\nGolpe medio: %d · Alcance: %d\nDefensa corporal: %.0f\nResistencia mágica: %.0f%% · Daño mágico: +%.0f%%\n%d hechizos disponibles" % [profile.max_health, profile.max_mana, profile.physical_power, profile.range, profile.armor_points, profile.resistance_percent, profile.magic_bonus, profile.spells.size()]
	for child in _gear.get_children():
		_gear.remove_child(child)
		child.queue_free()
	for slot: String in ["armor", "weapon", "helmet", "shield", "accessory", "ammunition"]:
		var item_id := int(profile[slot])
		if item_id == 0:
			continue
		var item := ClassCatalog.get_item(item_id)
		var row := HBoxContainer.new()
		_gear.add_child(row)
		var icon := TextureRect.new()
		icon.texture = AOResources.get_equipment_icon(item_id)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(26, 26)
		row.add_child(icon)
		var label := Label.new()
		label.text = str(item.get("Name", ""))
		label.add_theme_font_size_override("font_size", 14)
		row.add_child(label)
	apply_button.disabled = _pending
	apply_button.text = "Reiniciar este preset" if int(profile.id) == _current_class else "Usar este preset"


func _apply() -> void:
	if _pending:
		return
	_pending = true
	_request_generation += 1
	var generation := _request_generation
	apply_button.disabled = true
	message.text = "Esperando al servidor…"
	RecoveryNetwork.request_action("class:%d" % selector.get_selected_id())
	await get_tree().create_timer(3.0).timeout
	if _pending and generation == _request_generation:
		_on_rejection("No hubo respuesta. Revisá la conexión.")


func _on_result(event: Dictionary) -> void:
	if str(event.get("action", "")) == "class" and int(event.get("peer_id", 0)) == multiplayer.get_unique_id():
		_pending = false
		_current_class = int(event.class_id)
		close_panel()


func _on_rejection(reason: String) -> void:
	if _pending:
		_pending = false
		message.text = reason
		_show_selected()
