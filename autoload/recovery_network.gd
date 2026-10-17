extends Node

signal action_requested(peer_id: int, action: String, request_id: int)
signal action_resolved(event: Dictionary)
signal action_rejected(message: String)
var _next_request := 0


func request_action(action: String) -> void:
	if not SpellNetwork.server_available:
		action_rejected.emit("Actualizá y reiniciá el servidor para usar recuperación.")
		return
	var peer := multiplayer.multiplayer_peer
	if peer == null or multiplayer.is_server() or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_next_request += 1
	_request_action.rpc_id(NetworkConstants.SERVER_PEER_ID, action, _next_request)


func clear_session() -> void:
	_next_request = 0


func broadcast_result(event: Dictionary) -> void:
	if multiplayer.is_server() and multiplayer.get_peers().has(int(event.peer_id)):
		_receive_result.rpc_id(int(event.peer_id), event)


func send_rejection(peer_id: int, message: String) -> void:
	if multiplayer.is_server():
		_receive_rejection.rpc_id(peer_id, message)


@rpc("any_peer", "call_remote", "reliable")
func _request_action(action: String, request_id: int) -> void:
	if multiplayer.is_server():
		action_requested.emit(multiplayer.get_remote_sender_id(), action, request_id)


@rpc("authority", "call_remote", "reliable")
func _receive_result(event: Dictionary) -> void:
	action_resolved.emit(event)


@rpc("authority", "call_remote", "reliable")
func _receive_rejection(message: String) -> void:
	action_rejected.emit(message)
