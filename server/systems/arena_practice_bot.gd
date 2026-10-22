class_name ArenaPracticeBot
extends RefCounted

signal reset_world
signal removed(peer_id: int)
signal status_changed(status: Dictionary)

const BOT_ID := -1000 # Entity ID only; never a network recipient or the -1 lookup sentinel.
const COUNTDOWN_MSEC := 3000
const THINK_MSEC := 120
const COMMAND_INTERVAL_MSEC := 400
const MOVE_INTERVAL_MSEC := MovementRules.PRACTICE_BOT_MOVE_INTERVAL_MSEC
const CAST_INTERVAL_MSEC := 1250
const ATTACK_INTERVAL_MSEC := 650
const POTION_INTERVAL_MSEC := 280
var registry: PlayerRegistry
var owner_id := 0
var phase := "idle"
var _ready_at := 0
var _starts_at := 0
var _countdown := 0
var round_id := ""
var _next_observation := 0
var _observed_cell := Vector2i.ZERO
var _observed_rooted := false
var _next_move := 0
var _next_choice := 0
var _move_goal := Vector2i(-1, -1)
var _next_offense := 0
var _next_spell := 0
var _potion_due := 0
var _last_potion := ""
var _root_due := 0
var _root_observed := false
var _defending := false
var _next_heal := 0
var _last_red_at := -100000
var _movement_mode := 1
var _last_move_direction := -1
var _axis_run := 0
var _recent_cells: Array[Vector2i] = []
var _combo_step := 0
var _combo_until := 0
var _combo_rebuilding := false
var _fallback_used := false
var _semi_combos := 0
var _semi_step := 0
var _semi_until := 0
var _next_melee := 0
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
	var owner := registry.get_player(owner_id)
	return {"enabled": bot != null, "owner_id": owner_id, "bot_id": BOT_ID if bot != null else 0,
		"owner_class_id": owner.class_id if owner != null else ClassCatalog.DEFAULT_CLASS,
		"class_id": bot.class_id if bot != null else 3, "phase": phase, "human_count": human_ids().size(),
		"round_id": round_id, "countdown": _countdown}

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
	return _start_round(peer_id, class_id, now)

func restart_after_preset(peer_id: int, now: int = -1) -> void:
	if peer_id == owner_id and registry.has_player(BOT_ID):
		_start_round(peer_id, registry.get_player(BOT_ID).class_id, Time.get_ticks_msec() if now < 0 else now)

func _start_round(peer_id: int, class_id: int, now: int) -> Dictionary:
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
	phase = "countdown"
	round_id = Crypto.new().generate_random_bytes(16).hex_encode()
	_starts_at = now + COUNTDOWN_MSEC
	_countdown = 3
	registry.set_round_locked(peer_id, true)
	registry.set_round_locked(BOT_ID, true)
	_cast_request = 0
	_recovery_request = 0
	_shot_request = 0
	_ready_at = _starts_at + (_rng.randi_range(450,650) if class_id==1 else _rng.randi_range(600,850))
	_next_observation = _ready_at
	_observed_cell = owner.grid_position
	_observed_rooted = false
	_next_move = _ready_at
	_next_offense = _ready_at
	_next_spell = _ready_at
	_next_choice = 0
	_move_goal = Vector2i(-1, -1)
	_movement_mode = 1
	_last_move_direction = -1
	_axis_run = 0
	_recent_cells.clear()
	_combo_step = 0
	_combo_until = 0
	_combo_rebuilding = false
	_fallback_used = false
	_semi_combos = 0
	_semi_step = 0
	_semi_until = 0
	_next_melee = _ready_at
	_next_control = _ready_at if _is_semimagic(bot) else _starts_at + _rng.randi_range(10000, 14000)
	reset_world.emit()
	status_changed.emit(status())
	return {"ok": true}

