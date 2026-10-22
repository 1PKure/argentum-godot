extends Node

const CONNECTION_PANEL_SCRIPT := preload(
	"res://client/ui/server_connection_panel.gd"
)

@onready var _local_input: LocalInputController = $LocalInputController
@onready var _world: ClientWorld = $ClientWorld
@onready var _hud: CombatHUD = $CombatHUD

var _connection_panel: ServerConnectionPanel
var _spell_controller: SpellTargetingController
var _lobby_panel: LobbyPanel
var _lobby_id := 0
var _lobby_phase := ""


func _ready() -> void:
	DisplayServer.window_set_title(ArenaBrand.TITLE)
	print("Starting AO Mini client...")
	_local_input.set_process(false)
	_hud.mount_world(_world)
	_hud.disconnect_requested.connect(_leave_lobby)
	_hud.lobby_requested.connect(func() -> void: _lobby_panel.show_room())
	_hud.connection_disconnect_requested.connect(_disconnect_from_arena)
	_lobby_panel = LobbyPanel.new()
	add_child(_lobby_panel)
	_lobby_panel.disconnect_requested.connect(_disconnect_from_arena)
	_lobby_panel.presets_requested.connect(_hud._open_classes)
	_lobby_panel.skins_requested.connect(_hud._open_skins)
	LobbyNetwork.changed.connect(_on_lobby_changed)
	_spell_controller = SpellTargetingController.new()
	add_child(_spell_controller)
	_spell_controller.setup(_world, _hud.game_area)
	_hud.configure_spells(_spell_controller)
	_hud.modal_changed.connect(func(blocked: bool) -> void:
		RecoveryNetwork.set_input_blocked(blocked)
		_local_input.set_process(not blocked and _spell_controller.session_active and LobbyNetwork.gameplay_active())
	)

	NetworkManager.connected_to_server.connect(_on_connected_to_server)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	NetworkManager.connection_attempt_started.connect(_on_connection_attempt_started)

	_connection_panel = CONNECTION_PANEL_SCRIPT.new()
	add_child(_connection_panel)
	_connection_panel.setup(NetworkConstants.get_server_url())
	_connection_panel.connect_requested.connect(_connect_to_server)
	_connection_panel.cancel_requested.connect(_cancel_connection)

	_connection_panel.show_connection("Preparando efectos de combate…")
	_connection_panel.set_busy(true)
	_connection_panel._cancel_button.hide()
	await AOResources.prewarm_combat_fx()
	_connection_panel.set_busy(false)

	if OS.has_feature("web"):
		_connection_panel.show_connection("Elegí el servidor e iniciá la conexión.")
		return

	_connect_to_server(NetworkConstants.get_server_url())


func _connect_to_server(server_url: String) -> void:
	_local_input.set_process(false)
	_spell_controller.end_session()
	_connection_panel.show_connection("Conectando al servidor…")
	_connection_panel.set_busy(true)

	var error: Error = NetworkManager.start_client(server_url)
	if error != OK:
		ArenaNetwork.clear_session()
		LobbyNetwork.clear_session()
		NetworkManager.stop()
		_connection_panel.show_connection(
			"No se pudo iniciar la conexión. Revisá la dirección. Error: %s" % error,
			true
		)


func _cancel_connection() -> void:
	_spell_controller.end_session()
	ArenaNetwork.clear_session()
	LobbyNetwork.clear_session()
	NetworkManager.stop()
	_connection_panel.show_connection("Conexión cancelada. Podés volver a intentar.")


func _disconnect_from_arena() -> void:
	_lobby_panel.close_session()
	_local_input.set_process(false)
	_spell_controller.end_session()
	ArenaNetwork.clear_session()
	LobbyNetwork.clear_session()
	NetworkManager.stop()
	_world.clear_session()
	_hud.end_session("Te desconectaste de la arena.")
	_connection_panel.show_connection("Desconectado. Podés volver a conectar.")


func _unhandled_key_input(event: InputEvent) -> void:
	if OS.has_feature("web") or not OS.is_debug_build():
		return

	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_F2:
			DevServerLauncher.launch_extra_client()


func _on_connection_attempt_started(
	_url: String,
	attempt: int,
	maximum: int
) -> void:
	_connection_panel.set_message("Conectando… intento %d de %d." % [attempt, maximum])


func _on_connected_to_server() -> void:
	print("CLIENT MAIN: Connection confirmed.")
	_connection_panel.hide_connection()
	_hud.start_session(multiplayer.get_unique_id())
	_spell_controller.start_session(multiplayer.get_unique_id())
	_local_input.set_process(false)
	_lobby_panel.open_browser()


func _on_connection_failed() -> void:
	_local_input.set_process(false)
	_connection_panel.show_connection(
		"No se pudo conectar. Comprobá que el servidor esté activo y la dirección sea correcta.",
		true
	)


func _on_server_disconnected() -> void:
	_lobby_panel.close_session()
	print("CLIENT MAIN: Server disconnected.")
	_local_input.set_process(false)
	_spell_controller.end_session()
	_world.clear_session()
	_hud.end_session("Se perdió la conexión con el servidor.")
	_connection_panel.show_connection("Se perdió la conexión con el servidor.", true)


func _leave_lobby() -> void:
	LobbyNetwork.command("leave")

func _on_lobby_changed() -> void:
	if _spell_controller == null: return
	var round_paused := bool(LobbyNetwork.room.get("paused",false))
	_world.set_game_paused(round_paused)
	_hud.set_round_paused(round_paused)
	var room_id := int(LobbyNetwork.room.get("id",0))
	if room_id != _lobby_id:
		_lobby_id = room_id
		_spell_controller.reset_round_input()
		RecoveryNetwork.clear_session()
		BotNetwork.clear_session()
		ArenaNetwork.clear_session()
		_world.clear_session()
		_hud.end_session("Saliste de la sala.")
		if room_id != 0: _hud.start_session(multiplayer.get_unique_id())
	var phase := str(LobbyNetwork.room.get("phase",""))
	if phase == "countdown" and _lobby_phase != "countdown":
		_hud.set_menu_opened(false)
		_hud._class_panel.close_panel()
		_hud._skins_panel.close_panel()
		_hud._bot_panel.close_panel()
		_hud._arena_panel.close_panel()
		_hud._controls_panel.close_panel()
		_hud._release_text_focus()
	_lobby_phase = phase
	var blocked := not LobbyNetwork.gameplay_active() or _hud.is_gameplay_blocked()
	_spell_controller.input_blocked = blocked
	RecoveryNetwork.set_input_blocked(blocked)
	_local_input.set_process(not blocked and _spell_controller.session_active)
	if blocked: _spell_controller.cancel_targeting()
	if LobbyNetwork.room.is_empty(): _world.clear_session()
