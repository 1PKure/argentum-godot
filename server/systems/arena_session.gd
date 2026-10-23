class_name ArenaSession
extends RefCounted

const TRANSITION_MSEC := 600
const CHANGE_INTERVAL_MSEC := TRANSITION_MSEC
var registry: PlayerRegistry
var bot: ArenaPracticeBot
var revision := 0
var _unlock_at := 0
var _last_change := -CHANGE_INTERVAL_MSEC
var _last_request: Dictionary = {}

func _init(players: PlayerRegistry, practice: ArenaPracticeBot) -> void:
	registry = players
	bot = practice

func owner_id() -> int:
	var humans := bot.human_ids()
	return humans[0] if not humans.is_empty() else 0

func status() -> Dictionary:
	return {"arena_id":registry.get_arena_id(), "owner_id":owner_id(), "revision":revision, "transitioning":_unlock_at > 0}

func change(peer_id: int, arena_id: String, expected_revision: int, request_id: int, now: int = -1) -> Dictionary:
	if now < 0: now = Time.get_ticks_msec()
	if not bot.human_ids().has(peer_id) or peer_id != owner_id():
		return _error("Sólo el anfitrión puede cambiar la arena.")
	if request_id <= int(_last_request.get(peer_id,0)):
		return _error("La solicitud ya fue procesada.")
	_last_request[peer_id] = request_id
	if not ArenaData.is_implemented(arena_id):
		return _error("Arena desconocida.")
	if expected_revision != revision:
		return _error("La arena cambió. Volvé a elegir el escenario.")
	if _unlock_at > 0 or now - _last_change < CHANGE_INTERVAL_MSEC:
		return _error("Esperá a que termine el cambio de arena.")
	if arena_id == registry.get_arena_id():
		return _error("Esa arena ya está seleccionada.")
	var previous_bot := registry.get_player(ArenaPracticeBot.BOT_ID)
	var bot_class := previous_bot.class_id if previous_bot != null else 0
	var owner := bot.owner_id
	bot.remove_bot(false)
	registry.set_arena(arena_id)
	var occupied: Array[Vector2i] = []
	var spawns := ArenaData.get_spawn_points(arena_id)
	for id: int in bot.human_ids():
		var player := registry.get_player(id)
		registry.try_select_class(id,player.class_id,now)
		var cell: Vector2i = spawns[occupied.size()] if occupied.size() < spawns.size() else _free_cell(arena_id,occupied)
		player.grid_position = cell
		player.facing_direction = MovementRules.Direction.EAST if occupied.is_empty() else MovementRules.Direction.WEST
		occupied.append(cell)
		registry.set_round_locked(id,true)
	if bot_class != 0:
		bot.set_block_signals(true)
		bot._start_round(owner,bot_class,now)
		bot.set_block_signals(false)
	revision += 1
	_last_change = now
	_unlock_at = now + TRANSITION_MSEC
	return {"ok":true, "state":status()}

func tick(now: int = -1) -> bool:
	if now < 0: now = Time.get_ticks_msec()
	if _unlock_at == 0 or now < _unlock_at: return false
	_unlock_at = 0
	if bot.phase != "countdown":
		for id: int in bot.human_ids(): registry.set_round_locked(id,false)
	return true

func peer_joined() -> void:
	# Removing a solo bot releases its owner; retain the map transition lock.
	if _unlock_at > 0:
		for id: int in bot.human_ids(): registry.set_round_locked(id,true)

func peer_left(peer_id: int) -> void:
	_last_request.erase(peer_id)

func _free_cell(arena_id: String, occupied: Array[Vector2i]) -> Vector2i:
	for y in range(MovementRules.GRID_ROWS):
		for x in range(MovementRules.GRID_COLUMNS):
			var cell := Vector2i(x,y)
			if ArenaData.is_walkable(arena_id,cell) and not occupied.has(cell): return cell
	return Vector2i.ZERO

func _error(message: String) -> Dictionary:
	return {"ok":false,"message":message}
