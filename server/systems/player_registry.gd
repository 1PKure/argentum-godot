class_name PlayerRegistry
extends Node

var _players: Dictionary[int, PlayerState] = {}

var _last_move_time: Dictionary[int, int] = {}
var _last_attack_time: Dictionary[int, int] = {}
var _last_spell_time: Dictionary[int, int] = {}
var _last_spell_request: Dictionary[int, int] = {}

var _arena_id: String = (
	ArenaData.DEFAULT_ARENA_ID
)


func set_arena(
	arena_id: String
) -> bool:
	if not ArenaData.is_implemented(
		arena_id
	):
		push_warning(
			"Attempted to use unavailable arena: %s"
			% arena_id
		)

		return false

	_arena_id = arena_id

	print(
		"Active arena: %s"
		% ArenaData.get_display_name(
			_arena_id
		)
	)

	return true


func get_arena_id() -> String:
	return _arena_id


func add_player(
	peer_id: int
) -> PlayerState:
	if _players.has(peer_id):
		return _players[peer_id]

	var spawn_position := (
		_get_spawn_position()
	)

	var player := PlayerState.new(
		peer_id,
		"Player %d" % peer_id,
		spawn_position
	)

	_players[peer_id] = player

	_last_move_time[peer_id] = 0
	_last_attack_time[peer_id] = -SpellCatalog.ATTACK_SPELL_GAP_MSEC
	_last_spell_time[peer_id] = -SpellCatalog.CAST_INTERVAL_MSEC
	_last_spell_request[peer_id] = 0

	print(
		"Player registered: %s at tile %s"
		% [
			player.display_name,
			player.grid_position
		]
	)

	return player


func remove_player(
	peer_id: int
) -> void:
	if not _players.has(peer_id):
		return

	var player: PlayerState = (
		_players[peer_id]
	)

	print(
		"Player removed: %s"
		% player.display_name
	)

	_players.erase(peer_id)
	_last_move_time.erase(peer_id)
	_last_attack_time.erase(peer_id)
	_last_spell_time.erase(peer_id)
	_last_spell_request.erase(peer_id)


func try_move_player(
	peer_id: int,
	direction: int
) -> PlayerState:
	if not _players.has(peer_id):
		return null

	if not MovementRules.is_valid_direction(
		direction
	):
		return null
	
	var player: PlayerState = (
		_players[peer_id]
	)

	if (
		not player.is_alive
		and not player.is_ghost
	):
		return null

	var current_time: int = (
		Time.get_ticks_msec()
	)

	var last_move_time: int = (
		_last_move_time.get(
			peer_id,
			0
		)
	)

	if not MovementRules.is_move_ready(current_time, last_move_time):
		return null

	var offset: Vector2i = (
		MovementRules.get_offset(
			direction
		)
	)

	var new_position: Vector2i = (
		player.grid_position
		+ offset
	)

	if not ArenaData.is_walkable(
		_arena_id,
		new_position
	):
		return null

	if (
		player.is_alive
		and _is_position_blocked(
			new_position,
			peer_id
		)
	):
		print(
		"Movement blocked -> Player: %d | Position: %s"
		% [
			peer_id,
			new_position
		]
	)
		return null

	player.grid_position = new_position
	player.facing_direction = direction

	_last_move_time[peer_id] = MovementRules.get_accepted_move_time(current_time, last_move_time)

	return player


func try_basic_attack(
	attacker_peer_id: int
) -> PlayerState:
	if not _players.has(
		attacker_peer_id
	):
		return null

	var attacker: PlayerState = (
		_players[
			attacker_peer_id
		]
	)

	if not attacker.is_alive:
		return null

	if attacker.is_ghost:
		return null

	var current_time: int = (
		Time.get_ticks_msec()
	)

	var last_attack_time: int = (
		_last_attack_time.get(
			attacker_peer_id,
			0
		)
	)

	if (
		current_time - last_attack_time
		< CombatRules.BASIC_ATTACK_COOLDOWN_MSEC
	):
		return null
	if current_time - _last_spell_time.get(attacker_peer_id, -SpellCatalog.SPELL_ATTACK_GAP_MSEC) < SpellCatalog.SPELL_ATTACK_GAP_MSEC:
		return null

	_last_attack_time[
		attacker_peer_id
	] = current_time

	var attack_offset: Vector2i = (
		MovementRules.get_offset(
			attacker.facing_direction
		)
	)

	var attack_position: Vector2i = (
		attacker.grid_position
		+ attack_offset
	)

	var target: PlayerState = (
		_find_player_at_position(
			attack_position,
			attacker_peer_id
		)
	)

	if target == null:
		return null

	if not target.apply_damage(
		CombatRules.BASIC_ATTACK_DAMAGE
	):
		return null

	print(
		"%s attacked %s for %d damage. HP: %d/%d"
		% [
			attacker.display_name,
			target.display_name,
			CombatRules.BASIC_ATTACK_DAMAGE,
			target.current_health,
			target.max_health
		]
	)

	if target.is_ghost:
		print(
			"%s died and became a ghost."
			% target.display_name
		)

	return target