func remove_bot(notify: bool = true) -> void:
	registry.set_round_locked(owner_id, false)
	registry.set_round_locked(BOT_ID, false)
	round_id = ""
	_countdown = 0
	if registry.has_player(BOT_ID):
		registry.remove_player(BOT_ID)
		removed.emit(BOT_ID)
	owner_id = 0
	phase = "idle"
	_defending = false
	_next_heal = 0
	_last_red_at = -100000
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
	if phase not in ["active", "countdown"]:
		return actions
	if now < 0:
		now = Time.get_ticks_msec()
	var bot := registry.get_player(BOT_ID)
	var target := registry.get_player(owner_id)
	if bot == null or target == null or human_ids().size() != 1:
		remove_bot()
		return actions
	if phase == "countdown":
		var seconds := maxi(0, ceili((_starts_at - now) / 1000.0))
		if now >= _starts_at:
			phase = "active"
			registry.set_round_locked(owner_id, false)
			registry.set_round_locked(BOT_ID, false)
		if _countdown != seconds:
			_countdown = seconds
			status_changed.emit(status())
		if phase == "countdown":
			return actions
	if settle_round():
		return actions
	if now < _ready_at:
		return actions
	# Perception has human-scale latency. Movement and recovery do not wait for it.
	if now >= _next_observation:
		_observed_cell = target.grid_position
		_observed_rooted = target.active_effects.has("Paralizado") or target.active_effects.has("Inmovilizado")
		_next_observation = now + _rng.randi_range(THINK_MSEC - 30, THINK_MSEC + 30)
	var caster := bot.class_id in [1, 6]
	var ranged := caster or bot.class_id == 8
	var distance := _distance(bot.grid_position, _observed_cell)
	if not _defending and (bot.current_health < bot.max_health * 0.55 or (caster and bot.current_mana < bot.max_mana * 0.18)):
		_defending = true
		_next_choice = 0
	elif _defending and bot.current_health >= bot.max_health * 0.75 and (not caster or bot.current_mana >= bot.max_mana * 0.35):
		_defending = false
		_next_choice = 0
	var rooted := bot.active_effects.has("Paralizado") or bot.active_effects.has("Inmovilizado")
	if rooted and not _root_observed:
		_root_due = now + _rng.randi_range(650, 850)
	_root_observed = rooted
	var removing := rooted and ClassCatalog.can_cast(bot.class_id, 27) and bot.current_mana >= int(SpellCatalog.get_spell(27).mana)
	if removing and now >= _root_due and now >= _next_spell:
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
		if now >= _next_heal and bot.current_health < bot.max_health * 0.55 and now >= _next_spell:
			_next_heal = now + _rng.randi_range(3400, 4200)
			if _rng.randf() < 0.60:
				healed = _cast(31, bot.grid_position, now, actions)
				if healed: _potion_due = maxi(_potion_due,now+550)
		if not healed:
			_attack(bot, ranged, caster, now, actions)
	if not target.is_alive:
		phase = "lost"
		status_changed.emit(status())
		return actions
	# Human movement cadence, with varied bursts independent of spell/potion clocks.
	if not bot.is_meditating and now >= _next_move:
		var direction := _movement_step(bot, _observed_cell, ranged, now)
		if direction != -1:
			var moved := registry.try_move_player(BOT_ID, direction, now)
			if moved != null:
				_next_move = now + _move_interval(bot)
				_remember_move(direction, moved.grid_position)
				actions.append({"kind": "move", "state": moved.to_dictionary()})
	return actions

# Called immediately after a human hit too, before a preset/respawn can erase a defeat.
func settle_round() -> bool:
	if phase != "active":
		return phase in ["won", "lost"]
	var bot := registry.get_player(BOT_ID)
	var owner := registry.get_player(owner_id)
	if bot != null and owner != null and (not bot.is_alive or not owner.is_alive):
		phase = "won" if not bot.is_alive and owner.is_alive else "lost"
		status_changed.emit(status())
		return true
	return false

