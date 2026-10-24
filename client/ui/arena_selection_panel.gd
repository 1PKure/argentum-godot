class_name ArenaSelectionPanel
extends CanvasLayer

signal opened_changed(opened: bool)
const Palette := preload("res://client/ui/arena_presentation_theme.gd")
var buttons: Dictionary = {}
var card: PanelContainer
var message: Label
var summary: Label
var close_button: Button

func _ready() -> void:
	layer = 15
	var surface := Control.new()
	add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.theme = Palette.create_theme()
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02,0.025,0.04,0.86)
	surface.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	surface.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card = PanelContainer.new()
	card.custom_minimum_size.x = 648
	center.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",10)
	card.add_child(content)
	var title := Label.new()
	title.text = "Arenas"
	title.add_theme_font_size_override("font_size",24)
	content.add_child(title)
	summary = Label.new()
	summary.add_theme_font_size_override("font_size",14)
	content.add_child(summary)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",10)
	content.add_child(grid)
	for id: String in ArenaData.IDS:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel",Palette.box(Palette.BACKGROUND,Palette.BORDER))
		grid.add_child(panel)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation",5)
		panel.add_child(column)
		var name_label := Label.new()
		name_label.text = ArenaData.get_display_name(id)
		column.add_child(name_label)
		var preview := ArenaPreview.new()
		preview.arena_id = id
		column.add_child(preview)
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size.y = 30
		button.tooltip_text = str(ArenaData.get_definition(id).description)
		button.pressed.connect(ArenaNetwork.select_arena.bind(id))
		column.add_child(button)
		buttons[id] = button
	var note := Label.new()
	note.text = "Cambiar reinicia personajes, posiciones y efectos. La ronda interrumpida no da premios."
	note.add_theme_font_size_override("font_size",13)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 590
	content.add_child(note)
	message = Label.new()
	message.add_theme_font_size_override("font_size",14)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(message)
	close_button = Button.new()
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.text = "Volver"
	close_button.custom_minimum_size.y = 32
	close_button.pressed.connect(close_panel)
	content.add_child(close_button)
	ArenaNetwork.changed.connect(_refresh)
	ArenaNetwork.completed.connect(func(ok: bool, text: String) -> void:
		if ok: close_panel()
		else: message.text = text
	)
	hide()

func open_panel() -> void:
	message.text = ""
	_refresh()
	show()
	opened_changed.emit(true)

func close_panel() -> void:
	hide()
	opened_changed.emit(false)

func _refresh() -> void:
	if summary == null: return
	var state: Dictionary = ArenaNetwork.state
	var host := not state.is_empty() and int(state.owner_id) == multiplayer.get_unique_id()
	summary.text = "Elegí el escenario de la arena." if host else "El anfitrión elige el escenario."
	if ArenaNetwork.pending: summary.text = "Cambiando arena…"
	elif bool(state.get("transitioning",false)): summary.text = "Preparando el escenario…"
	for id: String in buttons:
		var current := id == str(state.get("arena_id",""))
		buttons[id].text = "Actual" if current else "Elegir"
		buttons[id].disabled = current or not host or ArenaNetwork.pending or bool(state.get("transitioning",false))
