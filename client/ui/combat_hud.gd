class_name CombatHUD
extends Control

signal disconnect_requested
signal modal_changed(blocked: bool)

const PALETTE := preload("res://client/ui/arena_presentation_theme.gd")
const ART := "res://assets/argentum/interface/ao20/"
const DESIGN_SIZE := Vector2(1280, 800)
const WORLD_RECT := Rect2(8, 152, 736, 608)

var console: CombatConsole
var game_area: Control
var _frame: Control
var _world: Node2D
var _players: Dictionary[int, PlayerState] = {}
var _local_peer_id := 0
var _name_label: Label
var _connection_label: Label
var _position_label: Label
var _health_label: Label
var _mana_label: Label
var _health_bar: ProgressBar
var _mana_bar: ProgressBar
var _minimap: ArenaMinimap
var _inventory_panel: Control
var _spell_panel: Control
var _menu_panel: Control
var _menu_card: PanelContainer
var _menu_close_button: Button
var _menu_disconnect_button: Button
var _menu_credits: Label
var _inventory_button: Button
var _spell_button: Button
var _spell_controller: SpellTargetingController
var _spell_buttons: Dictionary[int, SpellSlotButton] = {}
var _hotkey_buttons: Array[SpellSlotButton] = []
var _launch_button: Button
var _spell_status: Label
var _controls_hint: Label
var _header_art: Panel
var _world_art: Panel
var _side_art: Panel
var _filter_buttons: Array[Button] = []
var _session_title: Label
var _spell_search: LineEdit
var _show_catalog: CheckButton
var _spell_scroll: ScrollContainer
var _spell_list: VBoxContainer
var _status_label: Label
var _menu_button: Button
var _stats_button: Button
var _close_button: Button
var _reserved_buttons: Array[Button] = []
var _inventory_slots: Array[InventorySlotButton] = []
var _inventory_layout := ArenaInventoryLayout.new()
var _bottom_back: Panel
var _class_panel: ClassPresetPanel
var _bot_panel: BotPracticePanel
var _skins_panel: SkinsPanel
var _arena_panel: ArenaSelectionPanel
var _menu_arenas_button: Button
var _last_arena_revision := -1
var _round_countdown: RoundCountdown
var _last_bot_phase := "idle"
var _last_bot_owner := 0
var _inventory_move: Dictionary = {}
var _inventory_move_start := Vector2.ZERO
var _inventory_move_preview: TextureRect
var _book_class_id := -1
var _inventory_revision := -1
var _inventory_peer := 0
var _pixel_scale := 1
var _brand: Label
var _brand_detail: Label
var _console_back: Panel
var _macro_back: Panel
var _console_title: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inventory_layout.restore()
	_build_interface()
	_inventory_move_preview = TextureRect.new()
	_inventory_move_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inventory_move_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_inventory_move_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_inventory_move_preview.size = Vector2(32, 32)
	_inventory_move_preview.modulate.a = 0.85
	_inventory_move_preview.z_index = 100
	_inventory_move_preview.hide()
	add_child(_inventory_move_preview)
	get_viewport().size_changed.connect(_fit_interface)
	_fit_interface()
	PlayerNetwork.basic_attack_resolved.connect(_on_basic_attack_event)
	PlayerNetwork.snapshot_received.connect(_on_snapshot_received)
	PlayerNetwork.player_spawned.connect(_on_player_spawned)
	PlayerNetwork.player_despawned.connect(_on_player_despawned)
	PlayerNetwork.player_moved.connect(_on_player_moved)
	PlayerNetwork.player_stats_updated.connect(_on_player_stats_updated)
	SpellNetwork.spell_resolved.connect(_on_spell_event)
	RecoveryNetwork.action_resolved.connect(_on_recovery_event)
	RecoveryNetwork.selection_changed.connect(_refresh_potion_selection)
	BotNetwork.changed.connect(_on_bot_status)
	ArenaNetwork.changed.connect(_on_arena_status)
	Skins.victory_awarded.connect(func(result: Dictionary) -> void:
		var class_id := int(result.class_id)
		for id: String in result.unlocked:
			console.append_message("Skin desbloqueada: %s. Equipala desde Skins." % SkinCatalog.get_skin(id, class_id).name)
		if bool(result.get("invite_other_class", false)) or bool(result.get("all_collections_complete", false)):
			set_menu_opened(false)
			_class_panel.close_panel()
			_skins_panel.close_panel()
			_arena_panel.close_panel()
			if _spell_controller != null:
				_spell_controller.cancel_targeting()
			_bot_panel.show_collection_result(result)
	)
	InventoryNetwork.rejected.connect(func(message: String) -> void: console.append_message(message))
	RecoveryNetwork.action_rejected.connect(func(message: String) -> void: console.append_message(message))
	show_inventory()
	_update_local_stats()
	console.append_message("Bienvenido a la arena PvP.")


func mount_world(world: Node2D) -> void:
	_world = world
	_world.reparent(game_area)
	_world.configure_viewport(game_area.size)
	_update_pixel_scale()


func configure_spells(controller: SpellTargetingController) -> void:
	_spell_controller = controller
	controller.changed.connect(_update_spell_ui)
	controller.feedback.connect(console.append_message)
	_update_spell_ui()


