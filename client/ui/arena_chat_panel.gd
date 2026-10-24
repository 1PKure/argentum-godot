class_name ArenaChatPanel
extends VBoxContainer
var history: RichTextLabel
var input: LineEdit
var feedback: Label
var send_button: Button
func _ready() -> void:
	custom_minimum_size.x = 260
	add_theme_constant_override("separation",10)
	var title := Label.new()
	title.text = "Chat de la sala"
	add_child(title)
	history = RichTextLabel.new()
	history.bbcode_enabled = false
	history.selection_enabled = true
	history.scroll_following = true
	history.focus_mode = Control.FOCUS_NONE
	history.custom_minimum_size = Vector2(260,220)
	history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history.add_theme_font_size_override("normal_font_size",14)
	add_child(history)
	input = LineEdit.new()
	input.placeholder_text = "Escribí un mensaje…"
	input.max_length = ArenaChatService.MAX_LENGTH
	add_child(input)
	input.text_submitted.connect(func(_value: String) -> void: _send())
	input.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
			input.release_focus()
			accept_event()
	)
	send_button = Button.new()
	send_button.text = "Enviar"
	send_button.focus_mode = Control.FOCUS_NONE
	add_child(send_button)
	send_button.pressed.connect(_send)
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.add_theme_font_size_override("font_size",13)
	add_child(feedback)
	ChatNetwork.changed.connect(_refresh)
	ChatNetwork.completed.connect(func(ok: bool,message: String) -> void:
		feedback.text = "" if ok else message
		if ok: input.clear()
	)
	LobbyNetwork.changed.connect(func() -> void:
		if LobbyNetwork.room.is_empty(): input.clear(); feedback.text = ""
	)
	_refresh()
func _send() -> void:
	ChatNetwork.send(input.text)
func _refresh() -> void:
	if not is_instance_valid(history): return
	history.clear()
	for message: Dictionary in ChatNetwork.messages:
		history.add_text("%s: %s\n" % [message.nickname,message.text])
	send_button.disabled = ChatNetwork.pending or LobbyNetwork.room.is_empty()
	input.editable = not ChatNetwork.pending
