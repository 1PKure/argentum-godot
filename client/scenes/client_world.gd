class_name ClientWorld
extends Node2D

const SPELL_FEEDBACK := preload("res://client/effects/spell_feedback.gd")
const SPELL_PANEL := preload("res://client/ui/spell_panel.gd")
const SPELL_INPUT := preload("res://client/input/spell_input_state.gd")
var _spell_input: SpellInputState = SPELL_INPUT.new()
var _spell_panel: SpellPanel
var _local_state: PlayerState
var _selected_target := 0

const PLAYER_AVATAR_SCENE: PackedScene = preload(
	"res://client/characters/player_avatar.tscn"
)

const TILE_SIZE: int = 48

const SOURCE_TILE_SIZE := 32.0

const VISUAL_SCALE := (
	float(TILE_SIZE)
	/ SOURCE_TILE_SIZE
)

const GRID_COLUMNS: int = (
	MovementRules.GRID_COLUMNS
)

const GRID_ROWS: int = (
	MovementRules.GRID_ROWS
)

const WORLD_ORIGIN := Vector2(
	120.0,
	80.0
)

var _arena_id: String = (
	ArenaData.DEFAULT_ARENA_ID
)

var _avatars: Dictionary[int, PlayerAvatar] = {}

var _arena_ground: ArenaGround
var _arena_props: Array[AOProp] = []


func _ready() -> void:
	y_sort_enabled = true
	_spell_panel = SPELL_PANEL.new()
	add_child(_spell_panel)
	_spell_panel.spell_selected.connect(_select_spell)
	_spell_panel.launch_requested.connect(_arm_spell)
	_spell_panel.combat_changed.connect(_set_combat_mode)
	PlayerNetwork.spell_result_received.connect(_on_spell_result)
	PlayerNetwork.spell_cast.connect(_on_spell_cast)
	NetworkManager.server_disconnected.connect(_reset_combat_session)

	_create_arena_ground()
	_create_arena_props()

	PlayerNetwork.snapshot_received.connect(
		_on_snapshot_received
	)

	PlayerNetwork.player_spawned.connect(
		_on_player_spawned
	)

	PlayerNetwork.player_despawned.connect(
		_on_player_despawned
	)

	PlayerNetwork.player_moved.connect(
		_on_player_moved
	)

	PlayerNetwork.player_stats_updated.connect(
		_on_player_stats_updated
	)


func _process(_delta: float) -> void:
	_spell_panel.refresh(_spell_input, _local_state, Time.get_ticks_msec())


func _unhandled_input(event: InputEvent) -> void:
	if _local_state == null or not NetworkManager.is_network_connected():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_spell()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and _spell_input.is_targeting():
			var target_id := _target_at_position(to_local(get_global_mouse_position()))
			if target_id == 0:
				_spell_panel.show_message("Apuntá a un jugador vivo.", true)
			else:
				_request_spell(target_id)
			get_viewport().set_input_as_handled()


func _target_at_position(point: Vector2) -> int:
	var selected := 0
	var nearest := INF
	for avatar: PlayerAvatar in _avatars.values():
		var bounds := Rect2(avatar.position + Vector2(-24, -62), Vector2(48, 86))
		var distance := point.distance_squared_to(avatar.position + Vector2(0, -20))
		if bounds.has_point(point) and distance < nearest:
			selected = avatar.peer_id
			nearest = distance
	return selected


func _select_spell(spell_id: int) -> void:
	if SpellCatalog.get_spell(spell_id) == null:
		return
	_spell_input.selected_spell_id = spell_id
	_spell_panel.show_message("%s seleccionado." % SpellCatalog.get_spell(spell_id).display_name)


func _arm_spell() -> void:
	if _local_state == null or not _local_state.is_alive:
		return
	_spell_input.manual_armed = true
	_update_spell_cursor()
	_spell_panel.show_message("Hacé clic sobre el objetivo.")


