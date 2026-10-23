class_name NetworkConstants
extends RefCounted

const DEFAULT_ADDRESS: String = "127.0.0.1"
const DEFAULT_PORT: int = 7777

const LOCAL_WEBSOCKET_URL: String = "ws://127.0.0.1:7777"
const LOCAL_SECURE_WEBSOCKET_URL: String = "wss://127.0.0.1:7777"
const SERVER_URL_SETTING: String = "network/server_url"

const MAX_CLIENTS: int = 100
const SERVER_PEER_ID: int = 1


static func get_server_url() -> String:
	return server_url_from_arguments(OS.get_cmdline_user_args(), str(
		ProjectSettings.get_setting(
			SERVER_URL_SETTING,
			LOCAL_WEBSOCKET_URL
		)
	), OS.has_feature("web"))


# The web shell supplies a validated deployment URL via Engine.startGame args.
# Native development keeps ProjectSettings unless an explicit launch override is supplied.
static func server_url_from_arguments(arguments: PackedStringArray, configured: String, web_client: bool) -> String:
	for argument: String in arguments:
		if argument.begins_with("--server-url="):
			var candidate := argument.trim_prefix("--server-url=").strip_edges()
			if candidate.begins_with("wss://") or (not web_client and candidate.begins_with("ws://")):
				return candidate
	return resolve_server_url(configured, web_client)


static func resolve_server_url(configured_url: String, web_client: bool) -> String:
	var url := configured_url.strip_edges()
	if url.is_empty():
		url = LOCAL_WEBSOCKET_URL
	# The private web test uses the local TLS launcher. Keep native development
	# on WS, and preserve explicitly configured remote addresses in either client.
	if web_client and url == LOCAL_WEBSOCKET_URL:
		return LOCAL_SECURE_WEBSOCKET_URL
	return url