func try_cast_spell(caster_id: int, spell_id: int, target_position: Vector2i, request_id: int) -> Dictionary:
	var caster: PlayerState = _players.get(caster_id)
	if caster == null:
		return _spell_error("No hay un personaje conectado para lanzar.")
	if request_id <= _last_spell_request.get(caster_id, 0):
		return _spell_error("El lanzamiento ya fue procesado.")
	_last_spell_request[caster_id] = request_id
	if not caster.is_alive:
		return _spell_error("No podés lanzar hechizos mientras sos un fantasma.")
	if not SpellCatalog.is_available(spell_id):
		return _spell_error("No tenés ese hechizo disponible.")
	if not MovementRules.is_inside_bounds(target_position):
		return _spell_error("El objetivo está fuera de la arena.")
	var target: PlayerState = _find_player_at_position(target_position, -1)
	if target == null or not target.is_alive:
		return _spell_error("No hay un objetivo vivo en esa casilla.")
	var spell := SpellCatalog.get_spell(spell_id)
	if spell.effect == "damage" and caster_id == target.peer_id:
		return _spell_error("Elegí a un rival para un hechizo ofensivo.")
	if caster.current_mana < int(spell.mana):
		return _spell_error("No tenés suficiente maná para %s." % spell.name)
	var now := Time.get_ticks_msec()
	var remaining: int = SpellCatalog.CAST_INTERVAL_MSEC - (now - _last_spell_time.get(caster_id, -SpellCatalog.CAST_INTERVAL_MSEC))
	if remaining > 0:
		return _spell_error("Todavía no podés volver a lanzar.", remaining)
	remaining = SpellCatalog.ATTACK_SPELL_GAP_MSEC - (now - _last_attack_time.get(caster_id, -SpellCatalog.ATTACK_SPELL_GAP_MSEC))
	if remaining > 0:
		return _spell_error("Esperá el intervalo entre golpe y magia.", remaining)
	# No await occurs between validation and mutation: cost and effect are atomic.
	var rolled := randi_range(int(spell.min_amount), int(spell.max_amount))
	var previous_health := target.current_health
	if spell.effect == "healing":
		target.restore_health(rolled)
	else:
		target.apply_damage(rolled)
	caster.spend_mana(int(spell.mana))
	_last_spell_time[caster_id] = now
	return {
		"ok": true,
		"caster_state": caster.to_dictionary(),
		"target_state": target.to_dictionary(),
		"event": {
			"request_id": request_id,
			"caster_id": caster_id,
			"target_id": target.peer_id,
			"caster_name": caster.display_name,
			"target_name": target.display_name,
			"spell_id": spell_id,
			"spell_name": spell.name,
			"words": spell.words,
			"effect": spell.effect,
			"amount": absi(target.current_health - previous_health),
			"mana_cost": int(spell.mana),
			"origin_x": caster.grid_position.x,
			"origin_y": caster.grid_position.y,
			"target_x": target.grid_position.x,
			"target_y": target.grid_position.y,
		}
	}


func _spell_error(message: String, remaining_msec: int = 0) -> Dictionary:
	return {"ok": false, "message": message, "remaining_msec": remaining_msec}


func apply_damage(
	peer_id: int,
	amount: int
) -> PlayerState:
	if not _players.has(peer_id):
		return null

	var player: PlayerState = (
		_players[peer_id]
	)

	if not player.apply_damage(
		amount
	):
		return null

	return player


func spend_mana(
	peer_id: int,
	amount: int
) -> PlayerState:
	if not _players.has(peer_id):
		return null

	var player: PlayerState = (
		_players[peer_id]
	)

	if not player.spend_mana(
		amount
	):
		return null

	return player


func has_player(
	peer_id: int
) -> bool:
	return _players.has(
		peer_id
	)


func get_player(
	peer_id: int
) -> PlayerState:
	return _players.get(
		peer_id
	)


func get_peer_ids() -> Array:
	return _players.keys()


func get_snapshot() -> Array:
	var snapshot: Array = []

	for player in _players.values():
		snapshot.append(
			player.to_dictionary()
		)

	return snapshot


func _get_spawn_position() -> Vector2i:
	var spawn_points: Array[Vector2i] = (
		ArenaData.get_spawn_points(
			_arena_id
		)
	)

	for spawn_position: Vector2i in spawn_points:
		if not ArenaData.is_walkable(
			_arena_id,
			spawn_position
		):
			continue

		if _is_position_blocked(
			spawn_position,
			0
		):
			continue

		return spawn_position

	if not spawn_points.is_empty():
		return spawn_points[0]

	return Vector2i(
		4,
		5
	)


func _is_position_blocked(
	grid_position: Vector2i,
	excluded_peer_id: int
) -> bool:
	for other_player: PlayerState in (
		_players.values()
	):
		if (
			other_player.peer_id
			== excluded_peer_id
		):
			continue

		if not other_player.is_alive:
			continue

		if other_player.is_ghost:
			continue

		if (
			other_player.grid_position
			== grid_position
		):
			return true

	return false


func _find_player_at_position(
	grid_position: Vector2i,
	excluded_peer_id: int
) -> PlayerState:
	for player: PlayerState in (
		_players.values()
	):
		if (
			player.peer_id
			== excluded_peer_id
		):
			continue

		if not player.is_alive:
			continue

		if player.is_ghost:
			continue

		if (
			player.grid_position
			== grid_position
		):
			return player

	return null