func _set_combat_mode(enabled: bool) -> void:
	if _local_state == null or not _local_state.is_alive:
		return
	_spell_input.combat_mode = enabled
	_spell_input.manual_armed = false
	_update_spell_cursor()
	_spell_panel.show_message("Combate: clic para lanzar." if enabled else "Manual: pulsá Lanzar y apuntá.")


func _cancel_spell() -> void:
	_spell_input.cancel_targeting()
	_update_spell_cursor()
	_spell_panel.show_message("Apuntado cancelado.")


func _update_spell_cursor() -> void:
	var targeting := _local_state != null and _local_state.is_alive and _spell_input.is_targeting()
	Input.set_default_cursor_shape(Input.CURSOR_CROSS if targeting else Input.CURSOR_ARROW)


func _request_spell(target_id: int) -> void:
	if _local_state == null or not _local_state.is_alive or not NetworkManager.is_network_connected():
		return
	var request_id := _spell_input.begin_request(Time.get_ticks_msec())
	if request_id == 0:
		_spell_panel.show_message("Esperá a que termine el lanzamiento o la recarga.", true)
		return
	_selected_target = target_id
	for avatar: PlayerAvatar in _avatars.values():
		avatar.set_selected(avatar.peer_id == target_id)
	_spell_panel.show_message("Lanzando…")
	PlayerNetwork.request_spell(_spell_input.selected_spell_id, target_id, request_id)


func _on_spell_result(request_id: int, success: bool, reason: String, retry_after_msec: int) -> void:
	if not _spell_input.finish_request(request_id, success, retry_after_msec, Time.get_ticks_msec()):
		return
	_spell_panel.show_message("Hechizo lanzado." if success else SpellRules.get_message(reason), not success)
	_update_spell_cursor()


func _on_spell_cast(event: Dictionary) -> void:
	var spell: SpellDefinition = SpellCatalog.get_spell(int(event.get("spell_id", 0)))
	if spell == null:
		return
	var effect := SPELL_FEEDBACK.new()
	effect.start = _grid_to_world(Vector2i(int(event["caster_x"]), int(event["caster_y"])))
	effect.finish = _grid_to_world(Vector2i(int(event["target_x"]), int(event["target_y"])))
	effect.amount = int(event["amount"])
	effect.healing = spell.effect == SpellDefinition.Effect.HEAL
	add_child(effect)


