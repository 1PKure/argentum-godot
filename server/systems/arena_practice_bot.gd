class_name ArenaPracticeBot
extends RefCounted

signal reset_world
signal removed(peer_id: int)
signal status_changed(status: Dictionary)

const BOT_ID := -1000 # Entity ID only; never a network recipient or the -1 lookup sentinel.
const THINK_MSEC := 150
const COMMAND_INTERVAL_MSEC := 400
var registry: PlayerRegistry
var owner_id := 0
var phase := "idle"
var _next_think := 0
var _next_strafe := 0
var _next_control := 0
var _turn := 1
var _cast_request := 0
var _recovery_request := 0
var _shot_request := 0
var _last_request: Dictionary = {}
var _last_command: Dictionary = {}

func _init(players: PlayerRegistry) -> void:
	registry = players

func human_ids() -> Array[int]:
	var ids: Array[int] = []
	for id: int in registry.get_peer_ids():
		if not registry.get_player(id).is_bot:
			ids.append(id)
	return ids

func status() -> Dictionary:
	var bot := registry.get_player(BOT_ID)
	return {"enabled": bot != null, "owner_id": owner_id, "bot_id": BOT_ID if bot != null else 0,
		"class_id": bot.class_id if bot != null else 3, "phase": phase, "human_count": human_ids().size()}

func request(peer_id: int, enabled: bool, class_id: int, request_id: int, now: int = -1) -> Dictionary:
	if now < 0:
		now = Time.get_ticks_msec()
	if not human_ids().has(peer_id):
		return _error("No hay un jugador conectado para esta práctica.")
	if request_id <= int(_last_request.get(peer_id, 0)):
		return _error("La solicitud del bot ya fue procesada.")
	_last_request[peer_id] = request_id
	if owner_id != 0 and owner_id != peer_id:
		return _error("Este bot pertenece a otra práctica.")
	if not enabled:
		remove_bot()
		return {"ok": true}
	if human_ids().size() != 1:
		return _error("Hay otro jugador conectado. El bot está disponible para practicar a solas.")
	if ClassCatalog.get_profile(class_id).is_empty():
		return _error("Clase de bot desconocida.")
	if now - int(_last_command.get(peer_id, -COMMAND_INTERVAL_MSEC)) < COMMAND_INTERVAL_MSEC:
		return _error("Esperá un instante antes de reiniciar la práctica.")
	var spawns := ArenaData.get_spawn_points(registry.get_arena_id())
	if spawns.size() < 2:
		return _error("La arena necesita dos puntos de aparición.")
	_last_command[peer_id] = now
	remove_bot(false)
	var owner := registry.get_player(peer_id)
	registry.try_select_class(peer_id, owner.class_id, now)
	owner.grid_position = spawns[0]
	owner.facing_direction = MovementRules.Direction.EAST
	var bot := registry.add_player(BOT_ID)
	bot.is_bot = true
	registry.try_select_class(BOT_ID, class_id, now)
	bot.display_name = "Bot · %s" % ClassCatalog.get_profile(class_id).name
	bot.grid_position = spawns[1]
	bot.facing_direction = MovementRules.Direction.WEST
	owner_id = peer_id
	phase = "active"
	_cast_request = 0
	_recovery_request = 0
	_shot_request = 0
	_next_think = now + 600
	_next_strafe = now + 900
	_next_control = now + 1600
	reset_world.emit()
	status_changed.emit(status())
	return {"ok": true}

func remove_bot(notify: bool = true) -> void:
	if registry.has_player(BOT_ID):
		registry.remove_player(BOT_ID)
		removed.emit(BOT_ID)
	owner_id = 0
	phase = "idle"
	if notify:
		status_changed.emit(status())

func peer_joining() -> void:
	# Called before registering a second human, so their snapshot never includes a bot.
	remove_bot(false)

func peer_left(peer_id: int) -> void:
	if peer_id == owner_id:
		remove_bot(false)
	_last_request.erase(peer_id)
	_last_command.erase(peer_id)