func _update_spell_ui() -> void:
	if _spell_controller == null:
		return
	for id: int in _spell_buttons:
		_spell_buttons[id].button_pressed = id == _spell_controller.selected_spell_id
	for index in range(_hotkey_buttons.size()):
		var id: int = _spell_controller.bindings[index]
		if _hotkey_buttons[index].spell_id != id or _hotkey_buttons[index].class_id != _spell_controller.class_id:
			_hotkey_buttons[index].configure(id, index, _spell_controller.class_id)
		_hotkey_buttons[index].button_pressed = id != 0 and id == _spell_controller.aimed_spell_id
	_launch_button.disabled = not _spell_controller.can_launch()
	_launch_button.modulate = Color.WHITE if not _launch_button.disabled else Color(0.55, 0.55, 0.55)
	_controls_hint.text = ""
	_spell_status.text = ""
	if _spell_controller.aimed_attack:
		_controls_hint.text = "Arco · Elegí un objetivo"
		_spell_status.text = ""
	elif _spell_controller.aimed_spell_id != 0:
		var spell := SpellCatalog.get_spell(_spell_controller.aimed_spell_id)
		_controls_hint.text = "%s · Elegí un objetivo" % spell.name
		_spell_status.text = ""
	elif _spell_controller.pending_request != 0:
		_spell_status.text = "Esperando el resultado…"
	elif not _spell_controller.server_ready:
		_spell_status.text = "Esperando al servidor de combate…"
	var selected := SpellCatalog.get_spell(_spell_controller.selected_spell_id)
	if not selected.is_empty() and not str(selected.unavailable_reason).is_empty():
		_spell_status.text = str(selected.unavailable_reason)
	elif not selected.is_empty() and not ClassCatalog.can_cast(_spell_controller.class_id, int(selected.id)):
		_spell_status.text = "Tu clase no tiene este hechizo en su preset."
	if _book_class_id != _spell_controller.class_id:
		_book_class_id = _spell_controller.class_id
		_filter_spellbook()
	_spell_status.tooltip_text = _spell_status.text
	_update_recovery_controls()


func _on_spell_selected(id: int) -> void:
	_release_text_focus()
	if _spell_controller != null:
		_spell_controller.select_spell(id)


func _on_hotkey_pressed(slot: int) -> void:
	_release_text_focus()
	if _spell_controller != null:
		_spell_controller.aim_hotkey(slot)


func _on_hotkey_assigned(slot: int, id: int) -> void:
	if _spell_controller != null:
		_spell_controller.assign_hotkey(slot, id)


func _on_launch_pressed() -> void:
	_release_text_focus()
	if _spell_controller != null:
		_spell_controller.aim_selected()


func _on_spell_event(event: Dictionary) -> void:
	if _local_peer_id == 0 or (_local_peer_id != int(event.caster_id) and _local_peer_id != int(event.target_id)):
		return
	var own_cast := int(event.caster_id) == _local_peer_id
	var own_target := int(event.target_id) == _local_peer_id
	var target := "vos" if own_target else str(event.target_name)
	var text_value := ""
	if event.get("action", "") == "shot":
		text_value = "Le disparaste a %s" % target if own_cast else "%s te disparó" % event.caster_name
	elif own_cast:
		text_value = "Te lanzaste %s" % event.spell_name if own_target else "Lanzaste %s a %s" % [event.spell_name, target]
	else:
		text_value = "%s te lanzó %s" % [event.caster_name, event.spell_name]
	if int(event.amount) > 0:
		text_value += " · %d" % int(event.amount)
	console.append_message(text_value + ".", "healing" if str(event.effect) == "healing" else "damage")


func _on_basic_attack_event(event: Dictionary) -> void:
	if _local_peer_id == int(event.caster_id):
		console.append_message("Golpeaste a %s · %d." % [event.target_name, event.amount], "damage")
	elif _local_peer_id == int(event.target_id):
		console.append_message("%s te golpeó · %d." % [event.caster_name, event.amount], "damage")


func start_session(peer_id: int) -> void:
	_local_peer_id = peer_id
	_players.clear()
	console.clear_session()
	console.append_message("Conectado a la arena.")
	_connection_label.text = "Conectado · PvP"
	_update_local_stats()


func end_session(message: String) -> void:
	_cancel_inventory_move()
	set_menu_opened(false)
	_class_panel.close_panel()
	_bot_panel.close_panel()
	_skins_panel.close_panel()
	_arena_panel.close_panel()
	_round_countdown.clear()
	_players.clear()
	_local_peer_id = 0
	_connection_label.text = "Sin conexión"
	console.append_message(message)
	_update_local_stats()


func show_inventory() -> void:
	_inventory_panel.show()
	_spell_panel.hide()
	_inventory_button.button_pressed = true
	_spell_button.button_pressed = false


func show_spells() -> void:
	_cancel_inventory_move()
	_inventory_panel.hide()
	_spell_panel.show()
	_inventory_button.button_pressed = false
	_spell_button.button_pressed = true


