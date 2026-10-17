extends Node

const CONNECTION_PANEL_SCRIPT := preload(
	"res://client/ui/server_connection_panel.gd"
)

@onready var _local_input: LocalInputController = $LocalInputController
@onready var _world: ClientWorld = $ClientWorld
@onready var _hud: CombatHUD = $CombatHUD

var _connection_panel: ServerConnectionPanel
var _spell_controller: SpellTargetingController


func _ready() -> void:
	print("Starting Argentum client...")
	_local_input.set_process(false)
	_hud.mount_world(_world)
	_hud.disconnect_requested.connect(_disconnect_from_arena)
	_spell_controller = SpellTargetingController.new()
	add_child(_spell_controller)
	_spell_controller.setup(_world, _hud.game_area)
	_hud.configure_spells(_spell_controller)
	_hud.modal_changed.connect(func(blocked: bool) -> void:
		_local_input.set_process(not blocked and _spell_controller.session_active)
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
		NetworkManager.stop()
		_connection_panel.show_connection(
			"No se pudo iniciar la conexión. Revisá la dirección. Error: %s" % error,
			true
		)


func _cancel_connection() -> void:
	_spell_controller.end_session()
	NetworkManager.stop()
	_connection_panel.show_connection("Conexión cancelada. Podés volver a intentar.")


func _disconnect_from_arena() -> void:
	_local_input.set_process(false)
	_spell_controller.end_session()
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
	_local_input.set_process(true)


func _on_connection_failed() -> void:
	_local_input.set_process(false)
	_connection_panel.show_connection(
		"No se pudo conectar. Comprobá que el servidor esté activo y la dirección sea correcta.",
		true
	)


func _on_server_disconnected() -> void:
	print("CLIENT MAIN: Server disconnected.")
	_local_input.set_process(false)
	_spell_controller.end_session()
	_world.clear_session()
	_hud.end_session("Se perdió la conexión con el servidor.")
	_connection_panel.show_connection("Se perdió la conexión con el servidor.", true)
