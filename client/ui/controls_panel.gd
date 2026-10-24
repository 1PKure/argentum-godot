class_name ControlsPanel
extends CanvasLayer

signal opened_changed(opened: bool)
const Presentation := preload("res://client/ui/arena_presentation_theme.gd")
var _capture := ""
var _modifier_pending := 0
var _content: PanelContainer
var _status: Label
var _buttons: Dictionary = {}
var _classic_button: Button
var _macro_rows: Array[Control] = []

func _ready() -> void:
	layer = 30
	var shade := ColorRect.new()
	shade.color = Color(0.02,0.03,0.05,0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	_content = panel
	panel.theme = Presentation.create_theme()
	panel.custom_minimum_size = Vector2(540,0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Label.new()
	title.text = "Controles"
	title.add_theme_font_size_override("font_size",24)
	column.add_child(title)
	_status = Label.new()
	_status.text = "Elegí un atajo para cambiarlo. Esc cancela la captura."
	_status.add_theme_font_size_override("font_size",13)
	column.add_child(_status)
	_classic_button = Button.new()
	_classic_button.toggle_mode = true
	Presentation.secondary(_classic_button)
	_classic_button.pressed.connect(func() -> void:
		_capture = ""
		InputBindings.set_classic_mode(not InputBindings.classic_mode)
		_refresh()
	)
	column.add_child(_classic_button)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0,350)
	column.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for action in InputBindings.all_actions():
		var row := HBoxContainer.new()
		rows.add_child(row)
		if action.begins_with("macro_"): _macro_rows.append(row)
		var label := Label.new()
		label.text = InputBindings.title_for(action)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(160,32)
		Presentation.secondary(button)
		button.pressed.connect(_begin_capture.bind(action))
		row.add_child(button)
		_buttons[action] = button
	var footer := HBoxContainer.new()
	column.add_child(footer)
	var reset := Button.new()
	reset.text = "Restablecer controles"
	Presentation.secondary(reset)
	reset.pressed.connect(func() -> void:
		_capture = ""
		InputBindings.reset_defaults()
		_status.text = "Controles predeterminados restaurados."
	)
	footer.add_child(reset)
	var close := Button.new()
	close.text = "Volver"
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Presentation.primary(close)
	close.pressed.connect(close_panel)
	footer.add_child(close)
	InputBindings.save_failed.connect(func(message: String) -> void: _status.text = message)
	InputBindings.changed.connect(_refresh)
	_refresh()
	hide()

func open_panel() -> void:
	_capture = ""
	_modifier_pending = 0
	InputBindings.release_all()
	show()
	_refresh()
	opened_changed.emit(true)

func close_panel() -> void:
	_capture = ""
	_modifier_pending = 0
	InputBindings.release_all()
	hide()
	opened_changed.emit(false)

func _begin_capture(action: String) -> void:
	_capture = action
	InputBindings.release_all()
	_status.text = "Presioná la nueva tecla para %s. Esc cancela." % InputBindings.title_for(action)
	_refresh()

func _refresh() -> void:
	_classic_button.text = "Clásico activo · Volver a macros" if InputBindings.classic_mode else "Jugar clásico · Sin macros"
	_classic_button.button_pressed = InputBindings.classic_mode
	for row: Control in _macro_rows: row.visible = not InputBindings.classic_mode
	for action: String in _buttons:
		_buttons[action].text = "Presioná una tecla…" if action == _capture else InputBindings.label_for(action)

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey: return
	get_viewport().set_input_as_handled()
	if event.echo: return
	if _capture.is_empty():
		if event.pressed and (InputBindings.matches(event,"menu") or event.keycode == KEY_ESCAPE): close_panel()
		return
	var code := int(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	if event.pressed and code == KEY_ESCAPE:
		_capture = ""
		_modifier_pending = 0
		_status.text = "Cambio cancelado."
		_refresh()
		return
	if code in [KEY_CTRL,KEY_SHIFT,KEY_ALT,KEY_META]:
		if event.pressed:
			_modifier_pending = code
			return
		if _modifier_pending != code: return
	elif not event.pressed: return
	var result: Dictionary = InputBindings.rebind(_capture,event)
	_status.text = result.message
	_modifier_pending = 0
	if result.ok: _capture = ""
	_refresh()