func _build_interface() -> void:
	theme = PALETTE.create_theme()
	var backdrop := ColorRect.new()
	backdrop.color = PALETTE.BACKGROUND
	backdrop.z_index = -30
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame = _control(self,"ArenaInterface",Rect2(Vector2.ZERO,DESIGN_SIZE))
	_header_art = _surface(_frame,PALETTE.PANEL,PALETTE.BORDER)
	_world_art = _surface(_frame,Color("0b1119"),PALETTE.BORDER)
	_side_art = _surface(_frame,PALETTE.PANEL,PALETTE.BORDER)
	_console_back = _surface(_frame,PALETTE.PANEL,PALETTE.BORDER)
	_macro_back = _surface(_frame,PALETTE.PANEL,PALETTE.BORDER)
	_brand = _label(_frame,"ARGENTUM",Rect2(32,20,200,30),24)
	_brand.add_theme_color_override("font_color",PALETTE.IVORY)
	_brand_detail = _label(_frame,"A R E N A   /   P V P",Rect2(34,49,200,18),10)
	_brand_detail.add_theme_color_override("font_color",PALETTE.GOLD)
	_session_title = _label(_frame,"DUELO DE PRÁCTICA",Rect2(270,32,340,25),14)
	_session_title.add_theme_color_override("font_color",PALETTE.MUTED)
	game_area = _control(_frame,"GameArea",WORLD_RECT)
	game_area.clip_contents = true
	console = CombatConsole.new()
	console.name = "CombatConsole"
	_frame.add_child(console)
	_console_title = _label(_frame,"REGISTRO",Rect2(),11)
	_console_title.add_theme_color_override("font_color",PALETTE.GOLD)
	var filter_group := ButtonGroup.new()
	for index in range(3):
		var button := _text_button(_frame,["Todo","Combate","Sistema"][index],Rect2())
		button.toggle_mode = true
		button.button_group = filter_group
		button.button_pressed = index == 0
		button.pressed.connect(console.set_channel_filter.bind(["all","combat","system"][index]))
		_filter_buttons.append(button)
	_controls_hint = _label(_frame,"",Rect2(),13)
	_controls_hint.add_theme_color_override("font_color",PALETTE.IVORY)
	_minimap = ArenaMinimap.new()
	_frame.add_child(_minimap)
	_minimap.size = Vector2(72,64)
	_name_label = _label(_frame,"Sin personaje",Rect2(),17)
	_position_label = _label(_frame,"Bosque",Rect2(),13)
	_position_label.add_theme_color_override("font_color",PALETTE.MUTED)
	_connection_label = _label(_frame,"Sin conexión",Rect2(),12)
	_connection_label.add_theme_color_override("font_color",PALETTE.GOLD)
	_status_label = _label(_frame,"",Rect2(),12)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.max_lines_visible = 2
	_status_label.z_index = 1
	_status_label.clip_text = true
	_inventory_panel = _control(_frame,"InventoryPanel",Rect2())
	_inventory_panel.clip_contents = true
	_spell_panel = _control(_frame,"SpellPanel",Rect2())
	_spell_panel.clip_contents = true
	_inventory_button = _text_button(_frame,"Inventario",Rect2())
	_inventory_button.toggle_mode = true
	_inventory_button.pressed.connect(show_inventory)
	_spell_button = _text_button(_frame,"Hechizos",Rect2())
	_spell_button.toggle_mode = true
	_spell_button.pressed.connect(show_spells)
	for index in range(42):
		var slot := InventorySlotButton.new()
		_inventory_panel.add_child(slot)
		slot.position = Vector2(4+(index%6)*44,8+(index/6)*44)
		slot.size = Vector2(40,40)
		slot.configure(index,_inventory_layout)
		slot.item_used.connect(_use_inventory_item)
		slot.item_dropped.connect(_move_inventory_item)
		slot.move_started.connect(_begin_inventory_move)
		_inventory_slots.append(slot)
	_spell_search = LineEdit.new()
	_spell_search.placeholder_text = "Buscar hechizo…"
	_spell_panel.add_child(_spell_search)
	_spell_search.position = Vector2(0,4)
	_spell_search.size = Vector2(264,34)
	_spell_search.text_changed.connect(func(_value: String) -> void: _filter_spellbook())
	_spell_search.text_submitted.connect(func(_value: String) -> void: _spell_search.release_focus())
	_show_catalog = CheckButton.new()
	_show_catalog.text = "Catálogo completo"
	_show_catalog.focus_mode = Control.FOCUS_NONE
	_show_catalog.add_theme_font_size_override("font_size",12)
	_spell_panel.add_child(_show_catalog)
	_show_catalog.position = Vector2(0,42)
	_show_catalog.size = Vector2(264,28)
	_show_catalog.toggled.connect(func(_value: bool) -> void: _filter_spellbook())
	_spell_scroll = ScrollContainer.new()
	_spell_panel.add_child(_spell_scroll)
	_spell_scroll.position = Vector2(0,78)
	_spell_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_spell_scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_NONE
	_spell_list = VBoxContainer.new()
	_spell_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spell_list.add_theme_constant_override("separation",6)
	_spell_scroll.add_child(_spell_list)
	for id: int in SpellCatalog.all_ids():
		var entry := SpellSlotButton.new()
		entry.configure(id)
		_spell_list.add_child(entry)
		entry.custom_minimum_size = Vector2(244,54)
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.pressed.connect(_on_spell_selected.bind(id))
		_spell_buttons[id] = entry
	_spell_status = _label(_spell_panel,"",Rect2(),12)
	_spell_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_spell_status.max_lines_visible = 2
	_spell_status.clip_text = true
	_spell_status.mouse_filter = Control.MOUSE_FILTER_PASS
	_launch_button = _text_button(_spell_panel,"Lanzar",Rect2())
	_launch_button.name = "LaunchButton"
	_launch_button.disabled = true
	PALETTE.primary(_launch_button)
	_launch_button.tooltip_text = "Elegí un hechizo y después un objetivo."
	_launch_button.pressed.connect(_on_launch_pressed)
	_bottom_back = _surface(_frame,Color("121b28"),PALETTE.BORDER)
	_health_bar = _resource_bar(Color("d65d70"))
	_mana_bar = _resource_bar(Color("65a5df"))
	_health_label = _label(_frame,"—",Rect2(),13)
	_mana_label = _label(_frame,"—",Rect2(),13)
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_menu()
	_menu_button = _text_button(_frame,"Menú",Rect2())
	_menu_button.pressed.connect(func() -> void: set_menu_opened(not _menu_panel.visible))
	_close_button = _text_button(_frame,"×",Rect2())
	_close_button.tooltip_text = "Desconectarse"
	_close_button.pressed.connect(disconnect_requested.emit)
	for index in range(4):
		_reserved_buttons.append(_text_button(_frame,"",Rect2()))
	_class_panel = ClassPresetPanel.new()
	add_child(_class_panel)
	_class_panel.opened_changed.connect(func(_opened: bool) -> void: _notify_modal_state())
	_bot_panel = BotPracticePanel.new()
	add_child(_bot_panel)
	_bot_panel.opened_changed.connect(func(_opened: bool) -> void: _notify_modal_state())
	_bot_panel.try_class_requested.connect(func(id: int) -> void:
		_open_classes()
		if id != 0 and _class_panel.visible:
			_class_panel.selector.select(_class_panel.selector.get_item_index(id))
			_class_panel.selector.item_selected.emit(_class_panel.selector.selected)
	)
	_skins_panel = SkinsPanel.new()
	add_child(_skins_panel)
	_skins_panel.opened_changed.connect(func(_opened: bool) -> void: _notify_modal_state())
	_arena_panel = ArenaSelectionPanel.new()
	add_child(_arena_panel)
	_arena_panel.opened_changed.connect(func(_opened: bool) -> void: _notify_modal_state())
	_round_countdown = RoundCountdown.new()
	game_area.add_child(_round_countdown)
	_reserved_buttons[3].text = "Skins"
	_reserved_buttons[3].tooltip_text = "Atuendos desbloqueados al vencer al bot"
	_reserved_buttons[3].pressed.connect(_open_skins)
	_reserved_buttons[0].text = "Clases"
	_reserved_buttons[0].tooltip_text = "Ver y elegir clases, equipo y estadísticas."
	_reserved_buttons[0].pressed.connect(_open_classes)
	_reserved_buttons[2].text = "Bot"
	_reserved_buttons[2].tooltip_text = "Práctica con bot"
	_reserved_buttons[2].pressed.connect(_open_bot)
	_reserved_buttons[1].text = "Zoom 1×"
	_reserved_buttons[1].tooltip_text = "Acercar / alejar el mundo"
	_reserved_buttons[1].pressed.connect(func() -> void:
		_pixel_scale = 1 if _pixel_scale == 2 else 2
		_reserved_buttons[1].text = "Zoom %d×" % _pixel_scale
		_update_pixel_scale()
	)
	for index in range(10):
		var macro := SpellSlotButton.new()
		macro.configure(0, index)
		_frame.add_child(macro)
		macro.size = Vector2(48, 52)
		macro.pressed.connect(_on_hotkey_pressed.bind(index))
		macro.spell_dropped.connect(_on_hotkey_assigned)
		_hotkey_buttons.append(macro)
	# GUI hit testing follows sibling order, independently of drawing z_index.
	_frame.move_child(_menu_panel, _frame.get_child_count() - 1)
	_filter_spellbook()


