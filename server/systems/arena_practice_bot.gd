class_name ArenaPracticeBot
extends RefCounted

signal reset_world
signal removed(peer_id: int)
signal status_changed(status: Dictionary)

const BOT_ID := -1000 # Entity ID only; never a network recipient or the -1 lookup sentinel.
const THINK_MSEC := 120
const COMMAND_INTERVAL_MSEC := 400
const MOVE_INTERVAL_MSEC := 150
const CAST_INTERVAL_MSEC := 1150
const ATTACK_INTERVAL_MSEC := 650
const POTION_INTERVAL_MSEC := 350
var registry: PlayerRegistry
var owner_id := 0
var phase := "idle"
var _ready_at := 0
var _next_observation := 0
var _observed_cell := Vector2i.ZERO
var _observed_rooted := false
var _next_move := 0
var _next_choice := 0
var _move_goal := Vector2i(-1, -1)
var _next_offense := 0
var _potion_due := 0
var _last_potion := ""
var _root_due := 0
var _root_observed := false
var _defending := false
var _next_heal := 0
var _movement_mode := 1
var _rng := RandomNumberGenerator.new()
var _next_control := 0
var _cast_request := 0
var _recovery_request := 0
var _shot_request := 0
var _last_request: Dictionary = {}
var _last_command: Dictionary = {}

func _init(players: PlayerRegistry, random_seed: int = -1) -> void:
	registry = players
	if random_seed < 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed

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
	_ready_at = now + _rng.randi_range(600, 850)
	_next_observation = _ready_at
	_observed_cell = owner.grid_position
	_observed_rooted = false
	_next_move = _ready_at
	_next_offense = _ready_at
	_next_choice = 0
	_move_goal = Vector2i(-1, -1)
	_movement_mode = 1
	_next_control = now + _rng.randi_range(6000, 9000)
	reset_world.emit()
	status_changed.emit(status())
	return {"ok": true}

func remove_bot(notify: bool = true) -> void:
	if registry.has_player(BOT_ID):
		registry.remove_player(BOT_ID)
		removed.emit(BOT_ID)
	owner_id = 0
	phase = "idle"
	_defending = false
	_next_heal = 0
	_last_potion = ""
	_potion_due = 0
	_root_due = 0
	_root_observed = false
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
	if now < _ready_at:
		return actions
	# Perception has human-scale latency. Movement and recovery do not wait for it.
	if now >= _next_observation:
		_observed_cell = target.grid_position
		_observed_rooted = target.active_effects.has("Paralizado") or target.active_effects.has("Inmovilizado")
		_next_observation = now + _rng.randi_range(THINK_MSEC - 30, THINK_MSEC + 30)
	var caster := bot.class_id in [1, 2, 5, 6]
	var ranged := caster or bot.class_id == 8
	var distance := _distance(bot.grid_position, _observed_cell)
	if not _defending and (bot.current_health < bot.max_health * 0.45 or (caster and bot.current_mana < bot.max_mana * 0.18)):
		_defending = true
		_next_choice = 0
	elif _defending and bot.current_health >= bot.max_health * 0.65 and (not caster or bot.current_mana >= bot.max_mana * 0.35):
		_defending = false
		_next_choice = 0
	var rooted := bot.active_effects.has("Paralizado") or bot.active_effects.has("Inmovilizado")
	if rooted and not _root_observed:
		_root_due = now + _rng.randi_range(350, 550)
	_root_observed = rooted
	var removing := rooted and ClassCatalog.can_cast(bot.class_id, 27) and bot.current_mana >= int(SpellCatalog.get_spell(27).mana)
	if removing and now >= _root_due:
		_root_due = now + 60
		if _cast(27, bot.grid_position, now, actions):
			_root_observed = false
	_tick_potions(bot, now, actions)
	if bot.is_meditating:
		if bot.current_mana >= bot.max_mana * 0.3 or distance <= 2:
			_recover("meditate", now, actions)
		else:
			return actions
	if caster and bot.current_mana < 100 and distance >= 4 and not removing:
		_recover("meditate", now, actions)
		return actions
	# A defensive spell uses the same global cast interval as an attack.
	if not removing and now >= _next_offense:
		var healed := false
		if now >= _next_heal and bot.current_health < bot.max_health * 0.45:
			_next_heal = now + _rng.randi_range(1800, 2400)
			if _rng.randf() < 0.65:
				healed = _cast(31, bot.grid_position, now, actions)
		if not healed:
			_attack(bot, ranged, caster, now, actions)
	if not target.is_alive:
		phase = "lost"
		status_changed.emit(status())
		return actions
	# Keep a movement burst running while casting or drinking, at player cadence.
	if not bot.is_meditating and now >= _next_move:
		var direction := _movement_step(bot, _observed_cell, ranged, now)
		if direction != -1:
			var moved := registry.try_move_player(BOT_ID, direction, now)
			if moved != null:
				_next_move = now + MOVE_INTERVAL_MSEC
				actions.append({"kind": "move", "state": moved.to_dictionary()})
	return actions