func _attack(bot: PlayerState, ranged: bool, caster: bool, now: int, actions: Array[Dictionary]) -> void:
	var delta := _observed_cell - bot.grid_position
	if ranged:
		if _distance(bot.grid_position, _observed_cell) > 8 or not CombatRules.has_clear_shot(registry.get_arena_id(), bot.grid_position, _observed_cell):
			return
		var spell := 0
		if caster:
			spell = _combo_spell(bot, now)
			var choice := _rng.randf()
			if _combo_step == 0 and now >= _next_control and not _observed_rooted and bot.current_mana >= _mana_reserve(bot) and choice < 0.3:
				spell = 25
				_next_control = now + _rng.randi_range(14000, 18000)
		var cell := _observed_cell
		if _rng.randf() < (0.04 if bot.class_id==1 else 0.06):
			cell += MovementRules.get_offset(_rng.randi_range(0, 3))
		# An inaccurate click costs the opportunity too; no free rapid retries.
		var interval := maxi(SpellCatalog.CAST_INTERVAL_MSEC, CAST_INTERVAL_MSEC) if caster else maxi(CombatRules.RANGED_ATTACK_COOLDOWN_MSEC, ATTACK_INTERVAL_MSEC)
		_next_offense = now + interval + _rng.randi_range(0, 100)
		if caster:
			if _cast(spell, cell, now, actions) and spell != 25:
				_record_combo_spell(bot, spell, now)
		else:
			_shot_request += 1
			var shot := registry.try_ranged_attack(BOT_ID, cell, _shot_request, now)
			if shot.ok:
				actions.append({"kind": "cast", "result": shot})
	elif _is_semimagic(bot):
		_semi_attack(bot, now, actions)
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
	var red := bot.max_health - bot.current_health >= 27
	var blue := bot.max_mana > 0 and bot.current_mana < _mana_reserve(bot)
	if not red and not blue:
		_potion_due = 0
		return
	if _potion_due == 0:
		_potion_due = now + _rng.randi_range(120, 180)
		return
	if now < _potion_due:
		return
	var action := "health_potion" if red else "mana_potion"
	if red and blue and bot.current_health >= bot.max_health * 0.65:
		if bot.current_mana < bot.max_mana * 0.2 or _last_potion == "health_potion":
			action = "mana_potion"
	if _recover(action, now, actions):
		_last_potion = action
		if action == "health_potion":
			_last_red_at = now
			# Emergency recovery is a defensive choice; do not weave free offense into it.
			if bot.current_health < bot.max_health * 0.45:
				_next_offense = maxi(_next_offense,now+220)
		_potion_due = now + maxi(RecoveryRules.POTION_INTERVAL_MSEC, POTION_INTERVAL_MSEC)
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
			if (_axis_run < 4 or direction % 2 != _last_move_direction % 2) and _free(bot.grid_position + MovementRules.get_offset(direction)):
				return direction
	_next_choice = now + _rng.randi_range(450, 800)
	var roll := _rng.randf()
	_movement_mode = 0 if roll < 0.05 else 3 if _defending and roll < 0.7 else 1 if roll < 0.45 else 2 if roll < 0.75 else 3
	if _movement_mode == 0:
		_next_choice = now + _rng.randi_range(150, 260)
		return -1
	var candidates: Array[Dictionary] = []
	var total_weight := 0.0
	for direction: int in _directions():
		var offset := MovementRules.get_offset(direction)
		if _axis_run >= 4 and direction % 2 == _last_move_direction % 2:
			continue
		var cell := bot.grid_position
		for step in range(_rng.randi_range(2, 4)):
			var next := cell + offset
			var after := _distance(next, target)
			if not _free(next) or after < 2 or after > 7:
				break
			if ranged and not CombatRules.has_clear_shot(registry.get_arena_id(), next, target):
				break
			cell = next
		if cell != bot.grid_position:
			var after := _distance(cell, target)
			var weight := 3.0 if (_movement_mode == 1 and absi(after - distance) <= 1) or (_movement_mode == 2 and after < distance) or (_movement_mode == 3 and after > distance) else 1.0
			if _last_move_direction >= 0 and direction == (_last_move_direction + 2) % 4:
				weight *= 0.3
			if _recent_cells.has(cell):
				weight *= 0.25
			total_weight += weight
			candidates.append({"cell": cell, "weight": weight})
	if candidates.is_empty():
		_move_goal = Vector2i(-1, -1)
		return _path_step(bot, target, ranged)
	var draw := _rng.randf() * total_weight
	_move_goal = candidates[-1].cell
	for candidate: Dictionary in candidates:
		draw -= float(candidate.weight)
		if draw <= 0.0:
			_move_goal = candidate.cell
			break
	return _direction(_move_goal - bot.grid_position)


