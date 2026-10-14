extends Node

signal snapshot_received(players: Array)
signal player_spawned(player_data: Dictionary)
signal player_despawned(peer_id: int)
signal player_moved(player_data: Dictionary)
signal player_stats_updated(player_data: Dictionary)
signal spell_cast(event: Dictionary)
signal spell_result_received(request_id: int, success: bool, reason: String, retry_after_msec: int)
signal spell_requested(peer_id: int, spell_id: int, target_id: int, request_id: int)


func request_spell(spell_id: int, target_id: int, request_id: int) -> void:
	if multiplayer.is_server() or not _can_send_to_server():
		return
	_request_spell.rpc_id(NetworkConstants.SERVER_PEER_ID, spell_id, target_id, request_id)


func send_spell_result(peer_id: int, request_id: int, result: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	_receive_spell_result.rpc_id(peer_id, request_id, bool(result["success"]), str(result["reason"]), int(result["retry_after_msec"]))


func broadcast_spell(event: Dictionary) -> void:
	if multiplayer.is_server():
		_receive_spell.rpc(event)


@rpc("any_peer", "call_remote", "reliable")
func _request_spell(spell_id: int, target_id: int, request_id: int) -> void:
	if multiplayer.is_server():
		# The actor identity comes from the transport, never from client input.
		spell_requested.emit(multiplayer.get_remote_sender_id(), spell_id, target_id, request_id)


@rpc("authority", "call_remote", "reliable")
func _receive_spell_result(request_id: int, success: bool, reason: String, retry_after_msec: int) -> void:
	spell_result_received.emit(request_id, success, reason, retry_after_msec)


@rpc("authority", "call_remote", "reliable")
func _receive_spell(event: Dictionary) -> void:
	spell_cast.emit(event)

signal move_requested(
	peer_id: int,
	direction: int
)

signal basic_attack_requested(
	peer_id: int
)

signal debug_damage_requested(
	peer_id: int
)

signal debug_mana_spend_requested(
	peer_id: int
)


func request_move(direction: int) -> void:
	if multiplayer.is_server():
		return

	if not _can_send_to_server():
		return

	_request_move.rpc_id(
		NetworkConstants.SERVER_PEER_ID,
		direction
	)


func request_basic_attack() -> void:
	if multiplayer.is_server():
		return

	if not _can_send_to_server():
		return

	_request_basic_attack.rpc_id(
		NetworkConstants.SERVER_PEER_ID
	)


func request_debug_damage() -> void:
	if multiplayer.is_server():
		return

	if not _can_send_to_server():
		return

	_request_debug_damage.rpc_id(
		NetworkConstants.SERVER_PEER_ID
	)


func request_debug_mana_spend() -> void:
	if multiplayer.is_server():
		return

	if not _can_send_to_server():
		return

	_request_debug_mana_spend.rpc_id(
		NetworkConstants.SERVER_PEER_ID
	)


func send_snapshot_to(
	peer_id: int,
	players: Array
) -> void:
	if not multiplayer.is_server():
		push_error(
			"Only the server can send player snapshots."
		)
		return

	_receive_snapshot.rpc_id(
		peer_id,
		players
	)


func send_player_spawned_to(
	peer_id: int,
	player_data: Dictionary
) -> void:
	if not multiplayer.is_server():
		push_error(
			"Only the server can send player spawn events."
		)
		return

	_receive_player_spawned.rpc_id(
		peer_id,
		player_data
	)


func send_player_despawned_to(
	peer_id: int,
	disconnected_peer_id: int
) -> void:
	if not multiplayer.is_server():
		push_error(
			"Only the server can send player despawn events."
		)
		return

	_receive_player_despawned.rpc_id(
		peer_id,
		disconnected_peer_id
	)


func broadcast_player_moved(
	player_data: Dictionary
) -> void:
	if not multiplayer.is_server():
		push_error(
			"Only the server can broadcast player movement."
		)
		return

	_receive_player_moved.rpc(
		player_data
	)


func broadcast_player_stats_updated(
	player_data: Dictionary
) -> void:
	if not multiplayer.is_server():
		push_error(
			"Only the server can broadcast player stats."
		)
		return

	_receive_player_stats_updated.rpc(
		player_data
	)


func _can_send_to_server() -> bool:
	var peer := multiplayer.multiplayer_peer

	if peer == null:
		return false

	return (
		peer.get_connection_status()
		== MultiplayerPeer.CONNECTION_CONNECTED
	)


@rpc("any_peer", "call_remote", "reliable")
func _request_move(
	direction: int
) -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id: int = (
		multiplayer.get_remote_sender_id()
	)

	move_requested.emit(
		sender_peer_id,
		direction
	)


@rpc("any_peer", "call_remote", "reliable")
func _request_basic_attack() -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id: int = (
		multiplayer.get_remote_sender_id()
	)

	basic_attack_requested.emit(
		sender_peer_id
	)


@rpc("any_peer", "call_remote", "reliable")
func _request_debug_damage() -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id: int = (
		multiplayer.get_remote_sender_id()
	)

	debug_damage_requested.emit(
		sender_peer_id
	)


@rpc("any_peer", "call_remote", "reliable")
func _request_debug_mana_spend() -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id: int = (
		multiplayer.get_remote_sender_id()
	)

	debug_mana_spend_requested.emit(
		sender_peer_id
	)


@rpc("authority", "call_remote", "reliable")
func _receive_snapshot(
	players: Array
) -> void:
	snapshot_received.emit(
		players
	)


@rpc("authority", "call_remote", "reliable")
func _receive_player_spawned(
	player_data: Dictionary
) -> void:
	player_spawned.emit(
		player_data
	)


@rpc("authority", "call_remote", "reliable")
func _receive_player_despawned(
	peer_id: int
) -> void:
	player_despawned.emit(
		peer_id
	)


@rpc("authority", "call_remote", "reliable")
func _receive_player_moved(
	player_data: Dictionary
) -> void:
	player_moved.emit(
		player_data
	)


@rpc("authority", "call_remote", "reliable")
func _receive_player_stats_updated(
	player_data: Dictionary
) -> void:
	player_stats_updated.emit(
		player_data
	)
