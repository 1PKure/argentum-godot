extends SceneTree

const TLS_CONFIG := preload("res://shared/networking/server_tls_config.gd")
const TEST_PORT := 17778
var _failures := 0
var _paths: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var disabled := TLS_CONFIG.from_arguments(PackedStringArray())
	_expect(disabled["error"] == OK and not disabled["enabled"], "Normal WS remains available.")
	var incomplete := TLS_CONFIG.from_arguments(PackedStringArray(["--server-local-wss"]))
	_expect(incomplete["error"] != OK, "WSS fails closed without certificates.")
	var orphan := TLS_CONFIG.from_arguments(PackedStringArray(["--server-tls-key=missing.pem"]))
	_expect(orphan["error"] != OK, "TLS parameters cannot silently launch plain WS.")
	var empty_orphan := TLS_CONFIG.from_arguments(PackedStringArray(["--server-tls-key="]))
	_expect(empty_orphan["error"] != OK, "Even empty TLS parameters require explicit WSS mode.")
	var missing := TLS_CONFIG.from_arguments(PackedStringArray([
		"--server-local-wss", "--server-tls-cert=user://missing-cert.pem",
		"--server-tls-key=user://missing-key.pem",
	]))
	_expect(missing["error"] != OK, "Missing certificate files prevent startup.")

	var crypto := Crypto.new()
	var key: CryptoKey = crypto.generate_rsa(2048)
	var certificate: X509Certificate = crypto.generate_self_signed_certificate(key, "CN=localhost,O=Argentum")
	if key == null or certificate == null:
		_expect(false, "Test certificate generation.")
		_finish(null, null)
		return
	var prefix := "user://wss-test-%d" % Time.get_ticks_usec()
	var cert_path := prefix + ".pem"
	var key_path := prefix + "-key.pem"
	_paths.assign([cert_path, key_path])
	_expect(certificate.save(cert_path) == OK and key.save(key_path) == OK, "Test TLS files are saved.")
	var config := TLS_CONFIG.from_arguments(PackedStringArray([
		"--server-local-wss", "--server-tls-cert=" + cert_path, "--server-tls-key=" + key_path,
	]))
	_expect(config["error"] == OK and config["enabled"], "Valid certificates enable TLS.")
	_expect(config["bind_address"] == "127.0.0.1", "Local WSS binds only to loopback.")
	if config["error"] != OK:
		_finish(null, null)
		return

	var server := WebSocketMultiplayerPeer.new()
	var client := WebSocketMultiplayerPeer.new()
	var error: Error = server.create_server(TEST_PORT, config["bind_address"], config["tls_options"])
	_expect(error == OK, "A real WSS test server starts.")
	if error != OK:
		_finish(server, client)
		return
	error = client.create_client("wss://127.0.0.1:%d" % TEST_PORT, TLSOptions.client(certificate, "localhost"))
	_expect(error == OK, "A verifying TLS client starts.")
	var deadline := Time.get_ticks_msec() + 5000
	while client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING and Time.get_ticks_msec() < deadline:
		server.poll()
		client.poll()
		await create_timer(0.01).timeout
	_expect(client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "A real WebSocket multiplayer handshake succeeds over verified TLS.")
	_finish(server, client)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _finish(server, client) -> void:
	if client != null:
		client.close()
	if server != null:
		server.close()
	for path: String in _paths:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Server TLS smoke failures: %d" % _failures)
	quit(0 if _failures == 0 else 1)