func _remember_move(direction: int, cell: Vector2i) -> void:
	_axis_run = _axis_run + 1 if _last_move_direction >= 0 and direction % 2 == _last_move_direction % 2 else 1
	_last_move_direction = direction
	_recent_cells.append(cell)
	if _recent_cells.size() > 8:
		_recent_cells.pop_front()


func _is_semimagic(bot: PlayerState) -> bool:
	return bot.max_mana > 0 and bot.class_id not in [1, 6]

func _heavy_spell(bot: PlayerState) -> int:
	return 53 if bot.class_id == 1 else 59

func _mana_reserve(bot: PlayerState) -> int:
	if bot.max_mana <= 0: return 0
	if bot.class_id in [1, 6]:
		var heavy_cost := int(SpellCatalog.get_spell(_heavy_spell(bot)).mana)
		var reserve := heavy_cost * (1 if _combo_step == 1 else 2)
		# Recover a real two-cast budget: 65% could strand the mage below it.
		return mini(bot.max_mana, reserve + int(SpellCatalog.get_spell(27).mana) + roundi(bot.max_mana * 0.05))
	var cost := int(SpellCatalog.get_spell(25).mana) + int(SpellCatalog.get_spell(51).mana) + int(SpellCatalog.get_spell(27).mana)
	return mini(bot.max_mana, maxi(roundi(bot.max_mana * 0.65), cost))

func _affordable(bot: PlayerState, candidates: Array[int]) -> int:
	for id in candidates:
		if ClassCatalog.can_cast(bot.class_id,id) and bot.current_mana >= int(SpellCatalog.get_spell(id).mana): return id
	return 0

func _combo_spell(bot: PlayerState, now: int) -> int:
	if now > _combo_until and _combo_step == 1:
		_combo_step = 0
		_combo_rebuilding = true
	var heavy := _heavy_spell(bot)
	var cost := int(SpellCatalog.get_spell(heavy).mana)
	if _combo_step == 1:
		if bot.current_mana >= cost: return heavy
		_combo_step = 0
		_combo_rebuilding = true
	if _combo_step == 0 and bot.current_mana >= cost * 2:
		_combo_rebuilding = false
		_fallback_used = false
		return heavy
	# After the opening heavy pair, the mage can press with a real
	# Apocalypse+Discharge budget instead of idling until two Apocalypses.
	var mixed_cost := cost + int(SpellCatalog.get_spell(51).mana)
	if bot.class_id==1 and _combo_rebuilding and bot.current_mana>=mixed_cost:
		_fallback_used=false
		return heavy
	_combo_rebuilding = true
	# One fallback per rebuild: Discharge first, Firestorm only if too low.
	# Then save blue-potion mana for the next heavy pair, without cheap spam.
	if _fallback_used: return 0
	if bot.class_id == 1:
		return _affordable(bot,[51,41,39,3])
	return _affordable(bot,[113,43,3])

func _record_combo_spell(bot: PlayerState, spell: int, now: int) -> void:
	if spell == _heavy_spell(bot):
		if _combo_step == 1:
			_combo_step = 0
			_combo_rebuilding = true
			_fallback_used = false
		else: _combo_step = 1
		_combo_until = now + 6000
	elif _combo_rebuilding: _fallback_used = true

