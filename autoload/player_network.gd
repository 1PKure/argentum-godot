extends Node

signal basic_attack_resolved(event: Dictionary)
signal snapshot_received(players: Array)
signal player_spawned(player_data: Dictionary)
signal player_despawned(peer_id: int)
signal player_moved(player_data: Dictionary)
signal player_stats_updated(player_data: Dictionary)

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

	var visible: Array = []
	for data: Dictionary in players:
		visible.append(for_recipient(data, peer_id))
	_receive_snapshot.rpc_id(peer_id, visible)


func send_player_spawned_to(
	peer_id: int,
	player_data: Dictionary
) -> void:
	if not multiplayer.is_server():
		push_error(
			"Only the server can send player spawn events."
		)
		return

	_receive_player_spawned.rpc_id(peer_id, for_recipient(player_data, peer_id))


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

	for recipient: int in multiplayer.get_peers():
		_receive_player_moved.rpc_id(recipient, for_recipient(player_data, recipient))


func broadcast_player_stats_updated(
	player_data: Dictionary
) -> void:
	if not multiplayer.is_server():
		push_error(
			"Only the server can broadcast player stats."
		)
		return

	for recipient: int in multiplayer.get_peers():
		_receive_player_stats_updated.rpc_id(recipient, for_recipient(player_data, recipient))


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


# Actual enemy mana is absent in snapshots, movement and stat RPCs.
func for_recipient(data: Dictionary, recipient: int) -> Dictionary:
	var visible := data.duplicate(true)
	if int(data.get("peer_id", 0)) != recipient:
		visible.erase("current_mana")
		visible["mana_is_private"] = true
	return visible


func send_basic_attack_result(event: Dictionary) -> void:
	if multiplayer.is_server():
		for recipient: int in [int(event.caster_id), int(event.target_id)]:
			_receive_basic_attack_result.rpc_id(recipient, event)


@rpc("authority", "call_remote", "reliable")
func _receive_basic_attack_result(event: Dictionary) -> void:
	basic_attack_resolved.emit(event)
