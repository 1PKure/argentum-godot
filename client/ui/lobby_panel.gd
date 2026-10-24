class_name LobbyPanel
extends CanvasLayer

signal disconnect_requested
signal presets_requested
signal skins_requested
const Palette := preload("res://client/ui/arena_presentation_theme.gd")
var _arena_view := false
var _view_room_id := 0
var _surface: Control
var _content: VBoxContainer
var _browser: VBoxContainer
var _room_content: VBoxContainer
var _name: LineEdit
var _arena: OptionButton
var _rooms: VBoxContainer
var _message: Label
var _countdown: RoundCountdown
var _active := false
var _feedback := ""
var _create_button: Button
var _chat: ArenaChatPanel
var _ranking: RankingPanel
var _controls_panel: ControlsPanel
var _nickname: LineEdit
var _entering := false
var _last_profile_nickname := ""

func _ready() -> void:
	layer = 12
	_surface = Control.new()
	_surface.theme = Palette.create_theme()
	add_child(_surface)
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Palette.BACKGROUND
	_surface.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_surface.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(640,0)
	center.add_child(card)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation",16)
	card.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(608,500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_chat = ArenaChatPanel.new()
	body.add_child(_chat)
	_chat.hide()
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation",14)
	scroll.add_child(_content)
	_browser = VBoxContainer.new()
	_browser.add_theme_constant_override("separation",12)
	_content.add_child(_browser)
	_label(_browser,ArenaBrand.TITLE,28)
	_label(_browser,ArenaBrand.TAGLINE,14)
	_label(_browser,"Creá una sala o elegí un rival. También podés practicar con un bot.",14)
	_label(_browser,"Tu nick",14)
	_nickname = LineEdit.new()
	_nickname.placeholder_text = "Elegí tu nombre de jugador"
	_nickname.max_length = 20
	_browser.add_child(_nickname)
	_name = LineEdit.new()
	_name.placeholder_text = "Nombre de la sala"
	_name.max_length = 28
	_browser.add_child(_name)
	_arena = _arena_selector(_browser)
	_create_button = _button(_browser,"Crear sala",func() -> void:
		_enter_room("create",{"title":_name.text,"arena_id":ArenaData.IDS[_arena.selected]})
	)
	var bar := HBoxContainer.new()
	_browser.add_child(bar)
	_label(bar,"Salas disponibles",18)
	_button(bar,"Actualizar",LobbyNetwork.refresh)
	_rooms = VBoxContainer.new()
	_rooms.add_theme_constant_override("separation",8)
	_browser.add_child(_rooms)
	_room_content = VBoxContainer.new()
	_room_content.add_theme_constant_override("separation",12)
	_content.add_child(_room_content)
	_message = _label(_content,"",14)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var footer := HBoxContainer.new()
	_content.add_child(footer)
	_button(footer,"Desconectar",disconnect_requested.emit)
	_ranking = RankingPanel.new()
	add_child(_ranking)
	_button(footer,"Ranking",_ranking.open)
	_controls_panel = ControlsPanel.new()
	add_child(_controls_panel)
	_button(footer,"Controles / Jugar clásico",_controls_panel.open_panel)
	_countdown = RoundCountdown.new()
	add_child(_countdown)
	SpellNetwork.server_capabilities_received.connect(func(available: bool) -> void:
		if not available: _feedback = "Versión incompatible o servidor sin respuesta. Actualizá y reiniciá el dedicado junto con la web."
		_refresh()
	)
	RankingNetwork.changed.connect(func() -> void:
		var previous := _last_profile_nickname
		_last_profile_nickname = RankingNetwork.nickname
		if not _entering and not _nickname.has_focus() and (_nickname.text.is_empty() or _nickname.text == previous) and not RankingNetwork.nickname.begins_with("Aventurero_"): _nickname.text = RankingNetwork.nickname
	)
	LobbyNetwork.changed.connect(_refresh)
	ArenaNetwork.changed.connect(_refresh)
	LobbyNetwork.completed.connect(func(ok: bool, message: String) -> void:
		_feedback = "" if ok else message
		_refresh()
	)
	ArenaNetwork.completed.connect(func(ok: bool, message: String) -> void:
		_feedback = "" if ok else message
		_refresh()
	)
	hide()

func open_browser() -> void:
	_active = true
	show()
	_feedback = ""
	_last_profile_nickname = RankingNetwork.nickname
	_nickname.text = "" if RankingNetwork.nickname.begins_with("Aventurero_") else RankingNetwork.nickname
	_refresh()

func close_session() -> void:
	_active = false
	_countdown.clear()
	_controls_panel.close_panel()
	_ranking.close()
	hide()

func _refresh() -> void:
	if not _active: return
	var room: Dictionary = LobbyNetwork.room
	var phase := str(room.get("phase",""))
	var room_id := int(room.get("id",0))
	if room_id != _view_room_id:
		_view_room_id = room_id
		_arena_view = false
	if phase in ["countdown","fighting"]: _arena_view = true
	_surface.visible = room.is_empty() or not _arena_view
	if not _surface.visible:
		_ranking.close()
		_controls_panel.close_panel()
	_browser.visible = room.is_empty()
	_create_button.disabled = not LobbyNetwork.available or LobbyNetwork.pending or _entering
	_room_content.visible = not room.is_empty()
	_chat.visible = not room.is_empty()
	_message.text = _feedback if not _feedback.is_empty() else ("Conectando con el directorio de salas…" if not LobbyNetwork.available else "")
	for child in _rooms.get_children():
		_rooms.remove_child(child)
		child.queue_free()
	for entry: Dictionary in LobbyNetwork.rooms:
		var row := HBoxContainer.new()
		_rooms.add_child(row)
		var text := "%s · %s · %d/2" % [entry.title,ArenaData.get_display_name(str(entry.arena_id)),entry.occupancy]
		var label := _label(row,text,15)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var button := _button(row,"Unirse",func() -> void: _enter_room("join",{"room_id":int(entry.id)}))
		button.disabled = _entering or LobbyNetwork.pending or int(entry.occupancy) >= 2 or str(entry.phase) in ["countdown","fighting"]
	if LobbyNetwork.rooms.is_empty(): _label(_rooms,"Todavía no hay salas. Creá la primera.",14)
	for child in _room_content.get_children():
		_room_content.remove_child(child)
		child.queue_free()
	if room.is_empty():
		_countdown.clear()
		return
	_label(_room_content,str(room.title),28)
	_label(_room_content,"Sala #%d · %s" % [int(room.id),ArenaData.get_display_name(str(room.arena_id))],16)
	var own_id := multiplayer.get_unique_id()
	var owner := int(room.owner_id) == own_id
	var editable := phase in ["waiting","result"] and not LobbyNetwork.pending
	var own_ready := false
	for member: Dictionary in room.members:
		_label(_room_content,"%s%s · %s · %s" % [member.name," (vos)" if int(member.peer_id) == own_id else "",ClassCatalog.get_profile(int(member.class_id)).name,"Listo" if bool(member.ready) else "Preparando"],16)
		if int(member.peer_id) == own_id: own_ready = bool(member.ready)
	var options := HBoxContainer.new()
	_room_content.add_child(options)
	var class_selector := _class_selector(options)
	for member: Dictionary in room.members:
		if int(member.peer_id) == own_id: class_selector.select(class_selector.get_item_index(int(member.class_id)))
	class_selector.disabled = not editable
	class_selector.item_selected.connect(func(index: int) -> void: RecoveryNetwork.request_action("class:%d" % class_selector.get_item_id(index)))
	var arena_selector := _arena_selector(options)
	arena_selector.select(ArenaData.IDS.find(str(room.arena_id)))
	arena_selector.disabled = not owner or not editable or ArenaNetwork.pending or bool(ArenaNetwork.state.get("transitioning",false))
	arena_selector.item_selected.connect(func(index: int) -> void: ArenaNetwork.select_arena(ArenaData.IDS[index]))
	if room.members.size() == 1:
		var bot_options := HBoxContainer.new()
		_room_content.add_child(bot_options)
		var bot_class_selector := _class_selector(bot_options)
		bot_class_selector.select(bot_class_selector.get_item_index(int(room.bot_class)))
		bot_class_selector.disabled = not editable
		bot_class_selector.item_selected.connect(func(index: int) -> void:
			LobbyNetwork.command("bot",{"enabled":bool(room.bot_enabled),"class_id":bot_class_selector.get_item_id(index)})
		)
		var bot_button := _button(bot_options,"Quitar bot" if bool(room.bot_enabled) else "Añadir bot",func() -> void:
			LobbyNetwork.command("bot",{"enabled":not bool(room.bot_enabled),"class_id":int(room.bot_class)})
		)
		bot_button.disabled = not editable
		_label(_room_content,"El bot se usa sólo mientras no haya otro jugador.",14)
	if phase == "result":
		var winner := int(room.get("winner_id",0))
		var outcome := "Victoria" if winner == own_id else "Derrota" if winner != 0 else "Ronda interrumpida"
		_label(_room_content,outcome,24)
		if winner == 0: _label(_room_content,str(room.result_text),14)
		_label(_room_content,"Marcá Listo para jugar otra ronda. Podés cambiar clase o arena.",14)
	var collection := HBoxContainer.new()
	_room_content.add_child(collection)
	_button(collection,"Ver preset",presets_requested.emit)
	_button(collection,"Skins",skins_requested.emit)
	var actions := HBoxContainer.new()
	_room_content.add_child(actions)
	var ready_button := _button(actions,"Cancelar Listo" if own_ready else ("Revancha · Listo" if phase == "result" else "Listo"),func() -> void:
		LobbyNetwork.command("ready",{"ready":not own_ready,"revision":int(room.revision)})
	)
	ready_button.disabled = not editable or (room.members.size() < 2 and not bool(room.bot_enabled)) or bool(ArenaNetwork.state.get("transitioning",false))
	_button(actions,"Salir de la sala",func() -> void: LobbyNetwork.command("leave"))
	if not bool(room.bot_enabled):
		_countdown.update_status({"enabled":true,"owner_id":own_id,"round_id":room.round_id,"phase":"active" if phase == "fighting" else phase,"countdown":room.countdown},own_id)
	else: _countdown.clear()

func _enter_room(operation: String, payload: Dictionary) -> void:
	if _entering or LobbyNetwork.pending: return
	_entering = true
	_feedback = "Guardando tu nick…"
	_refresh()
	var ok := await RankingNetwork.ensure_name(_nickname.text)
	_entering = false
	_feedback = "" if ok else RankingNetwork.message
	if ok and _active and LobbyNetwork.room.is_empty(): LobbyNetwork.command(operation,payload)
	_refresh()

func _label(parent: Node, text_value: String, size_value: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size",size_value)
	parent.add_child(label)
	return label

func _button(parent: Node, text_value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	if text_value in ["Crear sala","Listo","Revancha · Listo"]: Palette.primary(button)
	else: Palette.secondary(button)
	button.custom_minimum_size.y = 36
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _arena_selector(parent: Node) -> OptionButton:
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id: String in ArenaData.IDS: selector.add_item(ArenaData.get_display_name(id))
	parent.add_child(selector)
	return selector

func _class_selector(parent: Node) -> OptionButton:
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id: int in ClassCatalog.all_ids(): selector.add_item(str(ClassCatalog.get_profile(id).name),id)
	parent.add_child(selector)
	return selector


func show_room() -> void:
	_arena_view = false
	_refresh()
