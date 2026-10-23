extends Node

signal changed
signal completed(ok: bool, message: String)
signal command_requested(peer_id: int, operation: String, payload: Dictionary, request_id: int)
signal status_requested(peer_id: int)
signal pause_requested(peer_id: int, value: bool, request_id: int)
signal pause_completed(ok: bool, message: String)
var rooms: Array = []
var room: Dictionary = {}
var pending := false
var available := false
var _next_request := 0
var _pending_id := 0
var _generation := 0
var _last_command_sent := -180
var pause_pending := false
var _pause_request := 0
var _pause_desired := false

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
	pause_pending = false
	_pause_desired = false
	available = false
	_pending_id = 0
	_last_command_sent = -180
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
	# A fast Add Bot → Ready click must respect the server's 150 ms edit gate
	# without dropping the user's valid next action. Pending disables duplicates.
	var wait_msec := maxi(0,_last_command_sent + 180 - Time.get_ticks_msec())
	changed.emit()
	if wait_msec > 0:
		await get_tree().create_timer(wait_msec / 1000.0).timeout
	if generation != _generation or request != _pending_id or not pending: return
	if not _connected():
		pending = false
		changed.emit()
		return
	_last_command_sent = Time.get_ticks_msec()
	_command.rpc_id(NetworkConstants.SERVER_PEER_ID,operation,payload,request)
	changed.emit()
	await get_tree().create_timer(3.0).timeout
	if generation == _generation and pending and _pending_id == request:
		pending = false
		completed.emit(false,"El servidor no respondió. Revisá la conexión.")
		changed.emit()

func can_pause() -> bool:
	return bool(room.get("can_pause",false))

func is_paused() -> bool:
	return bool(room.get("paused",false))

func request_pause(value: bool) -> void:
	if not available or not _connected() or (not can_pause() and not is_paused()): return
	if pause_pending and _pause_desired == value: return
	if not pause_pending and is_paused() == value: return
	_pause_desired = value
	pause_pending = true
	_send_pause(value,0)

func _send_pause(value: bool, attempt: int) -> void:
	_pause_request += 1
	var request := _pause_request
	var generation := _generation
	_set_pause.rpc_id(NetworkConstants.SERVER_PEER_ID,value,request)
	changed.emit()
	await get_tree().create_timer(3.0).timeout
	if generation != _generation or not pause_pending or request != _pause_request: return
	if attempt < 2:
		_send_pause(value,attempt+1)
	else:
		pause_pending = false
		pause_completed.emit(false,"No se pudo confirmar la pausa. Revisá la conexión.")
		refresh()
		changed.emit()

func gameplay_active() -> bool:
	return str(room.get("phase","")) == "fighting" and not is_paused() and not pause_pending

func send_pause_result(peer_id: int, request: int, result: Dictionary) -> void:
	if multiplayer.is_server(): _receive_pause_result.rpc_id(peer_id,request,bool(result.ok),str(result.get("message","")))

@rpc("any_peer","call_remote","reliable")
func _set_pause(value: bool, request: int) -> void:
	if multiplayer.is_server(): pause_requested.emit(multiplayer.get_remote_sender_id(),value,request)

@rpc("authority","call_remote","reliable")
func _receive_pause_result(request: int, ok: bool, message: String) -> void:
	if not pause_pending or request != _pause_request: return
	pause_pending = false
	pause_completed.emit(ok,message)
	changed.emit()

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
	if int(room.get("id",0)) != int(own_room.get("id",0)):
		pause_pending = false
		_pause_desired = false
		_pause_request += 1 # Invalidate any timeout/ack belonging to the previous room.
	rooms = listings.duplicate(true)
	room = own_room.duplicate(true)
	changed.emit()

@rpc("authority","call_remote","reliable")
func _receive_result(request: int, ok: bool, message: String) -> void:
	if not pending or request != _pending_id: return
	pending = false
	completed.emit(ok,message)
	changed.emit()
