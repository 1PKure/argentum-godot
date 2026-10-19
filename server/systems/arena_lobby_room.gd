class_name ArenaLobbyRoom
extends RefCounted

const COUNTDOWN_MSEC := 3000
var id: int
var title: String
var registry := PlayerRegistry.new()
var bot: ArenaPracticeBot
var arena: ArenaSession
var members: Array[int] = []
var ready: Dictionary = {}
var phase := "waiting"
var revision := 0
var round_id := ""
var winner_id := 0
var result_text := ""
var bot_enabled := false
var bot_class := ClassCatalog.DEFAULT_CLASS
var starts_at := 0
var countdown := 0
var paused := false
var _pause_started := 0
var _paused_total := 0

# All gameplay timestamps live on this room clock, including new round resets.
func game_time(wall_time: int = -1) -> int:
	if wall_time < 0: wall_time = Time.get_ticks_msec()
	return (_pause_started if paused else wall_time) - _paused_total

func can_pause(peer_id: int) -> bool:
	return members.size() == 1 and members[0] == peer_id and bot_enabled and phase in ["countdown", "fighting"]

func set_paused(peer_id: int, value: bool, wall_time: int = -1) -> Dictionary:
	if not can_pause(peer_id): return error("Sólo se puede pausar una partida individual contra el bot.")
	if wall_time < 0: wall_time = Time.get_ticks_msec()
	if paused == value: return {"ok":true}
	if value:
		_pause_started = wall_time
		paused = true
	else:
		_paused_total += maxi(0, wall_time - _pause_started)
		paused = false
	revision += 1
	return {"ok":true}

func _clear_pause() -> void:
	if paused:
		_paused_total += maxi(0, Time.get_ticks_msec() - _pause_started)
	paused = false

func _init(room_id: int, room_title: String, arena_id: String) -> void:
	id = room_id
	title = room_title
	registry.set_arena(arena_id)
	bot = ArenaPracticeBot.new(registry)
	arena = ArenaSession.new(registry,bot)

func dispose() -> void:
	registry.free()

func add_member(peer_id: int) -> void:
	bot.remove_bot(false)
	bot_enabled = false
	members.append(peer_id)
	registry.add_player(peer_id)
	invalidate_ready()

func remove_member(peer_id: int) -> void:
	var interrupted := phase in ["countdown","fighting"]
	bot.peer_left(peer_id)
	bot.remove_bot(false)
	registry.remove_player(peer_id)
	members.erase(peer_id)
	ready.erase(peer_id)
	bot_enabled = false
	invalidate_ready()
	if interrupted and not members.is_empty():
		phase = "result"
		result_text = "El rival salió de la sala."
		winner_id = 0 # A disconnect never grants a bot skin reward or a competitive win.

func invalidate_ready() -> void:
	_clear_pause()
	ready.clear()
	phase = "waiting"
	winner_id = 0
	result_text = ""
	starts_at = 0
	countdown = 0
	for peer_id: int in members:
		registry.set_round_locked(peer_id,true)
	revision += 1

func state() -> Dictionary:
	var players: Array = []
	for peer_id: int in members:
		var player := registry.get_player(peer_id)
		players.append({"peer_id":peer_id,"name":player.display_name,"class_id":player.class_id,"ready":bool(ready.get(peer_id,false))})
	return {"id":id,"title":title,"arena_id":registry.get_arena_id(),"owner_id":members[0] if not members.is_empty() else 0,
		"members":players,"phase":phase,"revision":revision,"bot_enabled":bot_enabled,"bot_class":bot_class,
		"paused":paused,"can_pause":members.size() == 1 and bot_enabled and phase in ["countdown","fighting"],
		"round_id":round_id,"countdown":countdown,"winner_id":winner_id,"result_text":result_text}

func listing() -> Dictionary:
	return {"id":id,"title":title,"arena_id":registry.get_arena_id(),"occupancy":members.size(),"capacity":2,"phase":phase,"bot_enabled":bot_enabled}

func set_ready(peer_id: int, value: bool, expected_revision: int, now: int = -1) -> Dictionary:
	if phase not in ["waiting","result"]: return error("La ronda ya comenzó.")
	if expected_revision != revision: return error("La sala cambió. Revisá el estado y volvé a marcar Listo.")
	if bool(arena.status().transitioning): return error("Esperá a que termine el cambio de arena.")
	if members.size() < 2 and not bot_enabled: return error("Esperá un rival o activá el bot.")
	ready[peer_id] = value
	if value and _all_ready(): start_round(game_time(now))
	return {"ok":true}

func _all_ready() -> bool:
	for peer_id: int in members:
		if not bool(ready.get(peer_id,false)): return false
	return members.size() == 2 or (members.size() == 1 and bot_enabled)

func start_round(now: int) -> void:
	winner_id = 0
	result_text = ""
	phase = "countdown"
	countdown = 3
	starts_at = now + COUNTDOWN_MSEC
	round_id = Crypto.new().generate_random_bytes(16).hex_encode()
	var spawns := ArenaData.get_spawn_points(registry.get_arena_id())
	for index in range(members.size()):
		var peer_id := members[index]
		var player := registry.get_player(peer_id)
		registry.try_select_class(peer_id,player.class_id,now)
		player.grid_position = spawns[index]
		player.facing_direction = MovementRules.Direction.EAST if index == 0 else MovementRules.Direction.WEST
		registry.set_round_locked(peer_id,true)
	if bot_enabled:
		bot._start_round(members[0],bot_class,now)
		round_id = bot.round_id
	revision += 1

func settle_round() -> bool:
	if phase != "fighting": return false
	if bot_enabled:
		bot.settle_round()
		if bot.phase not in ["won","lost"]: return false
		winner_id = members[0] if bot.phase == "won" else ArenaPracticeBot.BOT_ID
		result_text = "Victoria" if bot.phase == "won" else "Derrota"
	else:
		for peer_id: int in members:
			if not registry.get_player(peer_id).is_alive:
				for candidate: int in members:
					if candidate != peer_id: winner_id = candidate
				result_text = "Duelo terminado"
				break
		if winner_id == 0: return false
	phase = "result"
	ready.clear()
	for peer_id: int in registry.get_peer_ids(): registry.set_round_locked(peer_id,true)
	revision += 1
	return true

func tick(now: int = -1) -> Dictionary:
	if paused: return {"changed":false,"actions":[],"players":[]}
	now = game_time(now)
	var before := state()
	var actions: Array[Dictionary] = []
	var changed_players: Array = []
	if phase == "countdown":
		countdown = maxi(0,ceili((starts_at - now) / 1000.0))
		if now >= starts_at:
			phase = "fighting"
			for peer_id: int in registry.get_peer_ids(): registry.set_round_locked(peer_id,false)
	if phase in ["countdown","fighting"]:
		for player: PlayerState in registry.advance_runtime(now): changed_players.append(player.to_dictionary())
		if bot_enabled: actions = bot.tick(now)
		settle_round()
	# ArenaSession's transition lock must never release a waiting room's round lock.
	var arena_changed := arena.tick(now)
	if arena_changed and phase != "fighting":
		for peer_id: int in members: registry.set_round_locked(peer_id,true)
	return {"changed":arena_changed or before != state(),"actions":actions,"players":changed_players}

static func error(message: String) -> Dictionary:
	return {"ok":false,"message":message}
