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
var _arena_props: Array[Node2D] = []
var _arena_revision := -1
var _spell_effects: Array[Node2D] = []

var _viewport_size := Vector2.ZERO
var _camera_enabled := false
var _local_avatar_peer_id := 0


func _ready() -> void:
	# Run after PlayerAvatar interpolation so following never lags a render frame.
	process_priority = 100
	y_sort_enabled = true
	SpellNetwork.spell_resolved.connect(_on_spell_resolved)
	ArenaNetwork.changed.connect(_on_arena_state)

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


func configure_viewport(viewport_size: Vector2) -> void:
	# Only this world moves. Its parent Control clips the map and the HUD stays put.
	_camera_enabled = true
	scale = Vector2.ONE
	resize_viewport(viewport_size)


func resize_viewport(viewport_size: Vector2) -> void:
	_viewport_size = Vector2(maxf(viewport_size.x, 1.0), maxf(viewport_size.y, 1.0))
	_update_camera()


func _process(_delta: float) -> void:
	_update_camera()


func _update_camera() -> void:
	if not _camera_enabled:
		return
	var focus := WORLD_ORIGIN + Vector2(GRID_COLUMNS, GRID_ROWS) * TILE_SIZE * 0.5
	var avatar: PlayerAvatar = _avatars.get(_local_avatar_peer_id)
	if is_instance_valid(avatar):
		focus = avatar.position
	position = _viewport_size * 0.5 - focus * scale


func _unhandled_key_input(
	event: InputEvent
) -> void:
	if not event is InputEventKey:
		return

	if not event.pressed:
		return

	if event.echo:
		return

	if not OS.is_debug_build():
		return

	if event.keycode == KEY_F3:
		PlayerNetwork.request_debug_damage()
		return

	if event.keycode == KEY_F4:
		PlayerNetwork.request_debug_mana_spend()


func target_grid_at(viewport_position: Vector2) -> Vector2i:
	var local_point := get_global_transform().affine_inverse() * viewport_position
	for avatar: PlayerAvatar in _avatars.values():
		if Rect2(avatar.position + Vector2(-24, -68), Vector2(48, 100)).has_point(local_point):
			return avatar.grid_position
	return Vector2i(floori((local_point.x - WORLD_ORIGIN.x) / TILE_SIZE), floori((local_point.y - WORLD_ORIGIN.y) / TILE_SIZE))


func _on_spell_resolved(event: Dictionary) -> void:
	var effect := ArenaSpellEffect.new()
	effect.event = event
	effect.origin = _grid_to_world(Vector2i(int(event.origin_x), int(event.origin_y)))
	effect.target = _grid_to_world(Vector2i(int(event.target_x), int(event.target_y)))
	effect.origin_avatar = _avatars.get(int(event.caster_id))
	effect.target_avatar = _avatars.get(int(event.target_id))
	add_child(effect)
	_spell_effects.append(effect)
	effect.tree_exited.connect(func() -> void: _spell_effects.erase(effect))


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

	var definition := ArenaData.get_definition(_arena_id)
	if definition.props.is_empty():
		for cell: Vector2i in definition.blocked_cells:
			_create_scenery(str(definition.obstacle_kind),cell)
	var index := 0
	for cell: Vector2i in definition.decorations:
		var kind := str(definition.obstacle_kind)
		if _arena_id == ArenaData.DUEL_ROOM: kind = "torch"
		elif _arena_id == ArenaData.LAVA: kind = "ember"
		elif _arena_id == ArenaData.DESERT and index % 2 == 0: kind = "rock"
		_create_scenery(kind,cell)
		index += 1

func _create_scenery(kind: String, cell: Vector2i) -> void:
	var prop := ArenaScenery.new()
	prop.z_index = -2
	add_child(prop)
	prop.setup(kind,_grid_to_world(cell),VISUAL_SCALE,cell.x+cell.y)
	_arena_props.append(prop)

func _on_arena_state() -> void:
	if ArenaNetwork.state.is_empty():
		_arena_revision = -1
		return
	var revision := int(ArenaNetwork.state.revision)
	if revision == _arena_revision: return
	_arena_revision = revision
	set_arena(str(ArenaNetwork.state.arena_id))

func set_arena(id: String) -> void:
	if not ArenaData.is_implemented(id): return
	clear_session()
	_arena_id = id
	for prop: Node2D in _arena_props:
		remove_child(prop)
		prop.queue_free()
	_arena_props.clear()
	_arena_ground.setup(_arena_id,GRID_COLUMNS,GRID_ROWS,TILE_SIZE,WORLD_ORIGIN)
	_create_arena_props()

func _create_prop(
	grh_id: int,
	grid_position: Vector2i
) -> void:
	var prop := AOProp.new()
	prop.z_index = -2

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
	if peer_id == _local_avatar_peer_id:
		_local_avatar_peer_id = 0
		_update_camera()


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
	avatar.apply_server_stats(state)


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

	if not avatar.is_alive and state.is_alive:
		avatar.setup(state, state.peer_id == multiplayer.get_unique_id(), _grid_to_world(state.grid_position))
	else:
		avatar.apply_server_stats(state)


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
	if is_local:
		_local_avatar_peer_id = state.peer_id
		_update_camera()


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


func clear_session() -> void:
	_clear_players()
	for effect in _spell_effects.duplicate():
		if is_instance_valid(effect):
			effect.queue_free()


func _clear_players() -> void:
	for avatar in _avatars.values():
		avatar.queue_free()

	_avatars.clear()
	_local_avatar_peer_id = 0
	_update_camera()


func set_pixel_scale(source_pixel_scale: float) -> void:
	scale = Vector2.ONE * source_pixel_scale / VISUAL_SCALE
	_update_camera()
