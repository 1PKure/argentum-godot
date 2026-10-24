extends Node
signal changed
signal message_received(message: Dictionary)
signal completed(ok: bool, message: String)
signal message_requested(peer_id: int, room_id: int, text: String, request: int)
var messages: Array = []
var pending := false
var _room_id := 0
var _next_request := 0
var _pending_request := 0
var _epoch := 0

func _ready() -> void:
	LobbyNetwork.changed.connect(func() -> void:
		var room_id := int(LobbyNetwork.room.get("id",0))
		if room_id != _room_id:
			_room_id = room_id
			_clear()
	)
	NetworkManager.server_disconnected.connect(func() -> void: _room_id = 0; _clear())
	NetworkManager.connection_failed.connect(func() -> void: _room_id = 0; _clear())

func _clear() -> void:
	_epoch+=1
	pending = false
	_pending_request = 0
	messages.clear()
	changed.emit()

func send(text: String) -> bool:
	if pending or _room_id<=0 or not LobbyNetwork.available or multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED: return false
	if ArenaChatService.clean(text).is_empty():
		completed.emit(false,"Escribí un mensaje de 1 a 160 caracteres.")
		return false
	_next_request+=1
	_pending_request = _next_request
	pending = true
	var epoch := _epoch
	var request := _pending_request
	_send.rpc_id(NetworkConstants.SERVER_PEER_ID,_room_id,text,request)
	changed.emit()
	_timeout(epoch,request)
	return true

func _timeout(epoch: int, request: int) -> void:
	await get_tree().create_timer(4).timeout
	if epoch == _epoch and pending and request == _pending_request:
		pending = false
		completed.emit(false,"No se pudo confirmar el mensaje. Volvé a intentar.")
		changed.emit()

func send_history(peer: int, room_id: int, history: Array) -> void:
	if multiplayer.is_server(): _history.rpc_id(peer,room_id,history)
func deliver(peer: int, message: Dictionary) -> void:
	if multiplayer.is_server(): _message.rpc_id(peer,message)
func acknowledge(peer: int, request: int, ok: bool, error: String) -> void:
	if multiplayer.is_server(): _acknowledge.rpc_id(peer,request,ok,error)

@rpc("any_peer","call_remote","reliable")
func _send(room_id: int, text: String, request: int) -> void:
	if multiplayer.is_server(): message_requested.emit(multiplayer.get_remote_sender_id(),room_id,text,request)
@rpc("authority","call_remote","reliable")
func _history(room_id: int, history: Array) -> void:
	if room_id != _room_id: return
	messages = history.slice(maxi(0,history.size()-ArenaChatService.HISTORY_LIMIT)).duplicate(true)
	changed.emit()
@rpc("authority","call_remote","reliable")
func _message(message: Dictionary) -> void:
	if int(message.get("room_id",0)) != _room_id or _room_id == 0: return
	for previous: Dictionary in messages:
		if int(previous.id) == int(message.id): return
	messages.append(message.duplicate(true))
	if messages.size()>ArenaChatService.HISTORY_LIMIT: messages.pop_front()
	message_received.emit(message)
	changed.emit()
@rpc("authority","call_remote","reliable")
func _acknowledge(request: int, ok: bool, error: String) -> void:
	if not pending or request != _pending_request: return
	pending = false
	completed.emit(ok,error)
	changed.emit()
