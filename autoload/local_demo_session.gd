extends Node

const SERVER_FLAG := "--local-demo-server"
const STARTUP_TIMEOUT_MS := 15000
const STORAGE_DIRECTORY := "user://local_demo"

var _server_pid := -1
var _ready_path := ""
var _server_url := ""
var _session_path := ""
var _heartbeat_time := 0.0


func should_start() -> bool:
	var arguments := OS.get_cmdline_user_args()
	return (
		not OS.has_feature("web")
		and (OS.has_feature("local_demo") or "--local-demo" in arguments)
		and not "--server" in arguments
		and not "--no-auto-server" in arguments
	)


func start_session() -> bool:
	if _server_pid > 0:
		return OS.is_process_running(_server_pid)
	if DirAccess.make_dir_recursive_absolute(STORAGE_DIRECTORY) != OK:
		return false
	var reservation := TCPServer.new()
	if reservation.listen(0, "127.0.0.1") != OK:
		return false
	var port := reservation.get_local_port()
	reservation.stop()
	var identifier := "%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_ready_path = STORAGE_DIRECTORY.path_join(identifier + ".ready")
	_session_path = STORAGE_DIRECTORY.path_join(identifier + ".session")
	if not _write_heartbeat():
		return false
	var log_path := ProjectSettings.globalize_path(
		STORAGE_DIRECTORY.path_join("server.log")
	)
	var arguments := PackedStringArray(["--headless", "--log-file", log_path])
	if OS.has_feature("editor"):
		arguments.append_array(PackedStringArray([
			"--path", ProjectSettings.globalize_path("res://"),
		]))
	arguments.append_array(PackedStringArray(["--", "--server", SERVER_FLAG,
		"--port=%d" % port,
		"--demo-session-file=" + _session_path,
		"--demo-ready-file=" + _ready_path,
	]))
	_server_pid = OS.create_instance(arguments)
	if _server_pid <= 0:
		return false
	var deadline := Time.get_ticks_msec() + STARTUP_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if not OS.is_process_running(_server_pid):
			stop_session()
			return false
		if FileAccess.file_exists(_ready_path):
			_server_url = "ws://127.0.0.1:%d" % port
			ProjectSettings.set_setting(NetworkConstants.SERVER_URL_SETTING, _server_url)
			return true
		await get_tree().create_timer(0.05).timeout
	stop_session()
	return false


func get_server_url() -> String:
	return _server_url


func get_server_pid() -> int:
	return _server_pid


func stop_session() -> void:
	if _server_pid > 0 and OS.is_process_running(_server_pid):
		OS.kill(_server_pid)
	_server_pid = -1
	_server_url = ""
	if not _ready_path.is_empty() and FileAccess.file_exists(_ready_path):
		DirAccess.remove_absolute(_ready_path)
	_ready_path = ""
	if not _session_path.is_empty() and FileAccess.file_exists(_session_path):
		DirAccess.remove_absolute(_session_path)
	_session_path = ""


func _process(delta: float) -> void:
	if _server_pid <= 0:
		return
	_heartbeat_time += delta
	if _heartbeat_time >= 1.0:
		_heartbeat_time = 0.0
		_write_heartbeat()


func _write_heartbeat() -> bool:
	var file := FileAccess.open(_session_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string("alive")
	file.close()
	return true


func _exit_tree() -> void:
	stop_session()
