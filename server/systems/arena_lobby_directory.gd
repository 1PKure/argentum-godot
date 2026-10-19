class_name ArenaLobbyDirectory
extends RefCounted

const MAX_ROOMS := 32
const MAX_CONNECTED := 64
var rooms: Dictionary = {}
var membership: Dictionary = {}
var _next_id := 1
var _last_request: Dictionary = {}
var _last_command: Dictionary = {}
var _last_pause_request: Dictionary = {}

# Separate from rate-limited lobby edits: opening then closing a modal must resume immediately.
func pause(peer_id: int, value: bool, request: int, now: int = -1) -> Dictionary:
	if request <= int(_last_pause_request.get(peer_id,0)): return ArenaLobbyRoom.error("La solicitud ya fue procesada.")
	_last_pause_request[peer_id] = request
	var room := room_for(peer_id)
	if room == null: return ArenaLobbyRoom.error("Entrá primero a una sala.")
	return room.set_paused(peer_id,value,now)

func room_for(peer_id: int) -> ArenaLobbyRoom:
	return rooms.get(int(membership.get(peer_id,0)))

func listings() -> Array:
	var result: Array = []
	for room: ArenaLobbyRoom in rooms.values(): result.append(room.listing())
	return result

func command(peer_id: int, operation: String, payload: Dictionary, request_id: int, now: int = -1) -> Dictionary:
	if now < 0: now = Time.get_ticks_msec()
	if request_id <= int(_last_request.get(peer_id,0)): return ArenaLobbyRoom.error("La solicitud ya fue procesada.")
	_last_request[peer_id] = request_id
	if now - int(_last_command.get(peer_id,-150)) < 150: return ArenaLobbyRoom.error("Esperá un instante antes de cambiar la sala.")
	_last_command[peer_id] = now
	var room := room_for(peer_id)
	match operation:
		"create":
			if room != null: return ArenaLobbyRoom.error("Salí de tu sala antes de crear otra.")
			if rooms.size() >= MAX_ROOMS: return ArenaLobbyRoom.error("No hay lugar para más salas en este servidor.")
			var arena_id := str(payload.get("arena_id",""))
			if not ArenaData.is_implemented(arena_id): return ArenaLobbyRoom.error("Arena desconocida.")
			var title := str(payload.get("title","")).strip_edges().substr(0,28)
			for character in ["\n","\r","\t"]: title = title.replace(character," ")
			if title.is_empty(): title = "Sala %d" % _next_id
			room = ArenaLobbyRoom.new(_next_id,title,arena_id)
			rooms[_next_id] = room
			_next_id += 1
			_join(room,peer_id)
		"join":
			if room != null: return ArenaLobbyRoom.error("Ya estás dentro de una sala.")
			room = rooms.get(int(payload.get("room_id",0)))
			if room == null: return ArenaLobbyRoom.error("Esa sala ya no existe.")
			if room.members.size() >= 2: return ArenaLobbyRoom.error("La sala está llena.")
			if room.phase in ["countdown","fighting"]: return ArenaLobbyRoom.error("La ronda ya comenzó.")
			_join(room,peer_id)
		"leave":
			leave(peer_id)
		"ready":
			if room == null: return ArenaLobbyRoom.error("Entrá primero a una sala.")
			return room.set_ready(peer_id,bool(payload.get("ready",false)),int(payload.get("revision",-1)),now)
		"bot":
			if room == null or room.members[0] != peer_id: return ArenaLobbyRoom.error("Sólo el anfitrión puede configurar el bot.")
			if room.phase not in ["waiting","result"]: return ArenaLobbyRoom.error("La ronda ya comenzó.")
			if room.members.size() != 1: return ArenaLobbyRoom.error("El bot sólo está disponible si estás solo.")
			var class_id := int(payload.get("class_id",ClassCatalog.DEFAULT_CLASS))
			if ClassCatalog.get_profile(class_id).is_empty(): return ArenaLobbyRoom.error("Clase desconocida.")
			room.bot.remove_bot(false)
			room.bot_enabled = bool(payload.get("enabled",false))
			room.bot_class = class_id
			room.invalidate_ready()
		_:
			return ArenaLobbyRoom.error("Acción de sala desconocida.")
	return {"ok":true}

func _join(room: ArenaLobbyRoom, peer_id: int) -> void:
	membership[peer_id] = room.id
	room.add_member(peer_id)

func leave(peer_id: int) -> void:
	var room := room_for(peer_id)
	if room == null: return
	membership.erase(peer_id)
	room.remove_member(peer_id)
	if room.members.is_empty():
		rooms.erase(room.id)
		room.dispose()

func disconnect_peer(peer_id: int) -> void:
	leave(peer_id)
	_last_request.erase(peer_id)
	_last_command.erase(peer_id)
	_last_pause_request.erase(peer_id)

func dispose() -> void:
	for room: ArenaLobbyRoom in rooms.values(): room.dispose()
	rooms.clear()
	membership.clear()
