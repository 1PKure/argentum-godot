extends Node

const CLIENT_SCENE_PATH := "res://client/scenes/client_main.tscn"
const SERVER_SCENE_PATH := "res://server/scenes/server_main.tscn"

const DEV_SERVER_STARTUP_DELAY := 0.5


func _ready() -> void:
	await get_tree().process_frame

	var args := OS.get_cmdline_user_args()

	if "--server" in args:
		_start_server()
		return

	await _start_client()


func _start_server() -> void:
	print("Starting dedicated server...")

	var error := get_tree().change_scene_to_file(
		SERVER_SCENE_PATH
	)

	if error != OK:
		push_error(
			"Failed to load server scene. Error: %s"
			% error
		)


func _start_client() -> void:
	if LocalDemoSession.should_start():
		if not await LocalDemoSession.start_session():
			var dialog := AcceptDialog.new()
			dialog.title = "AO Mini"
			dialog.dialog_text = "No se pudo iniciar la práctica local. Cerrá el juego e intentá nuevamente.\nRegistro: " + ProjectSettings.globalize_path("user://local_demo/server.log")
			dialog.confirmed.connect(func() -> void: get_tree().quit(1))
			dialog.canceled.connect(func() -> void: get_tree().quit(1))
			add_child(dialog)
			dialog.popup_centered(Vector2i(560, 160))
			return
	elif DevServerLauncher.should_auto_start_server():
		var server_pid: int = (
			DevServerLauncher.ensure_server_running()
		)

		if server_pid <= 0:
			push_error(
				"Development server could not be started."
			)
			return

		await get_tree().create_timer(
			DEV_SERVER_STARTUP_DELAY
		).timeout

	print("Starting client...")

	var error := get_tree().change_scene_to_file(
		CLIENT_SCENE_PATH
	)

	if error != OK:
		push_error(
			"Failed to load client scene. Error: %s"
			% error
		)
