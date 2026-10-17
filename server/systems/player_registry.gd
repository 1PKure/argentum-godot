class_name PlayerRegistry
extends Node

signal basic_attack_resolved(event: Dictionary)

var _players: Dictionary[int, PlayerState] = {}

var _last_move_time: Dictionary[int, int] = {}
var _last_attack_time: Dictionary[int, int] = {}
var _last_spell_time: Dictionary[int, int] = {}
var _last_spell_request: Dictionary[int, int] = {}
var _last_recovery_request: Dictionary[int, int] = {}
var _last_potion_time: Dictionary[int, int] = {}
var _next_meditation_tick: Dictionary[int, int] = {}
var _spell_cooldowns: Dictionary = {}
var _last_inventory_request: Dictionary[int, int] = {}
var _last_shot_request: Dictionary[int, int] = {}
var _status_system := ArenaStatusSystem.new()

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

	var profile := ClassCatalog.get_profile(player.class_id)
	player.max_health = int(profile.max_health)
	player.current_health = player.max_health
	player.max_mana = int(profile.max_mana)
	player.current_mana = player.max_mana
	_players[peer_id] = player

	_last_move_time[peer_id] = 0
	_last_attack_time[peer_id] = -SpellCatalog.ATTACK_SPELL_GAP_MSEC
	_last_spell_time[peer_id] = -SpellCatalog.CAST_INTERVAL_MSEC
	_last_spell_request[peer_id] = 0
	_last_recovery_request[peer_id] = 0
	_last_potion_time[peer_id] = -RecoveryRules.POTION_INTERVAL_MSEC
	_spell_cooldowns[peer_id] = {}

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

	_status_system.clear_player(player)
	_players.erase(peer_id)
	_last_recovery_request.erase(peer_id)
	_last_potion_time.erase(peer_id)
	_next_meditation_tick.erase(peer_id)
	_spell_cooldowns.erase(peer_id)
	_last_move_time.erase(peer_id)
	_last_attack_time.erase(peer_id)
	_last_spell_time.erase(peer_id)
	_last_spell_request.erase(peer_id)
	_last_inventory_request.erase(peer_id)
	_last_shot_request.erase(peer_id)