func tick(now: int = -1) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if phase != "active":
		return actions
	if now < 0:
		now = Time.get_ticks_msec()
	var bot := registry.get_player(BOT_ID)
	var target := registry.get_player(owner_id)
	if bot == null or target == null or human_ids().size() != 1:
		remove_bot()
		return actions
	if not bot.is_alive or not target.is_alive:
		phase = "won" if not bot.is_alive else "lost"
		status_changed.emit(status())
		return actions
	if now < _next_think:
		return actions
	_next_think = now + THINK_MSEC
	# Read only public target position/HP/effects. Enemy mana is not used by the AI.
	if bot.active_effects.has("Paralizado") or bot.active_effects.has("Inmovilizado"):
		_cast(27, bot.grid_position, now, actions)
	var potion := "health_potion" if bot.current_health < bot.max_health * 0.7 else "mana_potion" if bot.max_mana > 0 and bot.current_mana < bot.max_mana * 0.65 else ""
	if potion != "":
		_recover(potion, now, actions)
	var delta := target.grid_position - bot.grid_position
	var distance := maxi(absi(delta.x), absi(delta.y))
	var caster := bot.class_id in [1, 2, 5, 6]
	var ranged := caster or bot.class_id == 8
	if bot.is_meditating:
		if bot.current_mana >= bot.max_mana * 0.45 or distance <= 2:
			_recover("meditate", now, actions)
		else:
			return actions
	if bot.current_health < bot.max_health * 0.45:
		_cast(31, bot.grid_position, now, actions)
	if caster and bot.current_mana < 100 and distance >= 3:
		_recover("meditate", now, actions)
		return actions
	if now >= _next_control and not target.active_effects.has("Paralizado") and distance <= 7 and bot.current_mana > 700:
		if _cast(25, target.grid_position, now, actions):
			_next_control = now + 8000
	if caster and distance <= 8:
		var profile := ClassCatalog.get_profile(bot.class_id)
		var spell := int(profile.bindings[2])
		if target.current_health < 240 and ClassCatalog.can_cast(bot.class_id, 53) and bot.current_mana >= 1000:
			spell = 53
		if not _cast(spell, target.grid_position, now, actions):
			_cast(3, target.grid_position, now, actions)
	elif bot.class_id == 8:
		_shot_request += 1
		var result := registry.try_ranged_attack(BOT_ID, target.grid_position, _shot_request, now)
		if result.ok:
			actions.append({"kind": "cast", "result": result})
	elif absi(delta.x) + absi(delta.y) == 1:
		bot.facing_direction = _direction(delta)
		var target_state := registry.try_basic_attack(BOT_ID, now)
		if target_state != null:
			actions.append({"kind": "melee", "attacker": bot.to_dictionary(), "target": target_state.to_dictionary()})
	if not target.is_alive:
		phase = "lost"
		status_changed.emit(status())
		return actions
	var direction := _path_step(bot, target, ranged)
	if direction == -1 and ranged and now >= _next_strafe:
		_next_strafe = now + 600
		_turn = -_turn
		var sideways := Vector2i(0, _turn) if absi(delta.x) >= absi(delta.y) else Vector2i(_turn, 0)
		var cell := bot.grid_position + sideways
		if _free(cell) and _firing_position(cell, target.grid_position):
			direction = _direction(sideways)
	if direction != -1:
		var moved := registry.try_move_player(BOT_ID, direction, now)
		if moved != null:
			actions.append({"kind": "move", "state": moved.to_dictionary()})
	return actions

func _cast(spell_id: int, target: Vector2i, now: int, actions: Array[Dictionary]) -> bool:
	var bot := registry.get_player(BOT_ID)
	if spell_id <= 0 or not ClassCatalog.can_cast(bot.class_id, spell_id) or bot.current_mana < int(SpellCatalog.get_spell(spell_id).mana):
		return false
	_cast_request += 1
	var result := registry.try_cast_spell(BOT_ID, spell_id, target, _cast_request, now)
	if result.ok:
		actions.append({"kind": "cast", "result": result})
	return bool(result.ok)

func _recover(action: String, now: int, actions: Array[Dictionary]) -> void:
	_recovery_request += 1
	var result := registry.try_recovery_action(BOT_ID, action, _recovery_request, now)
	if result.ok:
		actions.append({"kind": "recovery", "result": result})

func _free(cell: Vector2i) -> bool:
	if not ArenaData.is_walkable(registry.get_arena_id(), cell):
		return false
	for id: int in registry.get_peer_ids():
		var player := registry.get_player(id)
		if id != BOT_ID and player.is_alive and player.grid_position == cell:
			return false
	return true

func _firing_position(cell: Vector2i, target: Vector2i) -> bool:
	var delta := target - cell
	var distance := maxi(absi(delta.x), absi(delta.y))
	return distance >= 4 and distance <= 6 and CombatRules.has_clear_shot(registry.get_arena_id(), cell, target)

func _path_step(bot: PlayerState, target: PlayerState, ranged: bool) -> int:
	var queue: Array[Vector2i] = [bot.grid_position]
	var first: Dictionary = {bot.grid_position: -1}
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		var delta := target.grid_position - cell
		if (_firing_position(cell, target.grid_position) if ranged else absi(delta.x) + absi(delta.y) == 1):
			return int(first[cell])
		for direction in range(4):
			var next := cell + MovementRules.get_offset(direction)
			if not first.has(next) and _free(next):
				first[next] = direction if cell == bot.grid_position else first[cell]
				queue.append(next)
	return -1

func _direction(delta: Vector2i) -> int:
	if absi(delta.x) > absi(delta.y):
		return MovementRules.Direction.EAST if delta.x > 0 else MovementRules.Direction.WEST
	return MovementRules.Direction.SOUTH if delta.y > 0 else MovementRules.Direction.NORTH

func _error(message: String) -> Dictionary:
	return {"ok": false, "message": message}
