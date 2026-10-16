extends Node

signal move_requested(peer_id: int, source: int, destination: int, item_id: int, revision: int, request_id: int)
signal use_requested(peer_id: int, slot: int, item_id: int, revision: int, request_id: int)
signal rejected(message: String)
var _next_request := 0


func request_move(source: int, destination: int, item_id: int, revision: int) -> void:
	if not SpellNetwork.server_available or not SpellNetwork._can_send():
		return
	_next_request += 1
	_move.rpc_id(1, source, destination, item_id, revision, _next_request)


func request_use(slot: int, item_id: int, revision: int) -> void:
	if not SpellNetwork.server_available or not SpellNetwork._can_send():
		return
	_next_request += 1
	_use.rpc_id(1, slot, item_id, revision, _next_request)


func send_rejection(peer_id: int, message: String) -> void:
	if multiplayer.is_server():
		_rejected.rpc_id(peer_id, message)


@rpc("any_peer", "call_remote", "reliable")
func _move(source: int, destination: int, item_id: int, revision: int, request_id: int) -> void:
	if multiplayer.is_server():
		move_requested.emit(multiplayer.get_remote_sender_id(), source, destination, item_id, revision, request_id)


@rpc("any_peer", "call_remote", "reliable")
func _use(slot: int, item_id: int, revision: int, request_id: int) -> void:
	if multiplayer.is_server():
		use_requested.emit(multiplayer.get_remote_sender_id(), slot, item_id, revision, request_id)


@rpc("authority", "call_remote", "reliable")
func _rejected(message: String) -> void:
	rejected.emit(message)
