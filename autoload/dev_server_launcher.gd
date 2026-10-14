extends Node

const SERVER_FLAG := "--server"
const DEV_CHILD_FLAG := "--dev-child"
const NO_AUTO_SERVER_FLAG := "--no-auto-server"

const SERVER_LOG_FILE := "user://dev_server.log"

var _server_pid: int = -1
var _extra_client_pids: Array[int] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()

	if DEV_CHILD_FLAG in args:
		print("Development server child started.")


func should_auto_start_server() -> bool:
	var args := OS.get_cmdline_user_args()

	if SERVER_FLAG in args:
		return false

	if NO_AUTO_SERVER_FLAG in args:
		return false

	return OS.is_debug_build()


func ensure_server_running() -> int:
	if (
		_server_pid > 0
		and OS.is_process_running(_server_pid)
	):
		print(
			"Development server already running. PID: %d"
			% _server_pid
		)

		return _server_pid

	var project_path := ProjectSettings.globalize_path(
		"res://"
	)

	var log_path := ProjectSettings.globalize_path(
		SERVER_LOG_FILE
	)

	var arguments := PackedStringArray([
		"--headless",
		"--path",
		project_path,
		"--log-file",
		log_path,
		"--",
		SERVER_FLAG,
		DEV_CHILD_FLAG
	])

	print("Starting development server...")
	print("Project path: ", project_path)
	print("Server log: ", log_path)

	_server_pid = OS.create_instance(arguments)

	if _server_pid <= 0:
		push_error(
			"Failed to create development server instance."
		)

		_server_pid = -1

		return -1

	print(
		"Development server process created. PID: %d"
		% _server_pid
	)

	return _server_pid


func launch_extra_client() -> int:
	if not OS.is_debug_build():
		push_error(
			"Extra clients can only be launched in debug builds."
		)

		return -1

	var project_path := ProjectSettings.globalize_path(
		"res://"
	)

	var arguments := PackedStringArray([
		"--path",
		project_path,
		"--",
		NO_AUTO_SERVER_FLAG
	])

	print("Starting extra development client...")

	var client_pid := OS.create_instance(arguments)

	if client_pid <= 0:
		push_error(
			"Failed to create extra development client."
		)

		return -1

	_extra_client_pids.append(client_pid)

	print(
		"Extra development client created. PID: %d"
		% client_pid
	)

	return client_pid


func stop_server() -> void:
	if _server_pid <= 0:
		return

	if OS.is_process_running(_server_pid):
		print(
			"Stopping development server. PID: %d"
			% _server_pid
		)

		OS.kill(_server_pid)

	_server_pid = -1


func stop_extra_clients() -> void:
	for client_pid in _extra_client_pids:
		if not OS.is_process_running(client_pid):
			continue

		print(
			"Stopping extra development client. PID: %d"
			% client_pid
		)

		OS.kill(client_pid)

	_extra_client_pids.clear()


func _exit_tree() -> void:
	var args := OS.get_cmdline_user_args()

	if DEV_CHILD_FLAG in args:
		return

	if NO_AUTO_SERVER_FLAG in args:
		return

	stop_extra_clients()
	stop_server()
