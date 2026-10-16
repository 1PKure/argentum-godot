class_name CombatHUD
extends Control

signal disconnect_requested

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
var _health_bar: TextureProgressBar
var _mana_bar: TextureProgressBar
var _minimap: ArenaMinimap
var _inventory_panel: Control
var _spell_panel: Control
var _menu_panel: Control
var _inventory_button: TextureButton
var _spell_button: TextureButton
var _selected_inventory_slot: Button
var _spell_controller: SpellTargetingController
var _spell_buttons: Dictionary[int, SpellSlotButton] = {}
var _hotkey_buttons: Array[SpellSlotButton] = []
var _launch_button: TextureButton
var _spell_status: Label
var _controls_hint: Label
var _header_art: NinePatchRect
var _world_art: NinePatchRect
var _side_art: NinePatchRect
var _filter_buttons: Array[Button] = []
var _session_title: Label
var _spell_search: LineEdit
var _show_catalog: CheckButton
var _spell_scroll: ScrollContainer
var _spell_list: VBoxContainer
var _meditate_button: Button
var _health_potion_button: Button
var _mana_potion_button: Button
var _status_label: Label
var _menu_button: Button
var _stats_button: Button
var _close_button: Button
var _reserved_buttons: Array[Button] = []
var _inventory_slots: Array[Button] = []
var _bottom_back: Panel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_interface()
	get_viewport().size_changed.connect(_fit_interface)
	_fit_interface()
	PlayerNetwork.snapshot_received.connect(_on_snapshot_received)
	PlayerNetwork.player_spawned.connect(_on_player_spawned)
	PlayerNetwork.player_despawned.connect(_on_player_despawned)
	PlayerNetwork.player_moved.connect(_on_player_moved)
	PlayerNetwork.player_stats_updated.connect(_on_player_stats_updated)
	SpellNetwork.spell_resolved.connect(_on_spell_event)
	RecoveryNetwork.action_resolved.connect(_on_recovery_event)
	RecoveryNetwork.action_rejected.connect(func(message: String) -> void: console.append_message(message))
	show_inventory()
	_update_local_stats()
	console.append_message("Bienvenido a la arena PvP.")


func mount_world(world: Node2D) -> void:
	_world = world
	_world.reparent(game_area)
	_world.configure_viewport(game_area.size)


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
		if _hotkey_buttons[index].spell_id != id:
			_hotkey_buttons[index].configure(id, index)
		_hotkey_buttons[index].button_pressed = id != 0 and id == _spell_controller.aimed_spell_id
	_launch_button.disabled = not _spell_controller.can_launch()
	_launch_button.modulate = Color.WHITE if not _launch_button.disabled else Color(0.55, 0.55, 0.55)
	_controls_hint.text = "WASD · CTRL golpe · 1–0 hechizos · M meditar · Q vida · E maná"
	_spell_status.text = "Seleccioná un hechizo y pulsá Lanzar."
	if _spell_controller.aimed_spell_id != 0:
		show_spells()
		var spell := SpellCatalog.get_spell(_spell_controller.aimed_spell_id)
		_controls_hint.text = "%s · Elegí un objetivo · Esc o clic derecho para cancelar" % spell.name
		_spell_status.text = "Elegí el objetivo con un clic."
	elif _spell_controller.pending_request != 0:
		_spell_status.text = "Esperando el resultado…"
	elif not _spell_controller.server_ready:
		_spell_status.text = "Esperando al servidor de combate…"
	var selected := SpellCatalog.get_spell(_spell_controller.selected_spell_id)
	if not selected.is_empty() and not str(selected.unavailable_reason).is_empty():
		_spell_status.text = str(selected.unavailable_reason)
	_update_recovery_controls()


func _on_spell_selected(id: int) -> void:
	if _spell_controller != null:
		_spell_controller.select_spell(id)


func _on_hotkey_pressed(slot: int) -> void:
	if _spell_controller != null:
		_spell_controller.aim_hotkey(slot)