func try_move_player(
	peer_id: int,
	direction: int,
	current_time: int = -1
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

	if current_time < 0:
		current_time = Time.get_ticks_msec()

	var last_move_time: int = (
		_last_move_time.get(
			peer_id,
			0
		)
	)

	if _status_system.is_rooted(peer_id, current_time):
		return null
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

	player.is_meditating = false
	player.grid_position = new_position
	player.facing_direction = direction

	_last_move_time[peer_id] = MovementRules.get_accepted_move_time(current_time, last_move_time)

	return player


func try_basic_attack(
	attacker_peer_id: int,
	current_time: int = -1
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

	if not attacker.is_alive or attacker.class_id == 8:
		return null

	if attacker.is_ghost:
		return null

	if current_time < 0:
		current_time = Time.get_ticks_msec()

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

	attacker.is_meditating = false
	_last_attack_time[
		attacker_peer_id
	] = current_time

	var attack_offset: Vector2i = (
		MovementRules.get_offset(
			attacker.facing_direction
		)
	)

	var target: PlayerState = null
	# First living opponent in the facing line; walls stop arrows.
	for distance in range(1, int(ClassCatalog.get_profile(attacker.class_id).range) + 1):
		var attack_position := attacker.grid_position + attack_offset * distance
		if not ArenaData.is_walkable(_arena_id, attack_position):
			break
		target = _find_player_at_position(attack_position, attacker_peer_id)
		if target != null:
			break

	if target == null:
		return null

	var damage := ClassCatalog.roll_physical_damage(attacker.class_id, target.class_id, attacker.equipped_items, target.equipped_items)
	if not target.apply_damage(damage):
		return null

	print(
		"%s attacked %s for %d damage. HP: %d/%d"
		% [
			attacker.display_name,
			target.display_name,
			damage,
			target.current_health,
			target.max_health
		]
	)

	if target.is_ghost:
		print(
			"%s died and became a ghost."
			% target.display_name
		)

	basic_attack_resolved.emit({"caster_id": attacker.peer_id, "caster_name": attacker.display_name, "target_id": target.peer_id, "target_name": target.display_name, "amount": damage})
	return target


func try_ranged_attack(peer_id: int, position: Vector2i, request_id: int, now: int = -1) -> Dictionary:
	var attacker: PlayerState = _players.get(peer_id)
	if attacker == null or not attacker.is_alive or attacker.class_id != 8:
		return _spell_error("Este personaje no puede disparar con arco.")
	if request_id <= _last_shot_request.get(peer_id, 0):
		return _spell_error("El disparo ya fue procesado.")
	_last_shot_request[peer_id] = request_id
	if not attacker.equipped_items.has("weapon") or not attacker.equipped_items.has("ammunition"):
		return _spell_error("Equipá el arco y las flechas antes de disparar.")
	var target: PlayerState = _find_player_at_position(position, peer_id)
	if target == null:
		return _spell_error("Elegí un rival vivo para disparar.")
	var delta := position - attacker.grid_position
	if maxi(absi(delta.x), absi(delta.y)) > ClassCatalog.RANGED_RANGE:
		return _spell_error("El rival está fuera del alcance del arco.")
	if not CombatRules.has_clear_shot(_arena_id, attacker.grid_position, position):
		return _spell_error("Hay un obstáculo entre el arco y el objetivo.")
	if now < 0:
		now = Time.get_ticks_msec()
	var remaining: int = CombatRules.BASIC_ATTACK_COOLDOWN_MSEC - (now - _last_attack_time.get(peer_id, -CombatRules.BASIC_ATTACK_COOLDOWN_MSEC))
	if remaining > 0:
		return _spell_error("Esperá el intervalo del arco.", remaining)
	remaining = SpellCatalog.SPELL_ATTACK_GAP_MSEC - (now - _last_spell_time.get(peer_id, -SpellCatalog.SPELL_ATTACK_GAP_MSEC))
	if remaining > 0:
		return _spell_error("Esperá el intervalo entre magia y golpe.", remaining)
	var damage := ClassCatalog.roll_physical_damage(attacker.class_id, target.class_id, attacker.equipped_items, target.equipped_items)
	var previous := target.current_health
	target.apply_damage(damage)
	attacker.is_meditating = false
	attacker.facing_direction = (MovementRules.Direction.EAST if delta.x > 0 else MovementRules.Direction.WEST) if absi(delta.x) > absi(delta.y) else (MovementRules.Direction.SOUTH if delta.y > 0 else MovementRules.Direction.NORTH)
	_last_attack_time[peer_id] = now
	if not target.is_alive:
		_status_system.clear_player(target)
	return {"ok": true, "caster_state": attacker.to_dictionary(), "target_state": target.to_dictionary(), "event": {
		"action": "shot", "request_id": request_id, "caster_id": peer_id, "target_id": target.peer_id,
		"caster_name": attacker.display_name, "target_name": target.display_name, "spell_id": 247,
		"spell_name": "Disparo de arco", "words": "", "effect": "damage", "amount": previous - target.current_health,
		"mana_cost": 0, "origin_x": attacker.grid_position.x, "origin_y": attacker.grid_position.y,
		"target_x": position.x, "target_y": position.y}}


func try_inventory_move(peer_id: int, source: int, destination: int, item_id: int, revision: int, request_id: int) -> Dictionary:
	var valid := _validate_inventory_request(peer_id, source, item_id, revision, request_id)
	if not valid.ok:
		return valid
	var player: PlayerState = _players[peer_id]
	if destination < 0 or destination >= player.inventory.size() or source == destination:
		return _spell_error("Casillero de destino inválido.")
	var previous: int = player.inventory[destination]
	player.inventory[destination] = item_id
	player.inventory[source] = previous
	player.inventory_revision += 1
	return {"ok": true, "state": player.to_dictionary()}


func try_inventory_use(peer_id: int, slot: int, item_id: int, revision: int, request_id: int) -> Dictionary:
	var valid := _validate_inventory_request(peer_id, slot, item_id, revision, request_id)
	if not valid.ok:
		return valid
	var player: PlayerState = _players[peer_id]
	var equipment_slot := ClassCatalog.equipment_slot(player.class_id, item_id)
	if equipment_slot.is_empty():
		return _spell_error("Este objeto no es equipo del preset.")
	if not player.is_alive:
		return _spell_error("Reaparecé o elegí un preset para cambiar equipo.")
	if int(player.equipped_items.get(equipment_slot, 0)) == item_id:
		player.equipped_items.erase(equipment_slot)
	else:
		player.equipped_items[equipment_slot] = item_id
	player.inventory_revision += 1
	return {"ok": true, "state": player.to_dictionary()}


func _validate_inventory_request(peer_id: int, slot: int, item_id: int, revision: int, request_id: int) -> Dictionary:
	var player: PlayerState = _players.get(peer_id)
	if player == null:
		return _spell_error("No hay un personaje conectado.")
	if request_id <= _last_inventory_request.get(peer_id, 0):
		return _spell_error("La acción de inventario ya fue procesada.")
	_last_inventory_request[peer_id] = request_id
	if revision != player.inventory_revision or slot < 0 or slot >= player.inventory.size() or item_id <= 0 or player.inventory[slot] != item_id:
		return _spell_error("El inventario cambió. Volvé a intentar con el objeto actual.")
	return {"ok": true}


func try_cast_spell(caster_id: int, spell_id: int, target_position: Vector2i, request_id: int, now: int = -1) -> Dictionary:
	var caster: PlayerState = _players.get(caster_id)
	if caster == null:
		return _spell_error("No hay un personaje conectado para lanzar.")
	if request_id <= _last_spell_request.get(caster_id, 0):
		return _spell_error("El lanzamiento ya fue procesado.")
	_last_spell_request[caster_id] = request_id
	if not caster.is_alive:
		return _spell_error("No podés lanzar hechizos mientras sos un fantasma.")
	if not SpellCatalog.is_available(spell_id):
		return _spell_error("Este hechizo todavía no está habilitado en la arena.")
	if not ClassCatalog.can_cast(caster.class_id, spell_id):
		return _spell_error("Tu clase no tiene este hechizo en su preset.")
	if not MovementRules.is_inside_bounds(target_position):
		return _spell_error("El objetivo está fuera de la arena.")
	var target: PlayerState = _find_player_at_position(target_position, -1)
	if target == null or not target.is_alive:
		return _spell_error("No hay un objetivo vivo en esa casilla.")
	var spell := SpellCatalog.get_spell(spell_id)
	var offensive: bool = int(spell.raw.get("TargetEffectType", "0")) == 2 or spell.effect == "damage" or spell_id == 243
	if offensive and caster_id == target.peer_id:
		return _spell_error("Elegí a un rival para un hechizo ofensivo.")
	if caster.current_mana < int(spell.mana):
		return _spell_error("No tenés suficiente maná para %s." % spell.name)
	if now < 0:
		now = Time.get_ticks_msec()
	var remaining: int = SpellCatalog.CAST_INTERVAL_MSEC - (now - _last_spell_time.get(caster_id, -SpellCatalog.CAST_INTERVAL_MSEC))
	if remaining > 0:
		return _spell_error("Todavía no podés volver a lanzar.", remaining)
	remaining = SpellCatalog.ATTACK_SPELL_GAP_MSEC - (now - _last_attack_time.get(caster_id, -SpellCatalog.ATTACK_SPELL_GAP_MSEC))
	if remaining > 0:
		return _spell_error("Esperá el intervalo entre golpe y magia.", remaining)
	# Shared effect groups and individual spell IDs are different namespaces.
	# Dart (spell 1) must not accidentally lock Restoration (CdEffectId 1).
	var cooldown_group := int(spell.raw.get("CdEffectId", "0"))
	var cooldown_key := "group:%d" % cooldown_group if cooldown_group > 0 else "spell:%d" % spell_id
	var cooldown: int = int(float(spell.cooldown) * 1000.0)
	remaining = cooldown - (now - int(_spell_cooldowns[caster_id].get(cooldown_key, -cooldown)))
	if remaining > 0:
		return _spell_error("%s todavía está en recarga (%d s)." % [spell.name, ceili(remaining / 1000.0)], remaining)
	var status_message := ""
	if SpellCatalog.STATUS_HANDLERS.has(spell_id) or SpellCatalog.PERIODIC_HANDLERS.has(spell_id):
		var status_result := _status_system.apply_spell(caster, target, spell, now)
		if not status_result.ok:
			return _spell_error(str(status_result.message))
		status_message = str(status_result.message)
	# No await between validation and mutation: one authoritative cost/effect.
	var previous_health := target.current_health
	if int(spell.max_amount) > 0:
		var rolled := randi_range(int(spell.min_amount), int(spell.max_amount))
		if spell.effect == "healing":
			target.restore_health(rolled)
		else:
			target.apply_damage(ClassCatalog.magic_damage(rolled, caster.class_id, target.class_id, caster.equipped_items, target.equipped_items, true, int(spell.raw.get("AntiRm", "0")) == 1))
	caster.spend_mana(int(spell.mana))
	caster.is_meditating = false
	_last_spell_time[caster_id] = now
	_spell_cooldowns[caster_id][cooldown_key] = now
	if not target.is_alive:
		_status_system.clear_player(target)
	return {
		"ok": true, "caster_state": caster.to_dictionary(), "target_state": target.to_dictionary(),
		"event": {"request_id": request_id, "caster_id": caster_id, "target_id": target.peer_id,
			"caster_name": caster.display_name, "target_name": target.display_name,
			"spell_id": spell_id, "spell_name": spell.name, "words": spell.words,
			"effect": spell.effect, "amount": absi(target.current_health - previous_health),
			"status_message": status_message, "mana_cost": int(spell.mana),
			"origin_x": caster.grid_position.x, "origin_y": caster.grid_position.y,
			"target_x": target.grid_position.x, "target_y": target.grid_position.y}
	}


func try_recovery_action(peer_id: int, action: String, request_id: int, now: int = -1) -> Dictionary:
	if now < 0:
		now = Time.get_ticks_msec()
	var player: PlayerState = _players.get(peer_id)
	if player == null:
		return _spell_error("No hay un personaje conectado.")
	if not action in ["meditate", "health_potion", "mana_potion", "respawn"] and not action.begins_with("class:"):
		return _spell_error("Acción desconocida.")
	if request_id <= _last_recovery_request.get(peer_id, 0):
		return _spell_error("La acción ya fue procesada.")
	_last_recovery_request[peer_id] = request_id
	if action.begins_with("class:"):
		return try_select_class(peer_id, int(action.trim_prefix("class:")), now)
	var amount := 0
	var message := ""
	if action == "respawn":
		if player.is_alive:
			return _spell_error("Sólo podés reaparecer después de morir.")
		_status_system.clear_player(player)
		player.grid_position = _get_spawn_position()
		player.is_alive = true
		player.current_health = player.max_health
		player.current_mana = player.max_mana
		player.is_meditating = false
		_last_spell_time[peer_id] = now
		_last_attack_time[peer_id] = now
		_spell_cooldowns[peer_id].clear()
		_last_potion_time[peer_id] = -RecoveryRules.POTION_INTERVAL_MSEC
		message = "Reapareció en la arena."
	elif not player.is_alive:
		return _spell_error("No podés meditar ni usar pociones mientras sos un fantasma. Usá Reaparecer.")
	elif action == "meditate":
		if player.max_mana <= 0:
			return _spell_error("Tu clase no utiliza maná ni meditación.")
		if not player.is_meditating and player.current_mana >= player.max_mana:
			return _spell_error("Ya tenés el maná completo.")
		player.is_meditating = not player.is_meditating
		_next_meditation_tick[peer_id] = now + RecoveryRules.MEDITATION_WARMUP_MSEC
		message = "Comenzó a meditar." if player.is_meditating else "Dejó de meditar."
	else:
		if now - _last_potion_time.get(peer_id, -RecoveryRules.POTION_INTERVAL_MSEC) < RecoveryRules.POTION_INTERVAL_MSEC:
			return _spell_error("Esperá el intervalo de pociones.")
		if now - _last_attack_time.get(peer_id, -RecoveryRules.ATTACK_POTION_GAP_MSEC) < RecoveryRules.ATTACK_POTION_GAP_MSEC:
			return _spell_error("Esperá el intervalo entre golpe y poción.")
		var potion := RecoveryRules.get_potion(action)
		if potion.is_empty():
			return _spell_error("Faltan los datos de la poción.")
		if action == "health_potion":
			if player.current_health >= player.max_health:
				return _spell_error("Ya tenés la vida completa.")
			var previous := player.current_health
			player.restore_health(randi_range(int(potion.min), int(potion.max)))
			amount = player.current_health - previous
		else:
			if player.current_mana >= player.max_mana:
				return _spell_error("Ya tenés el maná completo.")
			var previous := player.current_mana
			player.restore_mana(maxi(1, int(player.max_mana * int(potion.percent) / 100.0)))
			amount = player.current_mana - previous
		# Drinking preserves meditation and its scheduled tick. Full mana still
		# ends it immediately, as it does when regeneration fills the resource.
		if player.current_mana >= player.max_mana:
			player.is_meditating = false
		_last_potion_time[peer_id] = now
		message = "Usó %s (+%d)." % [potion.name, amount]
	return {"ok": true, "state": player.to_dictionary(), "event": {
		"peer_id": peer_id, "player_name": player.display_name, "action": action,
		"amount": amount, "message": message, "is_meditating": player.is_meditating}}


func try_select_class(peer_id: int, class_id: int, now: int = -1) -> Dictionary:
	var player: PlayerState = _players.get(peer_id)
	var profile := ClassCatalog.get_profile(class_id)
	if player == null or profile.is_empty():
		return _spell_error("Clase desconocida o personaje desconectado.")
	if now < 0:
		now = Time.get_ticks_msec()
	player.class_id = class_id
	player.max_health = int(profile.max_health)
	player.max_mana = int(profile.max_mana)
	player.current_health = player.max_health
	player.current_mana = player.max_mana
	player.is_alive = true
	player.is_meditating = false
	_status_system.clear_player(player)
	_next_meditation_tick.erase(peer_id)
	player.reset_preset_inventory()
	player.preset_revision += 1
	_last_spell_time[peer_id] = -SpellCatalog.CAST_INTERVAL_MSEC
	_last_attack_time[peer_id] = -SpellCatalog.SPELL_ATTACK_GAP_MSEC
	_last_potion_time[peer_id] = -RecoveryRules.POTION_INTERVAL_MSEC
	_spell_cooldowns[peer_id] = {}
	return {"ok": true, "state": player.to_dictionary(), "event": {
		"peer_id": peer_id, "player_name": player.display_name, "action": "class",
		"class_id": class_id, "amount": 0, "message": "Preset %s listo para probar." % profile.name,
		"is_meditating": false}}


func advance_runtime(now: int = -1) -> Array[PlayerState]:
	if now < 0:
		now = Time.get_ticks_msec()
	var changed := _status_system.tick(_players, now)
	for player: PlayerState in _players.values():
		if not player.is_alive or not player.is_meditating:
			continue
		if now < _next_meditation_tick.get(player.peer_id, now):
			continue
		player.restore_mana(maxi(1, int(player.max_mana * RecoveryRules.MEDITATION_PERCENT / 100.0)))
		_next_meditation_tick[player.peer_id] = now + RecoveryRules.MEDITATION_INTERVAL_MSEC
		if player.current_mana >= player.max_mana:
			player.is_meditating = false
		if not changed.has(player):
			changed.append(player)
	return changed


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
