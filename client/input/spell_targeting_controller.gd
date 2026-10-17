class_name SpellTargetingController
extends Node

signal changed
signal feedback(message: String, channel: String)

const BINDINGS_FILE := "user://spell_hotkeys.cfg"
var selected_spell_id := 25
var aimed_spell_id := 0
var aimed_attack := false
var _preset_revision := -1
var bindings: Array[int] = []
var session_active := false
var server_ready := false
var pending_request := 0
var _next_request := 0
var _generation := 0
var _local_id := 0
var _world: ClientWorld
var _game_area: Control
var _alive := true
var class_id := ClassCatalog.DEFAULT_CLASS


func _ready() -> void:
	bindings.assign(ClassCatalog.get_profile(class_id).bindings)
	_load_bindings()
	SpellNetwork.server_capabilities_received.connect(_on_capabilities)
	SpellNetwork.spell_resolved.connect(_on_spell_resolved)
	SpellNetwork.spell_rejected.connect(_on_spell_rejected)
	PlayerNetwork.player_stats_updated.connect(_on_stats_updated)


func setup(world: ClientWorld, game_area: Control) -> void:
	_world = world
	_game_area = game_area


func start_session(peer_id: int) -> void:
	end_session()
	_local_id = peer_id
	session_active = true
	_alive = true
	_next_request = 0
	SpellNetwork.query_server()
	changed.emit()


func end_session() -> void:
	_generation += 1
	session_active = false
	server_ready = false
	pending_request = 0
	cancel_targeting()
	SpellNetwork.clear_session()
	RecoveryNetwork.clear_session()
	BotNetwork.clear_session()


func select_spell(id: int) -> void:
	if SpellCatalog.get_spell(id).is_empty():
		return
	selected_spell_id = id
	cancel_targeting()
	changed.emit()


func aim_selected() -> void:
	aim_spell(selected_spell_id)


func can_launch() -> bool:
	return session_active and server_ready and _alive and pending_request == 0 and ClassCatalog.can_cast(class_id, selected_spell_id)


func aim_hotkey(slot: int) -> void:
	if slot < 0 or slot >= bindings.size():
		return
	if bindings[slot] == ClassCatalog.ATTACK_BINDING:
		aim_basic_attack()
		return
	if bindings[slot] == 0:
		feedback.emit("Este acceso no tiene un hechizo asignado.", "system")
		return
	aim_spell(bindings[slot])


func aim_spell(id: int) -> void:
	if not session_active or not server_ready or not _alive:
		feedback.emit("No podés lanzar en este momento.", "system")
		return
	if not ClassCatalog.can_cast(class_id, id):
		feedback.emit("Tu clase no tiene este hechizo en su preset.", "system")
		return
	if pending_request != 0:
		return
	selected_spell_id = id
	aimed_attack = false
	aimed_spell_id = id
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	changed.emit()


func cancel_targeting() -> void:
	aimed_spell_id = 0
	aimed_attack = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	changed.emit()