func _on_hotkey_assigned(slot: int, id: int) -> void:
	if _spell_controller != null:
		_spell_controller.assign_hotkey(slot, id)


func _on_launch_pressed() -> void:
	if _spell_controller != null:
		_spell_controller.aim_selected()


func _on_spell_event(event: Dictionary) -> void:
	var caster := "Tu personaje" if int(event.caster_id) == _local_peer_id else str(event.caster_name)
	var target := "tu personaje" if int(event.target_id) == _local_peer_id else str(event.target_name)
	var detail := str(event.get("status_message", ""))
	if int(event.amount) > 0:
		detail = "%d" % int(event.amount)
	console.append_message("%s lanzó %s sobre %s (%s)." % [caster, event.spell_name, target, detail], "healing" if str(event.effect) == "healing" else "damage")


func start_session(peer_id: int) -> void:
	_local_peer_id = peer_id
	_players.clear()
	console.clear_session()
	console.append_message("Conectado. Movimiento: WASD · Ataque físico: CTRL.")
	_connection_label.text = "Conectado · PvP"
	_update_local_stats()


func end_session(message: String) -> void:
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
	_inventory_panel.hide()
	_spell_panel.show()
	_inventory_button.button_pressed = false
	_spell_button.button_pressed = true


func _build_interface() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("090b09")
	backdrop.z_index = -30
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame = _control(self, "AO20Frame", Rect2(Vector2.ZERO, DESIGN_SIZE))
	_frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_header_art = _frame_patch(Rect2(0, 0, 752, 152), 150, 110, 32, 8)
	_world_art = _frame_patch(Rect2(0, 152, 752, 616), 8, 8, 0, 60)
	_side_art = _frame_patch(Rect2(752, 0, 272, 768), 0, 0, 160, 270)
	game_area = _control(_frame, "GameArea", WORLD_RECT)
	game_area.clip_contents = true
	console = CombatConsole.new()
	console.name = "CombatConsole"
	_frame.add_child(console)
	var filter_group := ButtonGroup.new()
	for index in range(3):
		var button := _text_button(_frame, ["Todo", "Combate", "Sistema"][index], Rect2(150 + index * 75, 4, 73, 23))
		button.toggle_mode = true
		button.button_group = filter_group
		button.button_pressed = index == 0
		button.pressed.connect(console.set_channel_filter.bind(["all", "combat", "system"][index]))
		_filter_buttons.append(button)
	_session_title = _label(_frame, "Arena PvP · Prueba privada", Rect2(385, 5, 245, 22), 13)
	_controls_hint = _label(_frame, "WASD · CTRL golpe · 1–0 hechizos · M meditar · Q vida · E maná", Rect2(20, 123, 700, 22), 13)
	_minimap = ArenaMinimap.new()
	_frame.add_child(_minimap)
	_minimap.size = Vector2(91, 91)
	_name_label = _label(_frame, "Sin personaje", Rect2(0, 40, 237, 25), 15)
	_position_label = _label(_frame, "Bosque", Rect2(0, 68, 230, 22), 13)
	_connection_label = _label(_frame, "Sin conexión", Rect2(0, 96, 235, 22), 13)
	_status_label = _label(_frame, "", Rect2(0, 124, 235, 30), 12)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inventory_panel = _control(_frame, "InventoryPanel", Rect2(0, 192, 240, 400))
	var inventory_art := _picture(_inventory_panel, "es_centroinventario.png", Rect2(0, 0, 240, 400))
	var inventory_atlas := AtlasTexture.new()
	inventory_atlas.atlas = inventory_art.texture
	inventory_atlas.region = Rect2(0, 32, 247, 293)
	inventory_art.texture = inventory_atlas
	_spell_panel = _control(_frame, "SpellPanel", Rect2(0, 192, 240, 400))
	var spell_background := ColorRect.new()
	spell_background.color = Color("171612")
	spell_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spell_panel.add_child(spell_background)
	spell_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inventory_button = _art_button(_frame, "inventory", Rect2(0, 162, 122, 28))
	_inventory_button.toggle_mode = true
	_inventory_button.texture_normal = load(ART + "es_boton-inventory-off.png")
	_inventory_button.texture_pressed = load(ART + "es_boton-inventory-default.png")
	_inventory_button.pressed.connect(show_inventory)
	_spell_button = _art_button(_frame, "hechizos", Rect2(0, 162, 122, 28))
	_spell_button.toggle_mode = true
	_spell_button.texture_normal = load(ART + "es_boton-hechizos-off.png")
	_spell_button.texture_pressed = load(ART + "es_boton-hechizos-default.png")
	_spell_button.pressed.connect(show_spells)
	for index in range(42):
		var slot := _text_button(_inventory_panel, "", Rect2(10 + (index % 6) * 36, 16 + (index / 6) * 36, 34, 34))
		slot.tooltip_text = "Casillero %d · Vacío" % (index + 1)
		if index < 2:
			var action := "health_potion" if index == 0 else "mana_potion"
			var potion := RecoveryRules.get_potion(action)
			slot.icon = _grh_icon(int(potion.get("icon_grh", 0)))
			slot.expand_icon = true
			slot.tooltip_text = "%s · Provisión de arena ilimitada · Clic para usar" % potion.get("name", "Poción")
			slot.pressed.connect(_request_recovery.bind(action))
		else:
			slot.toggle_mode = true
			slot.pressed.connect(_select_inventory_slot.bind(slot, index + 1))
		_inventory_slots.append(slot)
	_label(_inventory_panel, "Provisión de arena ilimitada.\nVida +27 · Maná +5% máximo.\nM: meditar · Q: vida · E: maná.", Rect2(12, 280, 216, 74), 12)
	_spell_search = LineEdit.new()
	_spell_search.placeholder_text = "Buscar nombre o ID…"
	_spell_panel.add_child(_spell_search)
	_spell_search.position = Vector2(10, 8)
	_spell_search.size = Vector2(220, 28)
	_spell_search.text_changed.connect(func(_value: String) -> void: _filter_spellbook())
	_spell_search.text_submitted.connect(func(_value: String) -> void: _spell_search.release_focus())
	_show_catalog = CheckButton.new()
	_show_catalog.text = "Ver catálogo completo"
	_show_catalog.focus_mode = Control.FOCUS_NONE
	_show_catalog.add_theme_font_size_override("font_size", 12)
	_spell_panel.add_child(_show_catalog)
	_show_catalog.position = Vector2(8, 39)
	_show_catalog.size = Vector2(224, 28)
	_show_catalog.toggled.connect(func(_value: bool) -> void: _filter_spellbook())
	_spell_scroll = ScrollContainer.new()
	_spell_panel.add_child(_spell_scroll)
	_spell_scroll.position = Vector2(10, 74)
	_spell_scroll.size = Vector2(222, 230)
	_spell_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_spell_scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_NONE
	_spell_list = VBoxContainer.new()
	_spell_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spell_list.add_theme_constant_override("separation", 3)
	_spell_scroll.add_child(_spell_list)
	for id: int in SpellCatalog.all_ids():
		var entry := SpellSlotButton.new()
		entry.configure(id)
		_spell_list.add_child(entry)
		entry.custom_minimum_size = Vector2(200, 47)
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.pressed.connect(_on_spell_selected.bind(id))
		_spell_buttons[id] = entry
	_spell_status = _label(_spell_panel, "Seleccioná un hechizo y pulsá Lanzar.", Rect2(10, 308, 220, 46), 11)
	_spell_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_launch_button = _art_button(_spell_panel, "lanzar", Rect2(0, 360, 161, 39))
	_launch_button.name = "LaunchButton"
	_launch_button.disabled = true
	_launch_button.tooltip_text = "Lanzar el hechizo seleccionado: después elegí un objetivo."
	_launch_button.pressed.connect(_on_launch_pressed)
	_bottom_back = Panel.new()
	_bottom_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bottom_style := StyleBoxFlat.new()
	bottom_style.bg_color = Color("181612")
	bottom_style.border_color = Color("534a36")
	bottom_style.set_border_width_all(1)
	_bottom_back.add_theme_stylebox_override("panel", bottom_style)
	_frame.add_child(_bottom_back)
	_health_bar = _resource_bar("es_barradevida.png", Vector2.ZERO)
	_mana_bar = _resource_bar("es_barrademana.png", Vector2.ZERO)
	_health_label = _label(_frame, "—", Rect2(0, 0, 216, 22), 14)
	_mana_label = _label(_frame, "—", Rect2(0, 0, 216, 22), 14)
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meditate_button = _text_button(_frame, "M · Meditar", Rect2(0, 0, 232, 27))
	_meditate_button.pressed.connect(_on_meditate_pressed)
	_health_potion_button = _text_button(_frame, "Q · Vida +27", Rect2(0, 0, 113, 27))
	_health_potion_button.pressed.connect(_request_recovery.bind("health_potion"))
	_mana_potion_button = _text_button(_frame, "E · Maná +5%", Rect2(0, 0, 113, 27))
	_mana_potion_button.pressed.connect(_request_recovery.bind("mana_potion"))
	_menu_panel = _control(_frame, "MenuPanel", Rect2(0, 0, 250, 250))
	var menu_background := ColorRect.new()
	menu_background.color = Color("171511")
	menu_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_panel.add_child(menu_background)
	menu_background.size = _menu_panel.size
	_label(_menu_panel, "CONTROLES", Rect2(14, 8, 220, 24), 14)
	_label(_menu_panel, "WASD · Movimiento\nCTRL · Ataque físico\n1–0 · Hechizos asignados\nM · Meditar / dejar de meditar\nQ · Poción de vida · E · Maná\nEsc / clic derecho · Cancelar\n\nAO20 · © Noland Studios\nCC BY-NC-ND 4.0\ngithub.com/ao-org/Recursos", Rect2(14, 38, 225, 175), 12)
	_text_button(_menu_panel, "Desconectarse", Rect2(16, 219, 218, 26)).pressed.connect(disconnect_requested.emit)
	_menu_panel.hide()
	_stats_button = _text_button(_frame, "", Rect2(0, 0, 129, 27))
	_stats_button.text = "Reaparecer"
	_stats_button.pressed.connect(_request_recovery.bind("respawn"))
	_menu_button = _text_button(_frame, "", Rect2(0, 0, 126, 27))
	_menu_button.text = "Menú"
	_menu_button.pressed.connect(func() -> void: _menu_panel.visible = not _menu_panel.visible)
	_close_button = _text_button(_frame, "", Rect2(0, 2, 24, 25))
	_close_button.pressed.connect(disconnect_requested.emit)
	for index in range(4):
		var reserved := _text_button(_frame, "", Rect2(0, 2, 65, 25))
		reserved.tooltip_text = "Opción no disponible en esta arena."
		_reserved_buttons.append(reserved)
	for index in range(10):
		var macro := SpellSlotButton.new()
		macro.configure(0, index)
		_frame.add_child(macro)
		macro.size = Vector2(38, 38)
		macro.pressed.connect(_on_hotkey_pressed.bind(index))
		macro.spell_dropped.connect(_on_hotkey_assigned)
		_hotkey_buttons.append(macro)
	_filter_spellbook()


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
		_spell_buttons[id].visible = (_show_catalog.button_pressed or SpellCatalog.is_available(id)) and (query.is_empty() or str(spell.name).to_lower().contains(query) or str(id) == query)
	_spell_scroll.scroll_vertical = 0


