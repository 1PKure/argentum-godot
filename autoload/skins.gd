extends Node

signal changed
signal victory_awarded(result: Dictionary)
signal skin_requested(peer_id: int, skin_id: String, local_wins: int)
var progress := SkinProgress.new()

func _ready() -> void:
	progress.restore()
	SpellNetwork.server_capabilities_received.connect(func(available: bool) -> void:
		if available and _connected():
			_sync_selection()
	)

func select_skin(id: String) -> void:
	if progress.select(id):
		changed.emit()
		_sync_selection()

func accept_victory(round_id: String) -> void:
	var result := progress.award(round_id)
	if not result.is_empty():
		changed.emit()
		victory_awarded.emit(result)

func _sync_selection() -> void:
	if _connected() and SpellNetwork.server_available:
		_select_skin.rpc_id(NetworkConstants.SERVER_PEER_ID, progress.selected, progress.wins)

func _connected() -> bool:
	return not multiplayer.is_server() and multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

@rpc("any_peer", "call_remote", "reliable")
func _select_skin(id: String, local_wins: int) -> void:
	if multiplayer.is_server():
		skin_requested.emit(multiplayer.get_remote_sender_id(), id, local_wins)