func assign_hotkey(slot: int, id: int) -> void:
	if slot < 0 or slot >= bindings.size() or not ClassCatalog.can_cast(class_id, id):
		return
	bindings[slot] = id
	var config := ConfigFile.new()
	config.load(BINDINGS_FILE)
	config.set_value("meta", "version", ClassCatalog.MACRO_VERSION)
	config.set_value("class:%d" % class_id, "version", ClassCatalog.MACRO_VERSION)
	for index in range(bindings.size()):
		config.set_value("class:%d" % class_id, str(index), bindings[index])
	config.save(BINDINGS_FILE)
	feedback.emit("Acceso %d: %s." % [(slot + 1) % 10, SpellCatalog.get_spell(id).name], "system")
	changed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not session_active or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_CTRL:
		aim_basic_attack()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_ESCAPE and (aimed_spell_id != 0 or aimed_attack):
		cancel_targeting()
		get_viewport().set_input_as_handled()
	elif not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
		var recovery_action := {KEY_M: "meditate", KEY_Q: "health_potion", KEY_E: "mana_potion"}
		if recovery_action.has(event.keycode):
			cancel_targeting()
			RecoveryNetwork.request_action(recovery_action[event.keycode])
			get_viewport().set_input_as_handled()
			return
		var index := -1
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			index = event.keycode - KEY_1
		elif event.keycode == KEY_0:
			index = 9
		if index >= 0:
			aim_hotkey(index)
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if (aimed_spell_id == 0 and not aimed_attack) or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		cancel_targeting()
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_LEFT and _game_area.get_global_rect().has_point(event.position):
		get_viewport().set_input_as_handled()
		var target := _world.target_grid_at(event.position)
		var id := aimed_spell_id
		var shot := aimed_attack
		cancel_targeting()
		if not MovementRules.is_inside_bounds(target):
			feedback.emit("Elegí un objetivo dentro de la arena.", "system")
			return
		_next_request += 1
		pending_request = _next_request
		var sent := SpellNetwork.request_shot(target, pending_request) if shot else SpellNetwork.request_cast(id, target, pending_request)
		if not sent:
			pending_request = 0
			feedback.emit("No se pudo enviar el lanzamiento. Revisá la conexión.", "system")
		changed.emit()
		var generation := _generation
		var request := pending_request
		await get_tree().create_timer(3.0).timeout
		if generation == _generation and pending_request != 0 and pending_request == request:
			pending_request = 0
			feedback.emit("El servidor no respondió al lanzamiento. Revisá la conexión.", "system")
			changed.emit()


func _on_capabilities(available: bool) -> void:
	if not session_active:
		return
	server_ready = available
	if not available:
		feedback.emit("El servidor no incluye esta versión de hechizos. Actualizalo a la misma rama y revisión que el cliente y reinicialo con el .cmd.", "system")
	changed.emit()


func _on_spell_resolved(event: Dictionary) -> void:
	if int(event.caster_id) == _local_id and int(event.request_id) == pending_request:
		pending_request = 0
		changed.emit()


func _on_spell_rejected(request_id: int, message: String, _remaining: int) -> void:
	if request_id != pending_request:
		return
	pending_request = 0
	feedback.emit(message, "system")
	changed.emit()


func _on_stats_updated(data: Dictionary) -> void:
	if int(data.get("peer_id", 0)) == _local_id:
		apply_state(data)


func apply_state(data: Dictionary) -> void:
	apply_class(int(data.get("class_id", ClassCatalog.DEFAULT_CLASS)), int(data.get("preset_revision", 0)))
	_alive = bool(data.get("is_alive", true))
	if not _alive:
		cancel_targeting()
	else:
		changed.emit()


func aim_basic_attack() -> void:
	if not session_active or not server_ready or not _alive or pending_request != 0:
		return
	cancel_targeting()
	if class_id == 8:
		aimed_attack = true
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
		changed.emit()
	else:
		PlayerNetwork.request_basic_attack()


func apply_class(id: int, preset_revision: int = -1) -> void:
	if class_id == id and (preset_revision < 0 or _preset_revision == preset_revision):
		return
	class_id = id
	_preset_revision = preset_revision
	_generation += 1
	pending_request = 0
	bindings.assign(ClassCatalog.get_profile(class_id).bindings)
	_load_bindings()
	selected_spell_id = bindings[0] if bindings[0] > 0 else 0
	cancel_targeting()
	changed.emit()


func _load_bindings() -> void:
	var config := ConfigFile.new()
	if config.load(BINDINGS_FILE) != OK or int(config.get_value("class:%d" % class_id, "version", 0)) != ClassCatalog.MACRO_VERSION:
		return
	for index in range(bindings.size()):
		var id := int(config.get_value("class:%d" % class_id, str(index), bindings[index]))
		if id in [0, ClassCatalog.ATTACK_BINDING] or ClassCatalog.can_cast(class_id, id):
			bindings[index] = id
