class_name BotPracticePanel
extends CanvasLayer

signal opened_changed(opened: bool)
signal try_class_requested(class_id: int)
const PRESENTATION := preload("res://client/ui/arena_presentation_theme.gd")
var selector: OptionButton
var start_button: Button
var stop_button: Button
var message: Label
var _summary: Label
var try_class_button: Button
var _collection_result: Dictionary = {}

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
	card.custom_minimum_size = Vector2(470, 0)
	card.theme = PRESENTATION.create_theme()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	card.add_child(content)
	var title := Label.new()
	title.text = "Práctica con bot"
	title.add_theme_font_size_override("font_size", 22)
	content.add_child(title)
	_summary = Label.new()
	_summary.custom_minimum_size.x = 420
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_summary)
	selector = OptionButton.new()
	selector.name = "BotClassSelector"
	selector.focus_mode = Control.FOCUS_NONE
	for id: int in ClassCatalog.all_ids():
		selector.add_item(str(ClassCatalog.get_profile(id).name), id)
	selector.select(selector.get_item_index(3))
	content.add_child(selector)
	var note := Label.new()
	note.text = "Cada ronda comienza con una cuenta de 3 segundos.\nCambiar clase reinicia la ronda. Otro jugador retira al bot."
	note.add_theme_font_size_override("font_size", 13)
	content.add_child(note)
	message = Label.new()
	message.custom_minimum_size = Vector2(420, 38)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(message)
	try_class_button = _button(content, "Probar otra clase")
	try_class_button.pressed.connect(func() -> void:
		var id := int(_collection_result.get("suggested_class_id", 0))
		close_panel()
		try_class_requested.emit(id)
	)
	start_button = _button(content, "Activar bot")
	start_button.name = "StartPracticeBot"
	start_button.pressed.connect(func() -> void: BotNetwork.request_bot(true, selector.get_selected_id()))
	stop_button = _button(content, "Quitar bot")
	stop_button.pressed.connect(func() -> void: BotNetwork.request_bot(false, selector.get_selected_id()))
	_button(content, "Volver").pressed.connect(close_panel)
	BotNetwork.changed.connect(_refresh)
	BotNetwork.completed.connect(func(ok: bool, reason: String) -> void:
		message.text = reason
		if ok:
			close_panel()
	)
	_refresh()
	hide()

func open_panel() -> void:
	_collection_result.clear()
	if bool(BotNetwork.state.get("enabled", false)):
		selector.select(selector.get_item_index(int(BotNetwork.state.class_id)))
	message.text = ""
	_refresh()
	show()
	opened_changed.emit(true)

func show_collection_result(result: Dictionary) -> void:
	_collection_result = result.duplicate()
	_refresh()
	show()
	opened_changed.emit(true)

func close_panel() -> void:
	hide()
	_collection_result.clear()
	opened_changed.emit(false)

func _refresh() -> void:
	var state: Dictionary = BotNetwork.state
	var enabled := bool(state.get("enabled", false))
	var available := int(state.get("human_count", 0)) == 1
	if not available:
		_summary.text = "Disponible cuando estás solo en la arena."
	elif not enabled:
		_summary.text = "Elegí la clase del rival de práctica."
	elif str(state.phase) == "countdown":
		_summary.text = "La ronda comienza en %d…" % int(state.get("countdown", 3))
	elif str(state.phase) == "won":
		_summary.text = "Ganaste la práctica. Podés reiniciar."
	elif str(state.phase) == "lost":
		_summary.text = "Perdiste la práctica. Podés reiniciar."
	else:
		_summary.text = "Bot %s · Práctica activa" % ClassCatalog.get_profile(int(state.class_id)).name
	start_button.text = "Reiniciar práctica" if enabled else "Activar bot"
	start_button.disabled = BotNetwork.pending or not available or not SpellNetwork.server_available
	stop_button.disabled = BotNetwork.pending or not enabled
	selector.disabled = BotNetwork.pending
	try_class_button.visible = not _collection_result.is_empty() and bool(_collection_result.get("invite_other_class", false)) and str(state.get("phase", "")) == "won"
	if try_class_button.visible:
		_summary.text = "Colección de %s completa" % ClassCatalog.get_profile(int(_collection_result.class_id)).name
		message.text = "Ya tenés sus tres skins. Probá %s para desbloquear otra colección." % ClassCatalog.get_profile(int(_collection_result.suggested_class_id)).name
	elif not _collection_result.is_empty() and bool(_collection_result.get("all_collections_complete", false)):
		message.text = "¡Completaste las colecciones de las nueve clases!"
	if BotNetwork.pending:
		message.text = "Esperando al servidor…"

func _button(parent: Node, title: String) -> Button:
	var button := Button.new()
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 36
	parent.add_child(button)
	return button