func _request_recovery(action: String) -> void:
	if _spell_controller != null:
		_spell_controller.cancel_targeting()
	RecoveryNetwork.request_action(action)


func _on_meditate_pressed() -> void:
	var state: PlayerState = _players.get(_local_peer_id)
	_request_recovery("respawn" if state != null and not state.is_alive else "meditate")


func _on_recovery_event(event: Dictionary) -> void:
	var name := "Tu personaje" if int(event.peer_id) == _local_peer_id else str(event.player_name)
	console.append_message("%s: %s" % [name, event.message], "system" if event.action in ["meditate", "respawn"] else "healing")
	if event.action in ["health_potion", "mana_potion"] and int(event.peer_id) == _local_peer_id:
		var audio := AudioStreamPlayer.new()
		audio.stream = load("res://assets/argentum/source/audio/135.wav")
		audio.volume_db = -12.0
		add_child(audio)
		audio.finished.connect(audio.queue_free)
		audio.play()


func _update_recovery_controls() -> void:
	if _meditate_button == null:
		return
	var state: PlayerState = _players.get(_local_peer_id)
	var ready := _spell_controller != null and _spell_controller.server_ready and state != null
	_meditate_button.disabled = not ready or (state != null and not state.is_alive)
	_stats_button.disabled = not ready or (state != null and state.is_alive)
	_health_potion_button.disabled = not ready or (state != null and not state.is_alive)
	_mana_potion_button.disabled = not ready or (state != null and not state.is_alive)
	if state == null:
		_status_label.text = ""
		_meditate_button.text = "M · Meditar"
	elif not state.is_alive:
		_meditate_button.text = "M · Meditar"
		_status_label.text = "Fantasma · Podés reaparecer"
	else:
		_meditate_button.text = "M · Dejar de meditar" if state.is_meditating else "M · Meditar"
		var labels := state.active_effects.duplicate()
		if state.is_meditating:
			labels.append("Meditando")
		_status_label.text = " · ".join(labels)


