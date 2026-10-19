extends Node

signal changed
signal completed(ok: bool, message: String)
signal command_requested(peer_id: int, operation: String, payload: Dictionary, request_id: int)
signal status_requested(peer_id: int)
var rooms: Array = []
var room: Dictionary = {}
var pending := false
var available := false
var _next_request := 0
var _pending_id := 0
var _generation := 0

func _ready() -> void:
	SpellNetwork.server_capabilities_received.connect(func(value: bool) -> void:
		available = value
		if value and _connected(): refresh()
		changed.emit()
	)
	NetworkManager.server_disconnected.connect(clear_session)
	NetworkManager.connection_failed.connect(clear_session)

func clear_session() -> void:
	_generation += 1
	pending = false
	available = false
	_pending_id = 0
	rooms.clear()
	room.clear()
	changed.emit()

func refresh() -> void:
	if available and _connected(): _request_status.rpc_id(NetworkConstants.SERVER_PEER_ID)

func command(operation: String, payload: Dictionary = {}) -> void:
	if pending or not available or not _connected(): return
	_next_request += 1
	_pending_id = _next_request
	pending = true
	var generation := _generation
	var request := _pending_id
	_command.rpc_id(NetworkConstants.SERVER_PEER_ID,operation,payload,request)
	changed.emit()
	await get_tree().create_timer(3.0).timeout
	if generation == _generation and pending and _pending_id == request:
		pending = false
		completed.emit(false,"El servidor no respondió. Revisá la conexión.")
		changed.emit()

func gameplay_active() -> bool:
	return str(room.get("phase","")) == "fighting"

func send_state(peer_id: int, listings: Array, own_room: Dictionary) -> void:
	if multiplayer.is_server(): _receive_state.rpc_id(peer_id,listings,own_room)

func send_result(peer_id: int, request: int, result: Dictionary) -> void:
	if multiplayer.is_server(): _receive_result.rpc_id(peer_id,request,bool(result.ok),str(result.get("message","")))

func _connected() -> bool:
	return not multiplayer.is_server() and multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

@rpc("any_peer","call_remote","reliable")
func _request_status() -> void:
	if multiplayer.is_server(): status_requested.emit(multiplayer.get_remote_sender_id())

@rpc("any_peer","call_remote","reliable")
func _command(operation: String, payload: Dictionary, request: int) -> void:
	if multiplayer.is_server(): command_requested.emit(multiplayer.get_remote_sender_id(),operation,payload,request)

@rpc("authority","call_remote","reliable")
func _receive_state(listings: Array, own_room: Dictionary) -> void:
	rooms = listings.duplicate(true)
	room = own_room.duplicate(true)
	changed.emit()

@rpc("authority","call_remote","reliable")
func _receive_result(request: int, ok: bool, message: String) -> void:
	if not pending or request != _pending_id: return
	pending = false
	completed.emit(ok,message)
	changed.emit()
