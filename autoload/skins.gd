extends Node

signal changed
signal victory_awarded(result: Dictionary)
signal skin_requested(peer_id: int, class_id: int, skin_id: String, local_wins: int)
var progress := SkinProgress.new()
var _has_player_state := false

func _ready() -> void:
	progress.restore()
	PlayerNetwork.snapshot_received.connect(func(players: Array) -> void:
		for data: Dictionary in players:
			_apply_player_class(data)
	)
	PlayerNetwork.player_stats_updated.connect(_apply_player_class)
	NetworkManager.server_disconnected.connect(func() -> void: _has_player_state = false)
	NetworkManager.connection_failed.connect(func() -> void: _has_player_state = false)
	SpellNetwork.server_capabilities_received.connect(func(available: bool) -> void:
		if available and _connected():
			_sync_selection()
	)

func select_skin(id: String) -> void:
	if progress.select(id):
		changed.emit()
		_sync_selection()

func accept_victory(round_id: String, class_id: int) -> void:
	var result := progress.award(round_id, class_id)
	if not result.is_empty():
		changed.emit()
		victory_awarded.emit(result)

func _sync_selection() -> void:
	if _has_player_state and _connected() and SpellNetwork.server_available:
		_select_skin.rpc_id(NetworkConstants.SERVER_PEER_ID, progress.class_id, progress.selected, progress.wins)

func _apply_player_class(data: Dictionary) -> void:
	if not _connected() or int(data.get("peer_id", 0)) != multiplayer.get_unique_id():
		return
	var first := not _has_player_state
	_has_player_state = true
	if progress.set_class(int(data.get("class_id", ClassCatalog.DEFAULT_CLASS))) or first:
		changed.emit()
		_sync_selection()

func _connected() -> bool:
	return not multiplayer.is_server() and multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

@rpc("any_peer", "call_remote", "reliable")
func _select_skin(class_id: int, id: String, local_wins: int) -> void:
	if multiplayer.is_server():
		skin_requested.emit(multiplayer.get_remote_sender_id(), class_id, id, local_wins)
