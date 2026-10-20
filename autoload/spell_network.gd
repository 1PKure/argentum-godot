extends Node

signal shot_requested(peer_id: int, target: Vector2i, request_id: int)
signal cast_requested(peer_id: int, spell_id: int, target: Vector2i, request_id: int)
signal spell_resolved(event: Dictionary)
signal spell_rejected(request_id: int, message: String, remaining_msec: int)
signal server_capabilities_received(available: bool)

const PROTOCOL_VERSION := 21
var server_available := false
var _query_generation := 0


func query_server() -> void:
	_query_generation += 1
	var generation := _query_generation
	server_available = false
	if not _can_send():
		return
	_request_capabilities.rpc_id(NetworkConstants.SERVER_PEER_ID, PROTOCOL_VERSION)
	await get_tree().create_timer(3.0).timeout
	if generation == _query_generation and not server_available:
		server_capabilities_received.emit(false)


func clear_session() -> void:
	_query_generation += 1
	server_available = false


func request_cast(spell_id: int, target: Vector2i, request_id: int) -> bool:
	if not server_available or not _can_send():
		return false
	_request_cast.rpc_id(NetworkConstants.SERVER_PEER_ID, spell_id, target.x, target.y, request_id)
	return true


func send_rejection(peer_id: int, request_id: int, message: String, remaining_msec: int = 0) -> void:
	if multiplayer.is_server():
		_receive_rejection.rpc_id(peer_id, request_id, message, remaining_msec)


func broadcast_result(event: Dictionary, recipients: Array = []) -> void:
	if multiplayer.is_server():
		for recipient: int in (multiplayer.get_peers() if recipients.is_empty() else recipients):
			var visible := event.duplicate(true)
			if recipient != int(event.get("caster_id", 0)):
				visible.erase("mana_cost")
			_receive_result.rpc_id(recipient, visible)


func _can_send() -> bool:
	var peer := multiplayer.multiplayer_peer
	return not multiplayer.is_server() and peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


@rpc("any_peer", "call_remote", "reliable")
func _request_capabilities(version: int) -> void:
	if multiplayer.is_server():
		_receive_capabilities.rpc_id(multiplayer.get_remote_sender_id(), version == PROTOCOL_VERSION)


@rpc("authority", "call_remote", "reliable")
func _receive_capabilities(available: bool) -> void:
	server_available = available
	_query_generation += 1
	server_capabilities_received.emit(available)


@rpc("any_peer", "call_remote", "reliable")
func _request_cast(spell_id: int, target_x: int, target_y: int, request_id: int) -> void:
	if multiplayer.is_server():
		cast_requested.emit(multiplayer.get_remote_sender_id(), spell_id, Vector2i(target_x, target_y), request_id)


@rpc("authority", "call_remote", "reliable")
func _receive_rejection(request_id: int, message: String, remaining_msec: int) -> void:
	spell_rejected.emit(request_id, message, remaining_msec)


@rpc("authority", "call_remote", "reliable")
func _receive_result(event: Dictionary) -> void:
	spell_resolved.emit(event)


func request_shot(target: Vector2i, request_id: int) -> bool:
	if not server_available or not _can_send():
		return false
	_request_shot.rpc_id(NetworkConstants.SERVER_PEER_ID, target.x, target.y, request_id)
	return true


@rpc("any_peer", "call_remote", "reliable")
func _request_shot(target_x: int, target_y: int, request_id: int) -> void:
	if multiplayer.is_server():
		shot_requested.emit(multiplayer.get_remote_sender_id(), Vector2i(target_x, target_y), request_id)
