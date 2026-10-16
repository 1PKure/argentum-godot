class_name CombatHUD
extends Control

signal disconnect_requested

const ART := "res://assets/argentum/interface/ao20/"
const DESIGN_SIZE := Vector2(1024, 768)
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
	show_inventory()
	_update_local_stats()
	console.append_message("Bienvenido a la arena PvP.")


func mount_world(world: Node2D) -> void:
	_world = world
	_world.reparent(game_area)
	var arena_size := Vector2(MovementRules.GRID_COLUMNS, MovementRules.GRID_ROWS) * ClientWorld.TILE_SIZE
	var world_scale := minf((WORLD_RECT.size.x - 16.0) / arena_size.x, (WORLD_RECT.size.y - 100.0) / arena_size.y)
	_world.scale = Vector2.ONE * world_scale
	_world.position = WORLD_RECT.size * 0.5 - (ClientWorld.WORLD_ORIGIN + arena_size * 0.5) * world_scale


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
	var frame_art := _picture(_frame, "es_ventanaprincipal.png", Rect2(Vector2.ZERO, DESIGN_SIZE))
	# The existing arena ground uses z=-10; keep the frame behind it.
	frame_art.z_index = -20
	game_area = _control(_frame, "GameArea", WORLD_RECT)
	game_area.clip_contents = true
	console = CombatConsole.new()
	console.name = "CombatConsole"
	_frame.add_child(console)
	console.position = Vector2(16, 35)
	console.size = Vector2(609, 82)
	var filter_group := ButtonGroup.new()
	for index in range(3):
		var filter_button := _text_button(_frame, ["Todo", "Combate", "Sistema"][index], Rect2(150 + index * 75, 4, 73, 23))
		filter_button.toggle_mode = true
		filter_button.button_group = filter_group
		filter_button.button_pressed = index == 0
		filter_button.pressed.connect(console.set_channel_filter.bind(["all", "combat", "system"][index]))
	_label(_frame, "Arena PvP · Prueba privada", Rect2(385, 5, 245, 22), 12)
	_label(_frame, "Movimiento: WASD · Golpear: CTRL", Rect2(43, 123, 575, 22), 12)
	_minimap = ArenaMinimap.new()
	_frame.add_child(_minimap)
	_minimap.position = Vector2(642, 43)
	_minimap.size = Vector2(91, 91)
	_name_label = _label(_frame, "Sin personaje", Rect2(772, 40, 237, 25), 15)
	_position_label = _label(_frame, "Bosque", Rect2(772, 70, 205, 22), 12)
	_connection_label = _label(_frame, "Sin conexión", Rect2(773, 99, 235, 22), 12)
	_inventory_panel = _control(_frame, "InventoryPanel", Rect2(768, 160, 247, 325))
	_picture(_inventory_panel, "es_centroinventario.png", Rect2(0, 0, 247, 325))
	_spell_panel = _control(_frame, "SpellPanel", Rect2(768, 160, 247, 325))
	_picture(_spell_panel, "es_centrohechizo.png", Rect2(0, 0, 247, 325))
	_inventory_button = _art_button(_frame, "inventory", Rect2(769, 161, 122, 28))
	_inventory_button.toggle_mode = true
	_inventory_button.texture_normal = load(ART + "es_boton-inventory-off.png")
	_inventory_button.texture_pressed = load(ART + "es_boton-inventory-default.png")
	_inventory_button.pressed.connect(show_inventory)
	_spell_button = _art_button(_frame, "hechizos", Rect2(893, 161, 122, 28))
	_spell_button.toggle_mode = true
	_spell_button.texture_normal = load(ART + "es_boton-hechizos-off.png")
	_spell_button.texture_pressed = load(ART + "es_boton-hechizos-default.png")
	_spell_button.pressed.connect(show_spells)
	for index in range(42):
		var slot := _text_button(_inventory_panel, "", Rect2(19 + (index % 6) * 35, 45 + (index / 6) * 35, 33, 33))
		slot.tooltip_text = "Casillero %d · Vacío" % (index + 1)
		slot.toggle_mode = true
		slot.pressed.connect(_select_inventory_slot.bind(slot, index + 1))
	var empty_spells := _label(_spell_panel, "Sin hechizos disponibles.", Rect2(16, 55, 216, 50), 13)
	empty_spells.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var launch := _art_button(_spell_panel, "lanzar", Rect2(0, 284, 161, 39))
	launch.name = "LaunchButton"
	launch.disabled = true
	launch.modulate = Color(0.55, 0.55, 0.55)
	launch.tooltip_text = "No hay un hechizo disponible para lanzar."
	_health_bar = _resource_bar("es_barradevida.png", Vector2(791, 602))
	_mana_bar = _resource_bar("es_barrademana.png", Vector2(791, 630))
	_health_label = _label(_frame, "—", Rect2(791, 599, 216, 22), 13)
	_mana_label = _label(_frame, "—", Rect2(791, 627, 216, 22), 13)
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# AO20's unused attributes remain explicitly unset in this arena prototype.
	for rect: Rect2 in [Rect2(790, 655, 90, 20), Rect2(910, 655, 34, 20), Rect2(974, 655, 34, 20), Rect2(785, 696, 60, 24), Rect2(870, 696, 60, 24), Rect2(950, 696, 60, 24), Rect2(785, 727, 60, 24), Rect2(870, 727, 60, 24), Rect2(950, 727, 60, 24)]:
		var unavailable := _label(_frame, "—", rect, 12)
		unavailable.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_panel = _control(_frame, "MenuPanel", Rect2(768, 552, 243, 205))
	var menu_background := ColorRect.new()
	menu_background.color = Color("171511")
	menu_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_panel.add_child(menu_background)
	menu_background.size = _menu_panel.size
	_label(_menu_panel, "CONTROLES", Rect2(14, 8, 215, 24), 14)
	_label(_menu_panel, "WASD · Movimiento\nCTRL · Ataque físico\n\nArgentum Online / AO20\n© Noland Studios\nCC BY-NC-ND 4.0\ngithub.com/ao-org/Recursos", Rect2(14, 38, 218, 134), 12)
	_text_button(_menu_panel, "Desconectarse", Rect2(16, 172, 209, 26)).pressed.connect(disconnect_requested.emit)
	_menu_panel.hide()
	_text_button(_frame, "", Rect2(758, 523, 129, 27)).pressed.connect(_menu_panel.hide)
	_text_button(_frame, "", Rect2(891, 523, 126, 27)).pressed.connect(_menu_panel.show)
	_text_button(_frame, "", Rect2(998, 2, 24, 25)).pressed.connect(disconnect_requested.emit)
	# Preserve the frame's other chrome without implying unsupported actions.
	for rect: Rect2 in [Rect2(760, 2, 69, 25), Rect2(830, 2, 68, 25), Rect2(900, 2, 68, 25), Rect2(972, 2, 23, 25)]:
		var reserved := _text_button(_frame, "", rect)
		reserved.tooltip_text = "Opción no disponible en esta arena."
	for index in range(10):
		var macro := _text_button(_frame, str((index + 1) % 10), Rect2(185 + index * 37, 716, 34, 34))
		macro.tooltip_text = "Acceso %d · Sin asignar" % ((index + 1) % 10)
		macro.pressed.connect(console.append_message.bind("Este acceso no tiene un hechizo asignado."))


func _fit_interface() -> void:
	var available := get_viewport_rect().size
	var factor := minf(available.x / DESIGN_SIZE.x, available.y / DESIGN_SIZE.y)
	_frame.scale = Vector2.ONE * factor
	_frame.position = (available - DESIGN_SIZE * factor) * 0.5


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
