extends SceneTree

const TEST_PORT := 17777

var _checks := 0
var _failures := 0
var _attempts: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var manager = root.get_node("NetworkManager")
	manager.stop()

	var original_url: Variant = ProjectSettings.get_setting(
		NetworkConstants.SERVER_URL_SETTING,
		NetworkConstants.LOCAL_WEBSOCKET_URL
	)
	ProjectSettings.set_setting(NetworkConstants.SERVER_URL_SETTING, "")
	_expect(
		NetworkConstants.get_server_url() == NetworkConstants.LOCAL_WEBSOCKET_URL,
		"An empty server setting falls back to the local URL."
	)
	ProjectSettings.set_setting(
		NetworkConstants.SERVER_URL_SETTING,
		"  wss://arena.example.test/game  "
	)
	_expect(
		NetworkConstants.get_server_url() == "wss://arena.example.test/game",
		"A custom server URL is used and trimmed."
	)
	ProjectSettings.set_setting(NetworkConstants.SERVER_URL_SETTING, original_url)

	_expect(
		manager.start_client("https://example.test") == ERR_INVALID_PARAMETER,
		"Unsupported schemes are rejected before connecting."
	)
	_expect(not manager.is_network_connected(), "Invalid input leaves the client offline.")

	var panel: ServerConnectionPanel = preload(
		"res://client/ui/server_connection_panel.gd"
	).new()
	root.add_child(panel)
	panel.setup(NetworkConstants.LOCAL_WEBSOCKET_URL)
	panel.show_connection()
	var submitted: Array[String] = []
	panel.connect_requested.connect(func(url: String) -> void: submitted.append(url))
	var input := panel.find_child("ServerURL", true, false) as LineEdit
	var connect_button := panel.find_child("ConnectButton", true, false) as Button
	input.text = "https://example.test"
	connect_button.pressed.emit()
	_expect(submitted.is_empty(), "The connection panel rejects an unsupported scheme.")
	input.text = "  ws://127.0.0.1:7777  "
	connect_button.pressed.emit()
	_expect(submitted == ["ws://127.0.0.1:7777"], "The panel submits the chosen URL.")
	panel.set_busy(true)
	input.text_submitted.emit(input.text)
	_expect(submitted.size() == 1, "Busy state prevents duplicate connection requests.")
	panel.queue_free()

	var server := WebSocketMultiplayerPeer.new()
	var error := server.create_server(TEST_PORT, "127.0.0.1")
	_expect(error == OK, "The loopback test server starts on port %d." % TEST_PORT)
	if error != OK:
		_finish(manager, server)
		return

	manager.connection_attempt_started.connect(_on_attempt)
	# Cancel before the retry delay expires, then connect to a live server.
	manager.start_client("ws://127.0.0.1:1")
	await create_timer(0.25).timeout
	manager.stop()
	var test_url := "ws://127.0.0.1:%d" % TEST_PORT
	_expect(manager.start_client(test_url) == OK, "A new connection starts after canceling.")
	var deadline := Time.get_ticks_msec() + 3000
	while not manager.is_network_connected() and Time.get_ticks_msec() < deadline:
		server.poll()
		await create_timer(0.01).timeout
	_expect(manager.is_network_connected(), "The real WebSocket client connects to loopback.")
	var active_peer: MultiplayerPeer = manager.peer
	deadline = Time.get_ticks_msec() + 750
	while Time.get_ticks_msec() < deadline:
		server.poll()
		await create_timer(0.01).timeout
	var live_attempts := 0
	for attempt: Dictionary in _attempts:
		if attempt["url"] == test_url:
			live_attempts += 1
	_expect(live_attempts == 1, "A canceled retry does not reconnect the new session.")
	_expect(manager.peer == active_peer, "The connected peer remains the same after old timers.")
	manager.connection_attempt_started.disconnect(_on_attempt)
	_finish(manager, server)


func _on_attempt(url: String, attempt: int, _maximum: int) -> void:
	_attempts.append({"url": url, "attempt": attempt})


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _finish(manager, server: WebSocketMultiplayerPeer) -> void:
	manager.stop()
	server.close()
	print("Web connection smoke checks: %d; failures: %d" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)
