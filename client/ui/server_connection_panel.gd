class_name ServerConnectionPanel
extends CanvasLayer

signal connect_requested(url: String)
signal cancel_requested

var _url_input: LineEdit
var _connect_button: Button
var _cancel_button: Button
var _status_label: Label
var _busy := false


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
	_cancel_button.visible = busy
	if busy:
		_url_input.release_focus()


func set_message(message: String, is_error: bool = false) -> void:
	_status_label.text = message
	_status_label.modulate = (
		Color(1.0, 0.65, 0.5)
		if is_error
		else Color(0.76, 0.84, 0.69)
	)


func hide_connection() -> void:
	_url_input.release_focus()
	hide()


func _build_interface() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.04, 0.07, 0.05, 0.88)
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400.0, 0.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.15, 0.1)
	panel_style.border_color = Color(0.45, 0.46, 0.3)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	var title := Label.new()
	title.text = "Argentum Online"
	title.add_theme_font_size_override("font_size", 26)
	title.modulate = Color(0.88, 0.81, 0.58)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Conectate a la Arena de pruebas."
	content.add_child(subtitle)

	_url_input = LineEdit.new()
	_url_input.name = "ServerURL"
	_url_input.placeholder_text = NetworkConstants.get_server_url()
	_url_input.custom_minimum_size.y = 40.0
	_url_input.max_length = 2048
	_url_input.text_submitted.connect(_on_url_submitted)
	content.add_child(_url_input)

	var hint := Label.new()
	hint.text = (
		"Prueba local: iniciá el servidor Godot en esta PC.\n"
		+ "Para una página HTTPS, usá un servidor wss://."
	)
	if OS.has_feature("web"):
		hint.text = "Prueba local: abrí Start-PrivateWebTest.cmd\ny pulsá Conectar."
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(0.65, 0.72, 0.6)
	content.add_child(hint)

	_status_label = Label.new()
	_status_label.name = "ConnectionStatus"
	_status_label.custom_minimum_size.y = 48.0
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	content.add_child(buttons)

	_connect_button = Button.new()
	_connect_button.name = "ConnectButton"
	_connect_button.text = "Conectar"
	_connect_button.custom_minimum_size.y = 40.0
	_connect_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_connect_button.pressed.connect(_request_connection)
	buttons.add_child(_connect_button)

	_cancel_button = Button.new()
	_cancel_button.name = "CancelButton"
	_cancel_button.text = "Cancelar"
	_cancel_button.pressed.connect(_on_cancel_pressed)
	buttons.add_child(_cancel_button)
	_cancel_button.hide()


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
