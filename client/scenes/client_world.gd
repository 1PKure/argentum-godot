class_name ClientWorld
extends Node2D

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


func _unhandled_key_input(
	event: InputEvent
) -> void:
	if not event is InputEventKey:
		return

	if not event.pressed:
		return

	if event.echo:
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
