extends Node

signal changed
signal selection_requested(peer_id: int, arena_id: String, revision: int, request_id: int)
signal status_requested(peer_id: int)
signal completed(ok: bool, message: String)
var state: Dictionary = {}
var pending := false
var _next_request := 0
var _pending_id := 0
var _generation := 0

func _ready() -> void:
	SpellNetwork.server_capabilities_received.connect(func(available: bool) -> void:
		if available and _connected(): _request_status.rpc_id(NetworkConstants.SERVER_PEER_ID)
	)
	NetworkManager.server_disconnected.connect(clear_session)
	NetworkManager.connection_failed.connect(clear_session)

func clear_session() -> void:
	_generation += 1
	state.clear()
	pending = false
	_pending_id = 0
	changed.emit()

func select_arena(id: String) -> void:
	if pending or state.is_empty() or not SpellNetwork.server_available or not _connected(): return
	_next_request += 1
	_pending_id = _next_request
	pending = true
	var generation := _generation
	var request := _pending_id
	_select_arena.rpc_id(NetworkConstants.SERVER_PEER_ID,id,int(state.revision),request)
	changed.emit()
	await get_tree().create_timer(3).timeout
	if generation == _generation and pending and _pending_id == request:
		pending = false
		completed.emit(false,"El servidor no respondió. Revisá la conexión.")
		changed.emit()

func send_state(peer_id: int, value: Dictionary) -> void:
	if multiplayer.is_server(): _receive_state.rpc_id(peer_id,value)

func send_result(peer_id: int, request: int, result: Dictionary) -> void:
	if multiplayer.is_server(): _receive_result.rpc_id(peer_id,request,bool(result.ok),str(result.get("message","")))

func _connected() -> bool:
	return not multiplayer.is_server() and multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

@rpc("any_peer","call_remote","reliable")
func _request_status() -> void:
	if multiplayer.is_server(): status_requested.emit(multiplayer.get_remote_sender_id())

@rpc("any_peer","call_remote","reliable")
func _select_arena(id: String, revision: int, request: int) -> void:
	if multiplayer.is_server(): selection_requested.emit(multiplayer.get_remote_sender_id(),id,revision,request)

@rpc("authority","call_remote","reliable")
func _receive_state(value: Dictionary) -> void:
	state = value.duplicate(true)
	changed.emit()

@rpc("authority","call_remote","reliable")
func _receive_result(request: int, ok: bool, message: String) -> void:
	if not pending or request != _pending_id: return
	pending = false
	completed.emit(ok,message)
	changed.emit()