func _fit_interface() -> void:
	var available := get_viewport_rect().size
	var factor := minf(available.x / DESIGN_SIZE.x, available.y / DESIGN_SIZE.y)
	_frame.scale = Vector2.ONE * factor
	_frame.position = Vector2.ZERO
	_frame.size = available / maxf(factor, 0.01)
	var side_x := _frame.size.x - 272.0
	var height := _frame.size.y
	_header_art.position = Vector2.ZERO
	_header_art.size = Vector2(side_x, 152)
	_world_art.position = Vector2(0, 152)
	_world_art.size = Vector2(side_x, height - 152)
	_side_art.position = Vector2(side_x, 0)
	_side_art.size = Vector2(272, height)
	game_area.position = Vector2(8, 152)
	game_area.size = Vector2(side_x - 16, height - 214)
	console.position = Vector2(16, 35)
	console.size = Vector2(side_x - 143, 82)
	_minimap.position = Vector2(side_x - 110, 43)
	_controls_hint.size.x = side_x - 40
	_name_label.position = Vector2(side_x + 20, 40)
	_position_label.position = Vector2(side_x + 20, 68)
	_connection_label.position = Vector2(side_x + 20, 96)
	_status_label.position = Vector2(side_x + 20, 124)
	_inventory_button.position = Vector2(side_x + 16, 162)
	_spell_button.position = Vector2(side_x + 138, 162)
	for panel: Control in [_inventory_panel, _spell_panel]:
		panel.position = Vector2(side_x + 16, 192)
		panel.size = Vector2(240, height - 374)
	_spell_scroll.size.y = _spell_panel.size.y - 166
	_spell_status.position.y = _spell_panel.size.y - 85
	_launch_button.position.y = _spell_panel.size.y - 41
	_health_bar.position = Vector2(side_x + 32, height - 152)
	_mana_bar.position = Vector2(side_x + 32, height - 124)
	_health_label.position = _health_bar.position + Vector2(0, -3)
	_mana_label.position = _mana_bar.position + Vector2(0, -3)
	_meditate_button.position = Vector2(side_x + 20, height - 66)
	_health_potion_button.position = Vector2(side_x + 20, height - 34)
	_mana_potion_button.position = Vector2(side_x + 139, height - 34)
	_stats_button.position = Vector2(side_x + 6, height - 187)
	_menu_button.position = Vector2(side_x + 139, height - 187)
	_menu_panel.position = Vector2(side_x + 10, height - 280)
	_bottom_back.position = Vector2(side_x + 8, height - 188)
	_bottom_back.size = Vector2(256, 188)
	_close_button.position.x = _frame.size.x - 26
	for index in range(_reserved_buttons.size()):
		_reserved_buttons[index].position.x = side_x + 8 + index * 68
		_reserved_buttons[index].size.x = 65 if index < 3 else 23
	for index in range(_hotkey_buttons.size()):
		_hotkey_buttons[index].position = Vector2((side_x - 410) * 0.5 + index * 41, height - 49)
	if _world != null:
		_world.resize_viewport(game_area.size)


