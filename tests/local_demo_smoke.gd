extends SceneTree

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var session := root.get_node("LocalDemoSession")
	# Inherited hosting configuration must never send demo results to a remote store.
	OS.set_environment("AO_STORE_URL", "http://127.0.0.1:1/unreachable")
	OS.set_environment("AO_STORE_TOKEN", "unused-test-value")
	_expect(await session.start_session(), "A real dedicated starts despite inherited remote settings.")
	var server_pid: int = session.get_server_pid()
	_expect(server_pid > 0 and OS.is_process_running(server_pid), "The session owns a running server process.")
	var url: String = session.get_server_url()
	_expect(url.begins_with("ws://127.0.0.1:"), "The selected endpoint is local.")
	_expect(NetworkConstants.get_server_url() == url, "The client receives the selected port.")
	var peer := WebSocketMultiplayerPeer.new()
	_expect(peer.create_client(url) == OK, "A real client starts connecting.")
	var deadline := Time.get_ticks_msec() + 5000
	while peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING and Time.get_ticks_msec() < deadline:
		peer.poll()
		await create_timer(0.02).timeout
	_expect(peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "The ready signal precedes a successful WebSocket handshake.")
	peer.close()
	_expect(await session.start_session(), "Repeated start keeps the existing process.")
	_expect(session.get_server_pid() == server_pid, "Repeated start does not create another dedicated.")
	session.stop_session()
	await create_timer(0.2).timeout
	var released_port := TCPServer.new()
	_expect(released_port.listen(int(url.get_slice(":", 2)), "127.0.0.1") == OK, "Closing the session releases the dedicated port.")
	released_port.stop()
	_expect(session.get_server_url().is_empty(), "Closing clears the endpoint.")
	session.stop_session()
	_expect(session.get_server_pid() == -1, "Repeated close is safe.")
	OS.unset_environment("AO_STORE_URL")
	OS.unset_environment("AO_STORE_TOKEN")
	print("Local demo checks: %d; failures: %d" % [_checks, _failures])
	quit(1 if _failures else 0)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)