func _semi_attack(bot: PlayerState, now: int, actions: Array[Dictionary]) -> void:
	var distance := _distance(bot.grid_position,_observed_cell)
	var adjacent := absi(bot.grid_position.x-_observed_cell.x)+absi(bot.grid_position.y-_observed_cell.y)==1
	if now > _semi_until and _semi_step != 0: _semi_step = 0
	var clear := distance <= 8 and CombatRules.has_clear_shot(registry.get_arena_id(),bot.grid_position,_observed_cell)
	if clear and _semi_step == 0 and now >= _next_control and not _observed_rooted:
		var opener_cost := int(SpellCatalog.get_spell(25).mana) + int(SpellCatalog.get_spell(51).mana)
		if bot.current_mana >= mini(bot.max_mana,opener_cost) and _cast(25,_observed_cell,now,actions):
			_semi_step = 1
			_semi_until = now + 6000
			_next_control = now + _rng.randi_range(7500,10000)
			_next_offense = now + SpellCatalog.SPELL_ATTACK_GAP_MSEC
			return
	if _semi_step == 2 and clear:
		var finish_cost := int(SpellCatalog.get_spell(51).mana)
		var missing := finish_cost-bot.current_mana
		# Keep a finishing opportunity when only one/two real blues are missing.
		if ClassCatalog.can_cast(bot.class_id,51) and missing > 0 and missing <= maxi(1,roundi(bot.max_mana*0.05))*2 and bot.current_health >= bot.max_health*0.55 and now < _semi_until-1000: return
		var spell := _semi_finish_spell(bot)
		if spell > 0 and _cast(spell,_observed_cell,now,actions):
			_semi_combos = _semi_combos+1 if spell==51 else 0
			_semi_step = 0
			_next_offense = now + SpellCatalog.SPELL_ATTACK_GAP_MSEC
			return
		if now < _next_spell: return
		_semi_step = 0
	if adjacent and now >= _next_melee:
		if _defending and _potion_due != 0: return
		bot.facing_direction = _direction(_observed_cell-bot.grid_position)
		_next_melee = now + maxi(CombatRules.BASIC_ATTACK_COOLDOWN_MSEC,ATTACK_INTERVAL_MSEC) + _rng.randi_range(0,100)
		var target := registry.try_basic_attack(BOT_ID,now)
		if target != null:
			# A legitimate miss is still an action, never a free retry.
			actions.append({"kind":"melee","attacker":bot.to_dictionary(),"target":target.to_dictionary()})
			_semi_step = 2
			_semi_until = now + 4500
			_next_offense = now + SpellCatalog.ATTACK_SPELL_GAP_MSEC
		else: _next_offense = now + 100
		return
	if _semi_step == 1 and now < _semi_until-3000: return
	if clear and distance >= 2 and now >= _next_spell:
		_next_offense = now + 300
		if _semi_combos>=2 and _rng.randf() < 0.20:
			var spell := _semi_finish_spell(bot)
			if spell > 0 and _cast(spell,_observed_cell,now,actions):
				if spell!=51: _semi_combos=0
				_semi_step = 0


func _move_interval(bot: PlayerState) -> int:
	return 140 if _is_semimagic(bot) else MOVE_INTERVAL_MSEC

func _semi_finish_spell(bot: PlayerState) -> int:
	if _affordable(bot,[51])==51: return 51
	# Cheap pressure is earned by several actual melee/Discharge chains.
	# Never substitute Electric Arrow or Magic Missiles for a finisher.
	return _affordable(bot,[39,41]) if _semi_combos>=3 else 0


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
	if now < _next_spell or spell_id <= 0 or not ClassCatalog.can_cast(bot.class_id, spell_id) or bot.current_mana < int(SpellCatalog.get_spell(spell_id).mana):
		return false
	_cast_request += 1
	var result := registry.try_cast_spell(BOT_ID, spell_id, target, _cast_request, now)
	if result.ok:
		_next_spell = now + maxi(SpellCatalog.CAST_INTERVAL_MSEC, CAST_INTERVAL_MSEC) + _rng.randi_range(0, 100)
		_next_offense = maxi(_next_offense, _next_spell)
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