func _build_menu() -> void:
	_menu_panel = _control(_frame, "MenuPanel", Rect2(Vector2.ZERO, DESIGN_SIZE))
	_menu_panel.z_index = 100
	_menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			set_menu_opened(false)
			get_viewport().set_input_as_handled()
	)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.01, 0.01, 0.01, 0.75)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_panel.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_panel.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_card = PanelContainer.new()
	_menu_card.name = "MenuCard"
	_menu_card.custom_minimum_size.x = 440
	_menu_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = PALETTE.PANEL
	style.border_color = PALETTE.BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(22)
	_menu_card.add_theme_stylebox_override("panel", style)
	center.add_child(_menu_card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	_menu_card.add_child(content)
	var title := Label.new()
	title.text = "Controles"
	title.add_theme_font_size_override("font_size", 20)
	content.add_child(title)
	var controls := GridContainer.new()
	controls.columns = 2
	controls.add_theme_constant_override("h_separation", 20)
	controls.add_theme_constant_override("v_separation", 8)
	content.add_child(controls)
	for row: Array in [["WASD", "Movimiento"], ["CTRL", "Ataque físico"], ["1–0", "Accesos rápidos"], ["M", "Meditar"], ["Espacio", "Poción seleccionada (mantener: repetir)"], ["Q / E", "Poción de vida / maná"], ["Esc / clic derecho", "Cancelar apuntado"]]:
		for text_value: String in row:
			var label := Label.new()
			label.text = text_value
			label.add_theme_font_size_override("font_size", 14)
			controls.add_child(label)
	content.add_child(HSeparator.new())
	_menu_credits = Label.new()
	_menu_credits.text = "AO20 · © Noland Studios\nCC BY-NC-ND 4.0\ngithub.com/ao-org/Recursos"
	_menu_credits.add_theme_font_size_override("font_size", 12)
	_menu_credits.modulate = Color("c3b99f")
	content.add_child(_menu_credits)
	_menu_arenas_button = _text_button(content,"Arenas",Rect2())
	_menu_arenas_button.custom_minimum_size.y = 34
	_menu_arenas_button.pressed.connect(_open_arenas)
	_stats_button = _text_button(content, "Reaparecer", Rect2())
	_stats_button.custom_minimum_size.y = 34
	_stats_button.pressed.connect(func() -> void:
		set_menu_opened(false)
		_request_recovery("respawn")
	)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	content.add_child(actions)
	_menu_disconnect_button = _text_button(actions, "Desconectarse", Rect2())
	_menu_close_button = _text_button(actions, "Volver", Rect2())
	for button: Button in [_menu_disconnect_button, _menu_close_button]:
		button.custom_minimum_size.y = 34
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_close_button.pressed.connect(set_menu_opened.bind(false))
	_menu_disconnect_button.pressed.connect(func() -> void:
		set_menu_opened(false)
		disconnect_requested.emit()
	)
	_menu_panel.hide()


func is_modal_open() -> bool:
	return _menu_panel.visible or _class_panel.visible or _bot_panel.visible or _skins_panel.visible or _arena_panel.visible


func set_menu_opened(opened: bool) -> void:
	if _menu_panel.visible == opened:
		return
	_menu_panel.visible = opened
	if opened:
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null:
			focused.release_focus()
	_notify_modal_state()


func _notify_modal_state() -> void:
	if _spell_controller != null:
		_spell_controller.input_blocked = is_gameplay_blocked()
	if is_gameplay_blocked() and _spell_controller != null:
		_cancel_inventory_move()
		_spell_controller.cancel_targeting()
	modal_changed.emit(is_gameplay_blocked())


func _input(event: InputEvent) -> void:
	if not _inventory_move.is_empty():
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_cancel_inventory_move()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseMotion:
			_inventory_move_preview.visible = _inventory_move_preview.visible or event.position.distance_to(_inventory_move_start) >= 6.0
			_inventory_move_preview.position = event.position + Vector2(12, 12)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			if _inventory_move_preview.visible and _inventory_panel.visible and not is_modal_open() and _inventory_panel.get_global_rect().has_point(event.position):
				for slot: InventorySlotButton in _inventory_slots:
					if slot.get_global_rect().has_point(event.position):
						slot._drop_data(Vector2.ZERO, _inventory_move)
						break
			_cancel_inventory_move()
			get_viewport().set_input_as_handled()
			return
	if not is_modal_open() or not event is InputEventKey:
		return
	if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _menu_panel.visible:
			set_menu_opened(false)
		elif _arena_panel.visible:
			_arena_panel.close_panel()
		elif _skins_panel.visible:
			_skins_panel.close_panel()
		elif _bot_panel.visible:
			_bot_panel.close_panel()
		else:
			_class_panel.close_panel()
	get_viewport().set_input_as_handled()


func _layout_footer_actions() -> void:
	if _frame == null or _menu_button == null: return
	_menu_button.position = Vector2(_frame.size.x-296,_frame.size.y-58)
	_menu_button.size = Vector2(264,34)


func _frame_patch(region: Rect2, left: int, right: int, top: int, bottom: int) -> NinePatchRect:
	var patch := NinePatchRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load(ART + "es_ventanaprincipal.png")
	atlas.region = region
	patch.texture = atlas
	patch.patch_margin_left = left
	patch.patch_margin_right = right
	patch.patch_margin_top = top
	patch.patch_margin_bottom = bottom
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patch.z_index = -20
	_frame.add_child(patch)
	return patch


func _grh_icon(id: int) -> Texture2D:
	return AOResources.get_icon_texture(id) if id > 0 else null


func _filter_spellbook() -> void:
	var query := _spell_search.text.strip_edges().to_lower()
	for id: int in _spell_buttons:
		var spell := SpellCatalog.get_spell(id)
		_spell_buttons[id].visible = (_show_catalog.button_pressed or ClassCatalog.can_cast(_spell_controller.class_id if _spell_controller != null else ClassCatalog.DEFAULT_CLASS, id)) and (query.is_empty() or str(spell.name).to_lower().contains(query) or str(id) == query)
	_spell_scroll.scroll_vertical = 0


func _open_classes() -> void:
	var state: PlayerState = _players.get(_local_peer_id)
	if state != null and _spell_controller != null and _spell_controller.server_ready:
		set_menu_opened(false)
		_bot_panel.close_panel()
		_skins_panel.close_panel()
		_spell_controller.cancel_targeting()
		_class_panel.open_panel(state.class_id)


func _request_recovery(action: String) -> void:
	_release_text_focus()
	if _spell_controller != null and action not in ["health_potion", "mana_potion"]:
		_spell_controller.cancel_targeting()
	RecoveryNetwork.request_action(action, "click" if action in ["health_potion", "mana_potion"] else "direct")


func _on_recovery_event(event: Dictionary) -> void:
	if int(event.peer_id) != _local_peer_id:
		return
	console.append_message(str(event.message), "system" if event.action in ["meditate", "respawn"] else "healing")
	if event.action in ["health_potion", "mana_potion"] and int(event.peer_id) == _local_peer_id:
		var audio := AudioStreamPlayer.new()
		audio.stream = load("res://assets/argentum/source/audio/135.wav")
		audio.volume_db = -12.0
		add_child(audio)
		audio.finished.connect(audio.queue_free)
		audio.play()


func _update_recovery_controls() -> void:
	if _stats_button == null:
		return
	var state: PlayerState = _players.get(_local_peer_id)
	var ready := _spell_controller != null and _spell_controller.server_ready and state != null
	_stats_button.disabled = not ready or (state != null and state.is_alive)
	_reserved_buttons[0].disabled = not ready
	_reserved_buttons[2].disabled = not ready
	_reserved_buttons[3].disabled = not ready
	if state == null:
		_status_label.text = ""
	elif not state.is_alive:
		_status_label.text = "Fantasma"
	else:
		var labels := state.active_effects.duplicate()
		if state.is_meditating:
			labels.append("Meditando")
		_status_label.text = " · ".join(labels)
	_status_label.tooltip_text = _status_label.text
	_stats_button.visible = state != null and not state.is_alive


func _fit_interface() -> void:
	_cancel_inventory_move()
	var available := get_viewport_rect().size
	var factor := minf(available.x/DESIGN_SIZE.x,available.y/DESIGN_SIZE.y)
	_frame.scale = Vector2.ONE*factor
	_frame.position = Vector2.ZERO
	_frame.size = available/maxf(factor,0.01)
	var width := _frame.size.x
	var height := _frame.size.y
	var side_x := width-312.0
	_header_art.position = Vector2(16,12)
	_header_art.size = Vector2(width-32,64)
	_world_art.position = Vector2(16,88)
	_world_art.size = Vector2(side_x-32,height-348)
	_side_art.position = Vector2(side_x,88)
	_side_art.size = Vector2(296,height-104)
	game_area.position = _world_art.position+Vector2(2,2)
	game_area.size = _world_art.size-Vector2(4,4)
	_console_back.position = Vector2(16,height-152)
	_console_back.size = Vector2(side_x-32,136)
	_console_title.position = Vector2(32,height-142)
	_console_title.size = Vector2(100,25)
	for index in range(3):
		_filter_buttons[index].position = Vector2(144+index*82,height-144)
		_filter_buttons[index].size = Vector2(78,27)
	console.position = Vector2(32,height-108)
	console.size = Vector2(side_x-64,78)
	_controls_hint.position = Vector2(32,height-253)
	_controls_hint.size = Vector2(side_x-64,22)
	_macro_back.position = Vector2((side_x-556)*0.5,height-224)
	_macro_back.size = Vector2(556,60)
	for index in range(_hotkey_buttons.size()):
		_hotkey_buttons[index].position = _macro_back.position+Vector2(10+index*54,4)
	_minimap.position = Vector2(side_x+204,108)
	_name_label.position = Vector2(side_x+16,106)
	_name_label.size = Vector2(180,25)
	_position_label.position = Vector2(side_x+16,134)
	_position_label.size = Vector2(180,25)
	_connection_label.position = Vector2(side_x+16,159)
	_connection_label.size = Vector2(180,22)
	_health_bar.position = Vector2(side_x+16,190)
	_health_bar.size = Vector2(264,23)
	_mana_bar.position = Vector2(side_x+16,221)
	_mana_bar.size = Vector2(264,23)
	_health_label.position = _health_bar.position
	_health_label.size = _health_bar.size
	_mana_label.position = _mana_bar.position
	_mana_label.size = _mana_bar.size
	_inventory_button.position = Vector2(side_x+16,258)
	_spell_button.position = Vector2(side_x+152,258)
	_inventory_button.size = Vector2(128,34)
	_spell_button.size = Vector2(128,34)
	for panel: Control in [_inventory_panel,_spell_panel]:
		panel.position = Vector2(side_x+16,302)
		panel.size = Vector2(264,height-414)
	_spell_scroll.size = Vector2(264,_spell_panel.size.y-166)
	_spell_status.position = Vector2(0,_spell_panel.size.y-80)
	_spell_status.size = Vector2(264,34)
	_launch_button.position = Vector2(0,_spell_panel.size.y-40)
	_launch_button.size = Vector2(264,38)
	_bottom_back.position = Vector2(side_x+8,height-104)
	_bottom_back.size = Vector2(280,80)
	_status_label.position = Vector2(side_x+16,height-98)
	_status_label.size = Vector2(264,28)
	_menu_panel.position = Vector2.ZERO
	_menu_panel.size = _frame.size
	_layout_footer_actions()
	_close_button.position = Vector2(width-56,27)
	_close_button.size = Vector2(28,32)
	for index in range(4):
		_reserved_buttons[index].position = Vector2(width-382+index*80,27)
		_reserved_buttons[index].size = Vector2(76,32)
	if _world != null:
		_world.resize_viewport(game_area.size)
		_update_pixel_scale()


func _on_snapshot_received(players: Array) -> void:
	_players.clear()
	for data: Dictionary in players:
		var state := PlayerState.from_dictionary(data)
		_players[state.peer_id] = state
		if state.peer_id == _local_peer_id and _spell_controller != null:
			_spell_controller.apply_state(data)
	console.append_message("Arena lista · %d jugador(es) conectados." % _players.values().filter(func(player: PlayerState) -> bool: return not player.is_bot).size())
	_update_local_stats()


func _on_player_spawned(data: Dictionary) -> void:
	var state := PlayerState.from_dictionary(data)
	if not _players.has(state.peer_id):
		console.append_message("%s entró a la arena." % _player_name(state))
	_players[state.peer_id] = state
	_update_local_stats()


func _on_player_despawned(peer_id: int) -> void:
	if _players.has(peer_id):
		console.append_message("%s salió de la arena." % _player_name(_players[peer_id]))
	_players.erase(peer_id)
	_update_local_stats()


func _on_player_moved(data: Dictionary) -> void:
	var state := PlayerState.from_dictionary(data)
	_players[state.peer_id] = state
	_update_local_stats()


func _on_player_stats_updated(data: Dictionary) -> void:
	var state := PlayerState.from_dictionary(data)
	var previous: PlayerState = _players.get(state.peer_id)
	if previous != null and state.peer_id == _local_peer_id and previous.class_id == state.class_id and previous.preset_revision == state.preset_revision:
		if previous.is_alive and not state.is_alive:
			console.append_message("Moriste.", "death")
	_players[state.peer_id] = state
	_update_local_stats()


func _player_name(state: PlayerState) -> String:
	return "Tu personaje" if state.peer_id == _local_peer_id else state.display_name


func _update_local_stats() -> void:
	var state: PlayerState = _players.get(_local_peer_id)
	if not _inventory_move.is_empty() and (state == null or not state.is_alive or state.inventory_revision != int(_inventory_move.revision)):
		_cancel_inventory_move()
	_name_label.text = state.display_name if state != null else "Sin personaje"
	if state != null:
		_name_label.tooltip_text = state.display_name
	_health_bar.max_value = state.max_health if state != null else 100
	_mana_bar.max_value = state.max_mana if state != null else 100
	_health_bar.value = state.current_health if state != null else 0
	_mana_bar.value = state.current_mana if state != null else 0
	_health_label.text = "%d / %d" % [state.current_health, state.max_health] if state != null else "—"
	_mana_label.text = "%d / %d" % [state.current_mana, state.max_mana] if state != null else "—"
	_position_label.text = str(ClassCatalog.get_profile(state.class_id).name) if state != null else "Elegí tu clase"
	_session_title.text = ArenaData.get_display_name(str(ArenaNetwork.state.get("arena_id",ArenaData.DEFAULT_ARENA_ID))).to_upper() + "  /  PVP"
	_position_label.tooltip_text = "Casilla %d, %d" % [state.grid_position.x,state.grid_position.y] if state != null else ""
	if state != null and (state.inventory_revision != _inventory_revision or state.peer_id != _inventory_peer):
		_inventory_revision = state.inventory_revision
		_inventory_peer = state.peer_id
		_inventory_layout.apply_state(state)
		for index in range(_inventory_slots.size()):
			_inventory_slots[index].configure(index, _inventory_layout)
	elif state == null:
		_inventory_revision = -1
		_inventory_peer = 0
	_refresh_potion_selection()
	_minimap.players = _players
	_minimap.local_peer_id = _local_peer_id
	_minimap.queue_redraw()
	_update_recovery_controls()


func _begin_inventory_move(source: int, screen_position: Vector2) -> void:
	var state: PlayerState = _players.get(_local_peer_id)
	if is_modal_open() or state == null or not state.is_alive or _spell_controller == null or not _spell_controller.server_ready:
		return
	_release_text_focus()
	_inventory_move = _inventory_slots[source].move_data()
	_inventory_move_start = screen_position
	_inventory_move_preview.texture = _inventory_slots[source].icon
	_inventory_move_preview.position = screen_position + Vector2(12, 12)
	_inventory_move_preview.hide()


func _cancel_inventory_move() -> void:
	_inventory_move.clear()
	if _inventory_move_preview != null:
		_inventory_move_preview.hide()
		_inventory_move_preview.texture = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_inventory_move()


func _move_inventory_item(source: int, destination: int, action: String) -> void:
	if not _inventory_layout.can_move(source, destination, action):
		return
	InventoryNetwork.request_move(source, destination, _inventory_layout.item_id(source), _inventory_layout.revision)


func _use_inventory_item(action: String) -> void:
	if action.begins_with("item:"):
		var index := _inventory_layout.actions.find(action)
		if index >= 0:
			_spell_controller.cancel_targeting()
			InventoryNetwork.request_use(index, _inventory_layout.item_id(index), _inventory_layout.revision)
	else:
		_request_recovery(action)


func _update_pixel_scale() -> void:
	if _world == null:
		return
	var screen_scale := maxf(game_area.get_screen_transform().get_scale().x, 0.01)
	_world.set_pixel_scale(float(_pixel_scale) / screen_scale)


func _control(parent: Node, node_name: String, rect: Rect2) -> Control:
	var control := Control.new()
	control.name = node_name
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(control)
	control.position = rect.position
	control.size = rect.size
	return control


func _picture(parent: Node, filename: String, rect: Rect2) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = load(ART + filename)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(picture)
	picture.position = rect.position
	picture.size = rect.size
	return picture


func _label(parent: Node, text_value: String, rect: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", PALETTE.IVORY)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(label)
	label.position = rect.position
	label.size = rect.size
	return label


func _text_button(parent: Node, text_value: String, rect: Rect2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size",13)
	PALETTE.secondary(button)
	parent.add_child(button)
	button.position = rect.position
	button.size = rect.size
	return button


func _art_button(parent: Node, art_name: String, rect: Rect2) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = load(ART + "es_boton-%s-default.png" % art_name)
	button.texture_hover = load(ART + "es_boton-%s-over.png" % art_name)
	button.texture_pressed = load(ART + "es_boton-%s-off.png" % art_name)
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	button.position = rect.position
	button.size = rect.size
	return button


func _surface(parent: Node, fill: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = -20
	panel.add_theme_stylebox_override("panel",PALETTE.box(fill,border,10))
	parent.add_child(panel)
	return panel

func _resource_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background",PALETTE.box(Color("0d141e"),Color("2a384a"),6))
	bar.add_theme_stylebox_override("fill",PALETTE.box(color,color.lightened(0.15),6))
	_frame.add_child(bar)
	return bar


func _open_bot() -> void:
	if _spell_controller != null and _spell_controller.server_ready and _players.has(_local_peer_id):
		set_menu_opened(false)
		_class_panel.close_panel()
		_skins_panel.close_panel()
		_spell_controller.cancel_targeting()
		_bot_panel.open_panel()


func _on_bot_status() -> void:
	var state: Dictionary = BotNetwork.state
	_round_countdown.update_status(state, _local_peer_id)
	_notify_modal_state()
	var phase := str(state.get("phase", "idle"))
	var owner := int(state.get("owner_id", 0))
	if phase != _last_bot_phase and _local_peer_id != 0:
		if owner == _local_peer_id and phase in ["won", "lost"]:
			console.append_message("Ganaste la práctica." if phase == "won" else "Perdiste la práctica. Podés reiniciar desde Bot.")
		elif phase == "idle" and _last_bot_owner == _local_peer_id and int(state.get("human_count", 0)) > 0:
			console.append_message("Bot desactivado.")
	_last_bot_phase = phase
	_last_bot_owner = owner


func _refresh_potion_selection() -> void:
	for slot: InventorySlotButton in _inventory_slots:
		slot.set_potion_selected(RecoveryNetwork.selected_potion)


func _release_text_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		focused.release_focus()


func is_gameplay_blocked() -> bool:
	return is_modal_open() or bool(ArenaNetwork.state.get("transitioning",false)) or (str(BotNetwork.state.get("phase", "")) == "countdown" and int(BotNetwork.state.get("owner_id", 0)) == _local_peer_id and _local_peer_id != 0)

func _open_skins() -> void:
	var state: PlayerState = _players.get(_local_peer_id)
	if state != null:
		set_menu_opened(false)
		_class_panel.close_panel()
		_bot_panel.close_panel()
		_skins_panel.open_panel(state.class_id, state.equipped_items)


func _open_arenas() -> void:
	if _spell_controller == null or not _spell_controller.server_ready or not _players.has(_local_peer_id): return
	set_menu_opened(false)
	_class_panel.close_panel()
	_bot_panel.close_panel()
	_skins_panel.close_panel()
	_spell_controller.cancel_targeting()
	_arena_panel.open_panel()

func _on_arena_status() -> void:
	var state: Dictionary = ArenaNetwork.state
	if state.is_empty():
		_last_arena_revision = -1
		_minimap.arena_id = ArenaData.DEFAULT_ARENA_ID
	else:
		var revision := int(state.revision)
		if _last_arena_revision >= 0 and revision != _last_arena_revision:
			console.append_message("Arena cambiada: %s." % ArenaData.get_display_name(str(state.arena_id)))
		_last_arena_revision = revision
		_minimap.arena_id = str(state.arena_id)
	_minimap.queue_redraw()
	_update_local_stats()
	_notify_modal_state()
