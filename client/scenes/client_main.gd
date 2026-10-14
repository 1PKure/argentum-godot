extends Node


func _ready() -> void:
	print("Starting Argentum client...")

	NetworkManager.connected_to_server.connect(
		_on_connected_to_server
	)

	NetworkManager.connection_failed.connect(
		_on_connection_failed
	)

	NetworkManager.server_disconnected.connect(
		_on_server_disconnected
	)

	print("Client is waiting for server connection...")

	var error: Error = NetworkManager.start_client()

	if error != OK:
		push_error(
			"Client startup failed. Error: %s"
			% error
		)
		return

	print("Client startup completed.")


func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_F2:
				DevServerLauncher.launch_extra_client()


func _on_connected_to_server() -> void:
	print("CLIENT MAIN: Connection confirmed.")


func _on_connection_failed() -> void:
	push_error(
		"CLIENT MAIN: Server connection failed."
	)


func _on_server_disconnected() -> void:
	print(
		"CLIENT MAIN: Server disconnected."
	)
