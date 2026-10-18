class_name SkinsPanel
extends CanvasLayer

signal opened_changed(opened: bool)
const PRESENTATION := preload("res://client/ui/arena_presentation_theme.gd")
var summary: Label
var progress_bar: ProgressBar
var message: Label
var buttons: Dictionary[String, Button] = {}
var previews: Dictionary[String, Node2D] = {}
var _title: Label
var _names: Dictionary[String, Label] = {}
var _class_id := 1
var _equipped: Dictionary = {}

func _ready() -> void:
	layer = 15
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.01, 0.01, 0.015, 0.8)
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	card.theme = PRESENTATION.create_theme()
	center.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	card.add_child(content)
	_title = _label(content, "Skins", 24)
	summary = _label(content, "", 16)
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(648, 12)
	progress_bar.show_percentage = false
	content.add_child(progress_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	content.add_child(row)
	for skin: Dictionary in SkinCatalog.for_class(_class_id):
		var tile := VBoxContainer.new()
		tile.custom_minimum_size.x = 153
		row.add_child(tile)
		var name_label := _label(tile, str(skin.name), 15)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.custom_minimum_size = Vector2(153, 42)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_names[str(skin.id)] = name_label
		var preview := Control.new()
		preview.custom_minimum_size = Vector2(153, 108)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(preview)
		var avatar := preload("res://client/characters/player_visual.tscn").instantiate()
		preview.add_child(avatar)
		avatar.position = Vector2(76, 52)
		avatar.set_head_id(1)
		previews[str(skin.id)] = avatar
		var requirement := _label(tile, "Original" if int(skin.wins) == 0 else "%d %s" % [skin.wins, "victoria" if int(skin.wins) == 1 else "victorias"], 13)
		requirement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var button := Button.new()
		button.custom_minimum_size.y = 38
		button.focus_mode = Control.FOCUS_NONE
		tile.add_child(button)
		buttons[str(skin.id)] = button
		button.pressed.connect(func() -> void: Skins.select_skin(str(skin.id)))
	_label(content, "Sólo apariencia: conserva las estadísticas y el equipo de tu clase.", 13)
	message = _label(content, "", 13)
	var close := Button.new()
	close.text = "Volver"
	close.focus_mode = Control.FOCUS_NONE
	content.add_child(close)
	close.pressed.connect(close_panel)
	Skins.changed.connect(_refresh)
	_refresh()
	hide()

func open_panel(class_id: int, equipment: Dictionary) -> void:
	_class_id = class_id
	_equipped = equipment.duplicate()
	_refresh()
	show()
	opened_changed.emit(true)

func close_panel() -> void:
	hide()
	opened_changed.emit(false)

func _refresh() -> void:
	var profile: SkinProgress = Skins.progress
	_title.text = "Skins · %s" % ClassCatalog.get_profile(_class_id).name
	var next: Dictionary = {}
	for skin: Dictionary in SkinCatalog.for_class(_class_id):
		var id := str(skin.id)
		var unlocked := SkinCatalog.is_unlocked(id, profile.wins, _class_id)
		_names[id].text = str(skin.name)
		buttons[id].text = "Equipada" if profile.selected == id else "Equipar" if unlocked else "Bloqueada"
		buttons[id].disabled = not unlocked or profile.selected == id
		previews[id].set_loadout(_class_id, _equipped if id == "preset" else {}, id)
		previews[id].modulate = Color.WHITE if unlocked else Color(0.45, 0.45, 0.45)
		if not unlocked and next.is_empty():
			next = skin
	summary.text = "%d %s contra el bot" % [profile.wins, "victoria" if profile.wins == 1 else "victorias"]
	if next.is_empty():
		summary.text += " · Colección completa"
		progress_bar.max_value = 5
		progress_bar.value = 5
	else:
		summary.text += " · %d para %s" % [int(next.wins) - profile.wins, next.name]
		progress_bar.max_value = int(next.wins)
		progress_bar.value = profile.wins
	message.text = "Guardado en este navegador/dispositivo."
	if profile.save_error != OK:
		message.text = "No se pudo guardar. El progreso durará hasta cerrar esta sesión."

func _label(parent: Node, text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