func _on_snapshot_received(players: Array) -> void:
	_players.clear()
	for data: Dictionary in players:
		var state := PlayerState.from_dictionary(data)
		_players[state.peer_id] = state
	console.append_message("Arena lista · %d jugador(es) conectados." % _players.size())
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
	if previous != null:
		var health_change := state.current_health - previous.current_health
		var mana_change := state.current_mana - previous.current_mana
		var player_name := _player_name(state)
		if health_change < 0:
			console.append_message("%s recibió %d de daño." % [player_name, -health_change], "damage")
		elif health_change > 0:
			console.append_message("%s recuperó %d de vida." % [player_name, health_change], "healing")
		if mana_change < 0:
			console.append_message("%s consumió %d de maná." % [player_name, -mana_change], "mana")
		elif mana_change > 0:
			console.append_message("%s recuperó %d de maná." % [player_name, mana_change], "mana")
		if previous.is_alive and not state.is_alive:
			console.append_message("%s murió." % player_name, "death")
	_players[state.peer_id] = state
	_update_local_stats()


func _player_name(state: PlayerState) -> String:
	return "Tu personaje" if state.peer_id == _local_peer_id else state.display_name


func _update_local_stats() -> void:
	var state: PlayerState = _players.get(_local_peer_id)
	_name_label.text = state.display_name if state != null else "Sin personaje"
	if state != null and state.is_ghost:
		_name_label.text += " · Fantasma"
	_health_bar.max_value = state.max_health if state != null else 100
	_mana_bar.max_value = state.max_mana if state != null else 100
	_health_bar.value = state.current_health if state != null else 0
	_mana_bar.value = state.current_mana if state != null else 0
	_health_label.text = "%d / %d" % [state.current_health, state.max_health] if state != null else "—"
	_mana_label.text = "%d / %d" % [state.current_mana, state.max_mana] if state != null else "—"
	_position_label.text = "Bosque · %d, %d" % [state.grid_position.x, state.grid_position.y] if state != null else "Bosque"
	_minimap.players = _players
	_minimap.local_peer_id = _local_peer_id
	_minimap.queue_redraw()
	_update_recovery_controls()


func _select_inventory_slot(slot: Button, number: int) -> void:
	if _selected_inventory_slot != null and _selected_inventory_slot != slot:
		_selected_inventory_slot.button_pressed = false
	_selected_inventory_slot = slot
	console.append_message("Casillero %d vacío." % number)


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
	label.add_theme_color_override("font_color", Color("e2d8bc"))
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
	button.add_theme_font_size_override("font_size", 12)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.07, 0.065, 0.045, 0.3) if text_value != "" else Color.TRANSPARENT
	normal.border_color = Color(0.35, 0.31, 0.23, 0.6)
	if text_value != "":
		normal.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.7, 0.6, 0.3, 0.15)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.7, 0.6, 0.3, 0.3)
	pressed.border_color = Color("b59b61")
	pressed.set_border_width_all(1)
	button.add_theme_stylebox_override("pressed", pressed)
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


func _resource_bar(filename: String, at: Vector2) -> TextureProgressBar:
	var bar := TextureProgressBar.new()
	bar.texture_progress = load(ART + filename)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(bar)
	bar.position = at
	bar.size = Vector2(216, 16)
	return bar