func _attack(bot: PlayerState, ranged: bool, caster: bool, now: int, actions: Array[Dictionary]) -> void:
	var delta := _observed_cell - bot.grid_position
	if ranged:
		if _distance(bot.grid_position, _observed_cell) > 8 or not CombatRules.has_clear_shot(registry.get_arena_id(), bot.grid_position, _observed_cell):
			return
		var spell := 0
		if caster:
			spell = int(ClassCatalog.get_profile(bot.class_id).bindings[2])
			var choice := _rng.randf()
			if now >= _next_control and not _observed_rooted and bot.current_mana > 700 and choice < 0.3:
				spell = 25
				_next_control = now + _rng.randi_range(8000, 12000)
			elif choice < 0.1:
				spell = 3
			elif choice > 0.95 and ClassCatalog.can_cast(bot.class_id, 53) and bot.current_mana >= 1000:
				spell = 53
			if not ClassCatalog.can_cast(bot.class_id, spell) or bot.current_mana < int(SpellCatalog.get_spell(spell).mana):
				spell = 3
		var cell := _observed_cell
		if _rng.randf() < 0.06:
			cell += MovementRules.get_offset(_rng.randi_range(0, 3))
		# An inaccurate click costs the opportunity too; no free rapid retries.
		var interval := maxi(SpellCatalog.CAST_INTERVAL_MSEC, CAST_INTERVAL_MSEC) if caster else maxi(CombatRules.BASIC_ATTACK_COOLDOWN_MSEC, ATTACK_INTERVAL_MSEC)
		_next_offense = now + interval + _rng.randi_range(0, 100)
		if caster:
			_cast(spell, cell, now, actions)
		else:
			_shot_request += 1
			var shot := registry.try_ranged_attack(BOT_ID, cell, _shot_request, now)
			if shot.ok:
				actions.append({"kind": "cast", "result": shot})
	elif absi(delta.x) + absi(delta.y) == 1:
		# Leave a real recovery window after a melee hit when health is low.
		if _defending and _potion_due != 0:
			return
		_next_offense = now + maxi(CombatRules.BASIC_ATTACK_COOLDOWN_MSEC, ATTACK_INTERVAL_MSEC) + _rng.randi_range(0, 100)
		if _rng.randf() < 0.06:
			return
		bot.facing_direction = _direction(delta)
		var target_state := registry.try_basic_attack(BOT_ID, now)
		if target_state != null:
			actions.append({"kind": "melee", "attacker": bot.to_dictionary(), "target": target_state.to_dictionary()})

func _tick_potions(bot: PlayerState, now: int, actions: Array[Dictionary]) -> void:
	var red := bot.current_health < bot.max_health * 0.78 and bot.max_health - bot.current_health >= 27
	var blue := bot.max_mana > 0 and bot.current_mana < bot.max_mana * 0.65
	if not red and not blue:
		_potion_due = 0
		return
	if _potion_due == 0:
		_potion_due = now + _rng.randi_range(160, 260)
		return
	if now < _potion_due:
		return
	var action := "health_potion" if red else "mana_potion"
	if red and blue and bot.current_health >= bot.max_health * 0.4:
		if bot.current_mana < bot.max_mana * 0.2 or _last_potion == "health_potion":
			action = "mana_potion"
	if _recover(action, now, actions):
		_last_potion = action
		_potion_due = now + maxi(RecoveryRules.POTION_INTERVAL_MSEC, POTION_INTERVAL_MSEC) + _rng.randi_range(0, 40)
	else:
		# A normal attack/potion gap can block this; retain the pending decision.
		_potion_due = now + 40

