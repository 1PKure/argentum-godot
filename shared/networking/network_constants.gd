class_name NetworkConstants
extends RefCounted

const DEFAULT_ADDRESS: String = "127.0.0.1"
const DEFAULT_PORT: int = 7777

const LOCAL_WEBSOCKET_URL: String = "ws://127.0.0.1:7777"
const SERVER_URL_SETTING: String = "network/server_url"

const MAX_CLIENTS: int = 100
const SERVER_PEER_ID: int = 1


static func get_server_url() -> String:
	var configured_url: String = str(
		ProjectSettings.get_setting(
			SERVER_URL_SETTING,
			LOCAL_WEBSOCKET_URL
		)
	).strip_edges()

	if configured_url.is_empty():
		return LOCAL_WEBSOCKET_URL

	return configured_url

