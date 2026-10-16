class_name ServerConnectionPanel
extends CanvasLayer

const PRESENTATION_THEME := preload("res://client/ui/arena_presentation_theme.gd")

signal connect_requested(url: String)
signal cancel_requested

var _url_input: LineEdit
var _connect_button: Button
var _cancel_button: Button
var _status_label: Label
var _busy := false
var _panel: PanelContainer


func _ready() -> void:
	layer = 20
	_build_interface()
	hide()


func setup(server_url: String) -> void:
	_url_input.text = server_url


func show_connection(message: String = "", is_error: bool = false) -> void:
	show()
	set_busy(false)
	set_message(message, is_error)
	_url_input.grab_focus()


func set_busy(busy: bool) -> void:
	_busy = busy
	_url_input.editable = not busy
	_connect_button.disabled = busy
	_connect_button.text = "Conectando…" if busy else "Conectar a la arena"
	_cancel_button.visible = busy
	if busy:
		_url_input.release_focus()


func set_message(message: String, is_error: bool = false) -> void:
	_status_label.text = message
	_status_label.modulate = PRESENTATION_THEME.ERROR if is_error else PRESENTATION_THEME.MUTED


func hide_connection() -> void:
	_url_input.release_focus()
	hide()


func _build_interface() -> void:
	var overlay := ColorRect.new()
	overlay.color = PRESENTATION_THEME.BACKGROUND
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.theme = PRESENTATION_THEME.create_theme()
	scroll.add_child(center)

	var outer_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		outer_margin.add_theme_constant_override("margin_" + side, 24)
	center.add_child(outer_margin)

	_panel = PanelContainer.new()
	outer_margin.add_child(_panel)
	get_viewport().size_changed.connect(_update_panel_width)
	_update_panel_width()

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	margin.add_child(content)

	var eyebrow := Label.new()
	eyebrow.text = "A R G E N T U M   /   A L P H A"
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.modulate = PRESENTATION_THEME.GOLD
	content.add_child(eyebrow)

	var title := Label.new()
	title.text = "Argentum Online"
	title.add_theme_font_size_override("font_size", 32)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Tu próxima batalla empieza acá."
	subtitle.modulate = PRESENTATION_THEME.MUTED
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(subtitle)

	var divider := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Color("55503f")
	line.thickness = 1
	divider.add_theme_stylebox_override("separator", line)
	content.add_child(divider)

	var section := Label.new()
	section.text = "Arena de pruebas"
	section.add_theme_font_size_override("font_size", 20)
	content.add_child(section)

	var fields := VBoxContainer.new()
	fields.add_theme_constant_override("separation", 8)
	content.add_child(fields)
	var field_label := Label.new()
	field_label.text = "Dirección del servidor"
	field_label.add_theme_font_size_override("font_size", 13)
	field_label.modulate = PRESENTATION_THEME.MUTED
	fields.add_child(field_label)

	_url_input = LineEdit.new()
	_url_input.name = "ServerURL"
	_url_input.placeholder_text = NetworkConstants.get_server_url()
	_url_input.custom_minimum_size.y = 48.0
	_url_input.max_length = 2048
	_url_input.text_submitted.connect(_on_url_submitted)
	fields.add_child(_url_input)

	var hint := Label.new()
	hint.text = (
		"Prueba local: iniciá el servidor Godot en esta PC.\n"
		+ "Para una página HTTPS, usá un servidor wss://."
	)
	if OS.has_feature("web"):
		hint.text = "Prueba local: abrí Start-PrivateWebTest.cmd y pulsá Conectar."
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = PRESENTATION_THEME.MUTED
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fields.add_child(hint)

	_status_label = Label.new()
	_status_label.name = "ConnectionStatus"
	_status_label.custom_minimum_size.y = 48.0
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 14)
	content.add_child(_status_label)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	content.add_child(buttons)

	_connect_button = Button.new()
	_connect_button.name = "ConnectButton"
	_connect_button.text = "Conectar a la arena"
	_connect_button.custom_minimum_size.y = 48.0
	_connect_button.pressed.connect(_request_connection)
	buttons.add_child(_connect_button)

	_cancel_button = Button.new()
	_cancel_button.name = "CancelButton"
	_cancel_button.text = "Cancelar conexión"
	_cancel_button.custom_minimum_size.y = 44.0
	_cancel_button.add_theme_stylebox_override("normal", PRESENTATION_THEME.box(PRESENTATION_THEME.PANEL, Color("646477")))
	_cancel_button.add_theme_color_override("font_color", PRESENTATION_THEME.IVORY)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	buttons.add_child(_cancel_button)
	_cancel_button.hide()

	var footer := Label.new()
	footer.text = "VERSIÓN EN DESARROLLO"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 11)
	footer.modulate = PRESENTATION_THEME.MUTED
	content.add_child(footer)


func _update_panel_width() -> void:
	_panel.custom_minimum_size.x = minf(540.0, maxf(240.0, get_viewport().get_visible_rect().size.x - 48.0))


func _request_connection() -> void:
	if _busy:
		return

	var server_url := _url_input.text.strip_edges()
	if not (
		server_url.begins_with("ws://")
		or server_url.begins_with("wss://")
	):
		set_message("Ingresá una dirección ws:// o wss://.", true)
		return

	connect_requested.emit(server_url)


func _on_url_submitted(_text: String) -> void:
	_request_connection()


func _on_cancel_pressed() -> void:
	cancel_requested.emit()
