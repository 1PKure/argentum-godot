extends Node

signal server_started
signal server_stopped
signal connected_to_server
signal connection_failed
signal server_disconnected
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)

const CONNECTION_RETRY_DELAY := 0.5
const MAX_CONNECTION_ATTEMPTS := 20

var peer: WebSocketMultiplayerPeer

var _connection_attempts := 0
var _is_connecting := false
var _client_url := NetworkConstants.LOCAL_WEBSOCKET_URL


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_attempt_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func start_server(
	port: int = NetworkConstants.DEFAULT_PORT,
	bind_address: String = "*"
) -> Error:
	stop()

	peer = WebSocketMultiplayerPeer.new()

	var error: Error = peer.create_server(
		port,
		bind_address
	)

	if error != OK:
		push_error(
			"Failed to start WebSocket server. Error: %s"
			% error
		)

		peer = null
		return error

	multiplayer.multiplayer_peer = peer

	print(
		"WebSocket server started on port %d."
		% port
	)

	server_started.emit()

	return OK


func start_client(
	url: String = NetworkConstants.LOCAL_WEBSOCKET_URL
) -> Error:
	if is_network_connected():
		return OK

	if _is_connecting:
		return OK

	_client_url = url
	_connection_attempts = 0
	_is_connecting = true

	return _start_connection_attempt()


func stop() -> void:
	var was_server := (
		peer != null
		and multiplayer.multiplayer_peer == peer
		and multiplayer.is_server()
	)

	_is_connecting = false
	_connection_attempts = 0

	if peer != null:
		peer.close()
		peer = null

	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	if was_server:
		server_stopped.emit()


func is_server() -> bool:
	return (
		peer != null
		and multiplayer.multiplayer_peer == peer
		and multiplayer.is_server()
	)


func is_network_connected() -> bool:
	if peer == null:
		return false

	if multiplayer.multiplayer_peer != peer:
		return false

	return (
		peer.get_connection_status()
		== MultiplayerPeer.CONNECTION_CONNECTED
	)


func get_peer_id() -> int:
	return multiplayer.get_unique_id()


func _start_connection_attempt() -> Error:
	if not _is_connecting:
		return ERR_UNCONFIGURED

	_connection_attempts += 1

	print(
		"Connecting to WebSocket server at %s... Attempt %d/%d"
		% [
			_client_url,
			_connection_attempts,
			MAX_CONNECTION_ATTEMPTS
		]
	)

	if peer != null:
		peer.close()
		peer = null

	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	peer = WebSocketMultiplayerPeer.new()

	var error: Error = peer.create_client(_client_url)

	if error != OK:
		push_error(
			"Failed to create WebSocket client. Error: %s"
			% error
		)

		peer = null

		_schedule_retry()

		return error

	multiplayer.multiplayer_peer = peer

	return OK


func _schedule_retry() -> void:
	if not _is_connecting:
		return

	if _connection_attempts >= MAX_CONNECTION_ATTEMPTS:
		_finish_connection_failure()
		return

	await get_tree().create_timer(
		CONNECTION_RETRY_DELAY
	).timeout

	if not _is_connecting:
		return

	_start_connection_attempt()


func _finish_connection_failure() -> void:
	if not _is_connecting:
		return

	_is_connecting = false

	push_error(
		"Could not connect to WebSocket server after %d attempts."
		% MAX_CONNECTION_ATTEMPTS
	)

	if peer != null:
		peer.close()
		peer = null

	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	connection_failed.emit()


func _on_peer_connected(peer_id: int) -> void:
	print("Peer connected: %d" % peer_id)

	peer_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	print("Peer disconnected: %d" % peer_id)

	peer_disconnected.emit(peer_id)


func _on_connected_to_server() -> void:
	_is_connecting = false

	print(
		"Connected to WebSocket server. Local peer ID: %d"
		% multiplayer.get_unique_id()
	)

	connected_to_server.emit()


func _on_connection_attempt_failed() -> void:
	if not _is_connecting:
		return

	print(
		"WebSocket connection attempt %d/%d failed."
		% [
			_connection_attempts,
			MAX_CONNECTION_ATTEMPTS
		]
	)

	_schedule_retry()


func _on_server_disconnected() -> void:
	_is_connecting = false

	print("Disconnected from WebSocket server.")

	if peer != null:
		peer.close()
		peer = null

	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	server_disconnected.emit()
