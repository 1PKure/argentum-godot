extends Node

signal action_requested(peer_id: int, action: String, request_id: int, source: String)
signal action_resolved(event: Dictionary)
signal action_rejected(message: String)
signal selection_changed

var selected_potion := "health_potion"
var using_selected := false
var _hold_origin := ""
var _blocked := false
var _next_request := 0
var _epoch := 0
var _requests: Dictionary = {}
var _pending_potion := 0
var _click_queue := ""
var _use_once := ""
var _click_expires := 0
var _use_expires := 0
var _next_channel: Dictionary = {"click": 0, "use": 0}
var _next_global := 0
var _resources: Dictionary = {}

func _ready() -> void:
	PlayerNetwork.player_stats_updated.connect(_on_player_data)
	PlayerNetwork.snapshot_received.connect(func(players: Array) -> void:
		for player: Dictionary in players:
			_on_player_data(player)
	)
	NetworkManager.server_disconnected.connect(clear_session)
	NetworkManager.connection_failed.connect(clear_session)

func select_potion(action: String) -> void:
	if action not in ["health_potion", "mana_potion"] or action == selected_potion:
		return
	selected_potion = action
	_use_once = ""
	selection_changed.emit()

func begin_using_selected(origin: String = "keyboard") -> void:
	if _blocked:
		return
	using_selected = true
	_hold_origin = origin
	_use_once = selected_potion
	_use_expires = Time.get_ticks_msec() + 600
	_drain()

func stop_using_selected(origin: String = "") -> void:
	if not origin.is_empty() and origin != _hold_origin:
		return
	using_selected = false
	_hold_origin = ""

func cancel_use() -> void:
	_epoch += 1
	stop_using_selected()
	_click_queue = ""
	_use_once = ""

func set_input_blocked(blocked: bool) -> void:
	_blocked = blocked
	if blocked:
		cancel_use()

func request_action(action: String, source: String = "direct") -> void:
	if not SpellNetwork.server_available:
		action_rejected.emit("Actualizá y reiniciá el servidor para usar recuperación.")
		return
	if not _connected():
		return
	if action in ["health_potion", "mana_potion"]:
		select_potion(action)
		if _blocked:
			return
		if source == "click":
			_click_queue = action
			_click_expires = Time.get_ticks_msec() + 600
		else:
			_use_once = action
			_use_expires = Time.get_ticks_msec() + 600
		_drain()
	else:
		_send(action, "direct")

func _process(_delta: float) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		cancel_use()
		return
	if _pending_potion != 0 and Time.get_ticks_msec() - int(_requests.get(_pending_potion, {}).get("sent", 0)) >= 3000:
		_requests.erase(_pending_potion)
		_pending_potion = 0
		cancel_use()
		action_rejected.emit("El servidor no respondió al uso de la poción.")
	_drain()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.pressed and (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE):
		stop_using_selected("keyboard")
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		stop_using_selected("button")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_use()

func _on_player_data(data: Dictionary) -> void:
	if int(data.get("peer_id", 0)) != multiplayer.get_unique_id():
		return
	_resources = data.duplicate(true)
	if not bool(data.get("is_alive", true)):
		cancel_use()

func _can_drink(action: String) -> bool:
	if _resources.is_empty() or not bool(_resources.get("is_alive", false)):
		return false
	if action == "health_potion":
		return int(_resources.current_health) < int(_resources.max_health)
	return int(_resources.get("current_mana", 0)) < int(_resources.get("max_mana", 0))

func _drain() -> void:
	if _blocked or _pending_potion != 0 or not SpellNetwork.server_available or not _connected():
		return
	var now := Time.get_ticks_msec()
	if now > _click_expires:
		_click_queue = ""
	if now > _use_expires:
		_use_once = ""
	if now < _next_global:
		return
	if not _click_queue.is_empty() and now >= int(_next_channel.click):
		var action := _click_queue
		_click_queue = ""
		if _can_drink(action):
			_send(action, "click")
			return
	var action := _use_once if not _use_once.is_empty() else selected_potion
	if (using_selected or not _use_once.is_empty()) and now >= int(_next_channel.use):
		_use_once = ""
		if _can_drink(action):
			_send(action, "use")

func _send(action: String, source: String) -> void:
	_next_request += 1
	var potion := action in ["health_potion", "mana_potion"]
	_requests[_next_request] = {"action": action, "source": source, "sent": Time.get_ticks_msec(), "epoch": _epoch}
	if potion:
		_pending_potion = _next_request
	_request_action.rpc_id(NetworkConstants.SERVER_PEER_ID, action, _next_request, source)

func _connected() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and not multiplayer.is_server() and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func clear_session() -> void:
	cancel_use()
	_next_request = 0
	_pending_potion = 0
	_requests.clear()
	_resources.clear()
	_next_channel = {"click": 0, "use": 0}
	_next_global = 0
	_blocked = false
	selected_potion = "health_potion"
	selection_changed.emit()

func broadcast_result(event: Dictionary) -> void:
	if multiplayer.is_server() and multiplayer.get_peers().has(int(event.peer_id)):
		_receive_result.rpc_id(int(event.peer_id), event)

func send_rejection(peer_id: int, request_id: int, message: String, remaining_msec: int = 0) -> void:
	if multiplayer.is_server():
		_receive_rejection.rpc_id(peer_id, request_id, message, remaining_msec)

@rpc("any_peer", "call_remote", "reliable")
func _request_action(action: String, request_id: int, source: String) -> void:
	if multiplayer.is_server():
		action_requested.emit(multiplayer.get_remote_sender_id(), action, request_id, source)

@rpc("authority", "call_remote", "reliable")
func _receive_result(event: Dictionary) -> void:
	var id := int(event.get("request_id", 0))
	var pending: Dictionary = _requests.get(id, {})
	_requests.erase(id)
	if _pending_potion == id:
		_pending_potion = 0
	if not pending.is_empty() and event.action in ["health_potion", "mana_potion"]:
		var source := str(pending.source)
		_next_channel[source] = int(pending.sent) + RecoveryRules.POTION_INTERVAL_MSEC
		_next_global = int(pending.sent) + RecoveryRules.POTION_COMBINED_MIN_MSEC
	action_resolved.emit(event)

@rpc("authority", "call_remote", "reliable")
func _receive_rejection(request_id: int, message: String, remaining_msec: int) -> void:
	var pending: Dictionary = _requests.get(request_id, {})
	_requests.erase(request_id)
	if _pending_potion == request_id:
		_pending_potion = 0
	if pending.is_empty():
		return
	if remaining_msec > 0 and pending.action in ["health_potion", "mana_potion"]:
		var source := str(pending.source)
		_next_channel[source] = Time.get_ticks_msec() + remaining_msec
		if int(pending.epoch) == _epoch and not _blocked:
			if source == "click":
				_click_queue = str(pending.action)
				_click_expires = Time.get_ticks_msec() + 600
			elif not using_selected:
				_use_once = str(pending.action)
				_use_expires = Time.get_ticks_msec() + 600
		return
	action_rejected.emit(message)
