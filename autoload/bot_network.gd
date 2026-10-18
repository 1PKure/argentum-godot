extends Node

signal status_requested(peer_id: int)
signal command_requested(peer_id: int, enabled: bool, class_id: int, request_id: int)
signal changed
signal completed(ok: bool, message: String)
var state: Dictionary = {"enabled": false, "phase": "idle", "human_count": 0, "owner_id": 0, "class_id": 3}
var pending := false
var _next_request := 0
var _pending_id := 0
var _generation := 0

func _ready() -> void:
	SpellNetwork.server_capabilities_received.connect(func(available: bool) -> void:
		if available:
			_request_status.rpc_id(NetworkConstants.SERVER_PEER_ID)
	)
	NetworkManager.server_disconnected.connect(clear_session)
	NetworkManager.connection_failed.connect(clear_session)

func clear_session() -> void:
	_generation += 1
	pending = false
	_pending_id = 0
	state = {"enabled": false, "phase": "idle", "human_count": 0, "owner_id": 0, "class_id": 3}
	changed.emit()

func request_bot(enabled: bool, class_id: int) -> void:
	if pending or not SpellNetwork.server_available or not _connected():
		return
	_next_request += 1
	_pending_id = _next_request
	pending = true
	var generation := _generation
	var request_id := _pending_id
	_send_command.rpc_id(NetworkConstants.SERVER_PEER_ID, enabled, class_id, _pending_id)
	changed.emit()
	await get_tree().create_timer(3.0).timeout
	if generation == _generation and pending and _pending_id == request_id:
		pending = false
		completed.emit(false, "El servidor no respondió. Revisá la conexión.")
		changed.emit()

func send_status(peer_id: int, value: Dictionary) -> void:
	if multiplayer.is_server():
		_receive_status.rpc_id(peer_id, value)

func send_result(peer_id: int, request_id: int, result: Dictionary) -> void:
	if multiplayer.is_server():
		_receive_result.rpc_id(peer_id, request_id, bool(result.ok), str(result.get("message", "")))

func _connected() -> bool:
	return not multiplayer.is_server() and multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

@rpc("any_peer", "call_remote", "reliable")
func _request_status() -> void:
	if multiplayer.is_server():
		status_requested.emit(multiplayer.get_remote_sender_id())

@rpc("any_peer", "call_remote", "reliable")
func _send_command(enabled: bool, class_id: int, request_id: int) -> void:
	if multiplayer.is_server():
		command_requested.emit(multiplayer.get_remote_sender_id(), enabled, class_id, request_id)

@rpc("authority", "call_remote", "reliable")
func _receive_status(value: Dictionary) -> void:
	state = value.duplicate(true)
	if str(state.get("phase", "")) == "won" and int(state.get("owner_id", 0)) == multiplayer.get_unique_id():
		Skins.accept_victory(str(state.get("round_id", "")))
	changed.emit()

@rpc("authority", "call_remote", "reliable")
func _receive_result(request_id: int, ok: bool, message: String) -> void:
	if request_id != _pending_id:
		return
	pending = false
	completed.emit(ok, message)
	changed.emit()
