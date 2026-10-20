extends Node
signal changed
signal profile_requested(peer_id: int, identity: String, secret: String, nickname: String, request: int)
signal snapshot_requested(peer_id: int)
var snapshot: Dictionary = {}
var player: Dictionary = {}
var registered := false
var available := false
var pending := false
var message := ""
var nickname := ""
var _identity: Dictionary = {}
var _profile := ""
var _request := 0
var _pending_request := 0
var _elapsed := 0.0
const IDENTITY_PATH := "user://ranking_identity_v1.cfg"
const REFRESH_SECONDS := 30.0

func _ready() -> void:
	_load_identity()
	InputBindings.changed.connect(func() -> void:
		if _profile != InputBindings.profile_id and not _connected(): _load_identity()
	)
	SpellNetwork.server_capabilities_received.connect(func(value: bool) -> void:
		available = value
		if value and _connected(): register_name(nickname)
		changed.emit()
	)
	NetworkManager.server_disconnected.connect(clear_session)
	NetworkManager.connection_failed.connect(clear_session)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= REFRESH_SECONDS:
		_elapsed = 0
		refresh()

func _load_identity() -> void:
	_profile = InputBindings.profile_id
	var config := ConfigFile.new()
	config.load(IDENTITY_PATH)
	var id := str(config.get_value(_profile,"id",""))
	var secret := str(config.get_value(_profile,"secret",""))
	if id.length() != 32 or secret.length() != 64:
		id = Crypto.new().generate_random_bytes(16).hex_encode()
		secret = Crypto.new().generate_random_bytes(32).hex_encode()
		config.set_value(_profile,"id",id)
		config.set_value(_profile,"secret",secret)
	nickname = str(config.get_value(_profile,"nickname","Aventurero_"+id.left(6)))
	_identity = {"id":id,"secret":secret}
	config.set_value(_profile,"nickname",nickname)
	if config.save(IDENTITY_PATH) != OK: message = "No se pudo guardar tu perfil en este dispositivo."

func clear_session() -> void:
	available = false
	registered = false
	pending = false
	_pending_request = 0
	snapshot.clear()
	player.clear()
	message = "Sin conexión al ranking."
	changed.emit()

func _connected() -> bool:
	return not multiplayer.is_server() and multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func register_name(value: String) -> void:
	if pending or not available or not _connected(): return
	_request += 1
	_pending_request = _request
	pending = true
	message = "Guardando nombre…"
	_request_profile.rpc_id(NetworkConstants.SERVER_PEER_ID,str(_identity.id),str(_identity.secret),value,_request)
	changed.emit()
	var expected := _request
	await get_tree().create_timer(4.0).timeout
	if pending and _pending_request == expected:
		pending = false
		message = "El servidor no respondió. Volvé a intentar."
		changed.emit()

func refresh() -> void:
	if available and _connected(): _request_snapshot.rpc_id(NetworkConstants.SERVER_PEER_ID)

func send_profile(peer_id: int, request: int, result: Dictionary, state: Dictionary) -> void:
	if multiplayer.is_server(): _receive_profile.rpc_id(peer_id,request,bool(result.ok),str(result.get("message","")),result.get("player",{}),state)

func send_snapshot(peer_id: int, state: Dictionary) -> void:
	if multiplayer.is_server(): _receive_snapshot.rpc_id(peer_id,state)

@rpc("any_peer","call_remote","reliable")
func _request_profile(identity: String, secret: String, value: String, request: int) -> void:
	if multiplayer.is_server(): profile_requested.emit(multiplayer.get_remote_sender_id(),identity,secret,value,request)

@rpc("any_peer","call_remote","reliable")
func _request_snapshot() -> void:
	if multiplayer.is_server(): snapshot_requested.emit(multiplayer.get_remote_sender_id())

@rpc("authority","call_remote","reliable")
func _receive_profile(request: int, ok: bool, text: String, public_player: Dictionary, state: Dictionary) -> void:
	if request != _pending_request or not pending: return
	pending = false
	message = text
	if ok:
		registered = true
		player = public_player
		nickname = str(player.get("nickname",nickname))
		var config := ConfigFile.new()
		config.load(IDENTITY_PATH)
		config.set_value(_profile,"nickname",nickname)
		if config.save(IDENTITY_PATH) != OK: message = "Nombre guardado en el servidor; no se pudo guardar en este dispositivo."
	_receive_snapshot(state)

@rpc("authority","call_remote","reliable")
func _receive_snapshot(state: Dictionary) -> void:
	if int(state.get("schema",0)) != 1 or not state.get("entries",[]) is Array: return
	snapshot = state.duplicate(true)
	_elapsed = 0
	changed.emit()
	if OS.has_feature("web"):
		# Public data only. A future web shell can consume this snapshot/event
		# while the client is connected; no credentials or score writes cross it.
		JavaScriptBridge.eval("window.argentumRanking = "+JSON.stringify(snapshot)+"; window.dispatchEvent(new CustomEvent('argentum:ranking', {detail: window.argentumRanking}));",true)