func _movement_step(bot: PlayerState, target: Vector2i, ranged: bool, now: int) -> int:
	var distance := _distance(bot.grid_position, target)
	if not ranged and not _defending:
		return _path_step(bot, target, false)
	if ranged and (distance < 3 or distance > 7 or not CombatRules.has_clear_shot(registry.get_arena_id(), bot.grid_position, target)):
		return _path_step(bot, target, true)
	# A goal persists for several tiles, rather than rolling each step or after a cast.
	if now < _next_choice:
		if _movement_mode == 0:
			return -1
		if bot.grid_position != _move_goal:
			var direction := _direction(_move_goal - bot.grid_position)
			if _free(bot.grid_position + MovementRules.get_offset(direction)):
				return direction
	_next_choice = now + _rng.randi_range(480, 850)
	var roll := _rng.randf()
	_movement_mode = 3 if _defending else 0 if roll < 0.1 else 1 if roll < 0.65 else 2 if roll < 0.85 else 3
	if _movement_mode == 0:
		_next_choice = now + _rng.randi_range(150, 260)
		return -1
	var delta := target - bot.grid_position
	var candidates: Array[Vector2i] = []
	for direction: int in _directions():
		var offset := MovementRules.get_offset(direction)
		if _movement_mode == 1 and ((absi(delta.x) >= absi(delta.y) and offset.x != 0) or (absi(delta.x) < absi(delta.y) and offset.y != 0)):
			continue
		var cell := bot.grid_position
		for step in range(_rng.randi_range(2, 4)):
			var next := cell + offset
			var after := _distance(next, target)
			if not _free(next) or after < 2 or after > 7:
				break
			if ranged and not CombatRules.has_clear_shot(registry.get_arena_id(), next, target):
				break
			if (_movement_mode == 2 and after > distance) or (_movement_mode == 3 and after < distance):
				break
			cell = next
		if cell != bot.grid_position:
			candidates.append(cell)
	if candidates.is_empty():
		_move_goal = Vector2i(-1, -1)
		return -1
	_move_goal = candidates[_rng.randi_range(0, candidates.size() - 1)]
	return _direction(_move_goal - bot.grid_position)

func _distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

func _directions() -> Array[int]:
	var directions: Array[int] = [0, 1, 2, 3]
	for index in range(3, 0, -1):
		var other := _rng.randi_range(0, index)
		var old := directions[index]
		directions[index] = directions[other]
		directions[other] = old
	return directions

func _cast(spell_id: int, target: Vector2i, now: int, actions: Array[Dictionary]) -> bool:
	var bot := registry.get_player(BOT_ID)
	if spell_id <= 0 or not ClassCatalog.can_cast(bot.class_id, spell_id) or bot.current_mana < int(SpellCatalog.get_spell(spell_id).mana):
		return false
	_cast_request += 1
	var result := registry.try_cast_spell(BOT_ID, spell_id, target, _cast_request, now)
	if result.ok:
		_next_offense = maxi(_next_offense, now + maxi(SpellCatalog.CAST_INTERVAL_MSEC, CAST_INTERVAL_MSEC) + _rng.randi_range(0, 100))
		actions.append({"kind": "cast", "result": result})
	return bool(result.ok)

func _recover(action: String, now: int, actions: Array[Dictionary]) -> bool:
	_recovery_request += 1
	var result := registry.try_recovery_action(BOT_ID, action, _recovery_request, now)
	if result.ok:
		actions.append({"kind": "recovery", "result": result})
	return bool(result.ok)

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

func _path_step(bot: PlayerState, target: Vector2i, ranged: bool) -> int:
	var queue: Array[Vector2i] = [bot.grid_position]
	var first: Dictionary = {bot.grid_position: -1}
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		var delta := target - cell
		if (_firing_position(cell, target) if ranged else absi(delta.x) + absi(delta.y) == 1):
			return int(first[cell])
		for direction: int in _directions():
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