func _reset_combat_session() -> void:
	_spell_input.reset_session()
	_local_state = null
	_selected_target = 0
	_clear_players()
	_update_spell_cursor()


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _unhandled_key_input(
	event: InputEvent
) -> void:
	if not event is InputEventKey:
		return

	if not event.pressed:
		return

	if event.echo:
		return
	if _local_state == null or not NetworkManager.is_network_connected():
		return
	match event.keycode:
		KEY_1: _select_spell(SpellCatalog.DAMAGE)
		KEY_2: _select_spell(SpellCatalog.HEAL)
		KEY_C: _set_combat_mode(not _spell_input.combat_mode)
		KEY_E: _arm_spell()
		KEY_ESCAPE: _cancel_spell()
		_:
			if event.keycode not in [KEY_CTRL, KEY_F3, KEY_F4]:
				return
	if event.keycode in [KEY_1, KEY_2, KEY_C, KEY_E, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
		return

	if event.keycode == KEY_CTRL:
		_request_basic_attack()
		return

	if not OS.is_debug_build():
		return

	if event.keycode == KEY_F3:
		PlayerNetwork.request_debug_damage()
		return

	if event.keycode == KEY_F4:
		PlayerNetwork.request_debug_mana_spend()


func _request_basic_attack() -> void:
	PlayerNetwork.request_basic_attack()


func _create_arena_ground() -> void:
	_arena_ground = ArenaGround.new()

	_arena_ground.z_index = -10

	add_child(
		_arena_ground
	)

	_arena_ground.setup(
		_arena_id,
		GRID_COLUMNS,
		GRID_ROWS,
		TILE_SIZE,
		WORLD_ORIGIN
	)


func _create_arena_props() -> void:
	var props: Array[Dictionary] = (
		ArenaData.get_props(
			_arena_id
		)
	)

	for prop_data: Dictionary in props:
		var grh_id: int = int(
			prop_data.get(
				"grh_id",
				0
			)
		)

		var grid_position: Vector2i = (
			prop_data.get(
				"grid_position",
				Vector2i.ZERO
			)
		)

		_create_prop(
			grh_id,
			grid_position
		)


func _create_prop(
	grh_id: int,
	grid_position: Vector2i
) -> void:
	var prop := AOProp.new()

	add_child(
		prop
	)

	prop.setup(
		grh_id,
		_grid_to_world(
			grid_position
		),
		VISUAL_SCALE
	)

	_arena_props.append(
		prop
	)


func _on_snapshot_received(
	players: Array
) -> void:
	_spell_input.reset_session()
	_selected_target = 0
	_local_state = null
	print(
		"Player snapshot received. Players: %d"
		% players.size()
	)

	_clear_players()

	for player_data in players:
		_spawn_player(
			player_data
		)


func _on_player_spawned(
	player_data: Dictionary
) -> void:
	var peer_id: int = int(
		player_data.get(
			"peer_id",
			0
		)
	)

	if _avatars.has(
		peer_id
	):
		return

	print(
		"Remote player spawned: %d"
		% peer_id
	)

	_spawn_player(
		player_data
	)


func _on_player_despawned(
	peer_id: int
) -> void:
	if _selected_target == peer_id:
		_selected_target = 0
	if not _avatars.has(
		peer_id
	):
		return

	print(
		"Player despawned: %d"
		% peer_id
	)

	_avatars[
		peer_id
	].queue_free()

	_avatars.erase(
		peer_id
	)


func _on_player_moved(
	player_data: Dictionary
) -> void:
	var state := PlayerState.from_dictionary(
		player_data
	)
	if state.peer_id == multiplayer.get_unique_id():
		_local_state = state

	if not _avatars.has(
		state.peer_id
	):
		return

	var avatar: PlayerAvatar = (
		_avatars[
			state.peer_id
		]
	)

	avatar.apply_server_position(
		state.grid_position,
		_grid_to_world(
			state.grid_position
		)
	)


func _on_player_stats_updated(
	player_data: Dictionary
) -> void:
	var state := PlayerState.from_dictionary(
		player_data
	)
	if state.peer_id == multiplayer.get_unique_id():
		_local_state = state
		if not state.is_alive:
			_spell_input.cancel_targeting()
			_update_spell_cursor()
	print(
	"CLIENT STATE -> Player: %d | HP: %d | Alive: %s | Ghost: %s"
	% [
		state.peer_id,
		state.current_health,
		state.is_alive,
		state.is_ghost
	]
)

	if not _avatars.has(
		state.peer_id
	):
		return

	var avatar: PlayerAvatar = (
		_avatars[
			state.peer_id
		]
	)

	avatar.apply_server_stats(
		state
	)


func _spawn_player(
	player_data: Dictionary
) -> void:
	var state := PlayerState.from_dictionary(
		player_data
	)

	if _avatars.has(
		state.peer_id
	):
		return

	var avatar: PlayerAvatar = (
		PLAYER_AVATAR_SCENE.instantiate()
	)

	add_child(
		avatar
	)

	var local_peer_id: int = (
		multiplayer.get_unique_id()
	)

	var is_local: bool = (
		state.peer_id
		== local_peer_id
	)
	if is_local:
		_local_state = state
		_spell_panel.show_message("Elegí un hechizo y pulsá Lanzar, o activá Combate.")

	avatar.setup(
		state,
		is_local,
		_grid_to_world(
			state.grid_position
		)
	)

	_avatars[
		state.peer_id
	] = avatar


func _grid_to_world(
	grid_position: Vector2i
) -> Vector2:
	return (
		WORLD_ORIGIN
		+ Vector2(
			grid_position.x
			* TILE_SIZE
			+ TILE_SIZE * 0.5,

			grid_position.y
			* TILE_SIZE
			+ TILE_SIZE * 0.5
		)
	)


func _clear_players() -> void:
	for avatar in _avatars.values():
		avatar.queue_free()

	_avatars.clear()
