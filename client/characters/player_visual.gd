class_name PlayerVisual
extends Node2D

@onready var body: AnimatedSprite2D = $Body
@onready var head: Sprite2D = $Head

const DEFAULT_BODY_ID := 21
const DEFAULT_HEAD_ID := 1

const ANIMATION_SPEED := 10.0
const SOURCE_TILE_SIZE := 32.0
const WORLD_TILE_SIZE := 48.0
const NORMAL_MODULATE := Color(
	1.0,
	1.0,
	1.0,
	1.0
)

const GHOST_MODULATE := Color(
	0.6,
	0.85,
	1.0,
	0.45
)
const VISUAL_SCALE := (
	WORLD_TILE_SIZE
	/ SOURCE_TILE_SIZE
)
var current_direction := Vector2.DOWN

var _body_definition: Dictionary = {}
var _head_definition: Dictionary = {}

var _head_textures: Dictionary = {}


func _ready() -> void:
	
	scale = Vector2.ONE * VISUAL_SCALE
	
	body.texture_filter = (
		CanvasItem.TEXTURE_FILTER_NEAREST
	)

	head.texture_filter = (
		CanvasItem.TEXTURE_FILTER_NEAREST
	)

	set_body_id(
		DEFAULT_BODY_ID
	)

	set_head_id(
		DEFAULT_HEAD_ID
	)

	set_movement(
		Vector2.DOWN,
		false
	)


func set_body_id(
	body_id: int
) -> void:
	_body_definition = (
		AOResources.get_body_definition(
			body_id
		)
	)

	if _body_definition.is_empty():
		return

	_build_body_animations()
	_update_head_position()


func set_head_id(
	head_id: int
) -> void:
	_head_definition = (
		AOResources.get_head_definition(
			head_id
		)
	)

	if _head_definition.is_empty():
		return

	_build_head_textures()
	_update_head()
	_update_head_position()




func set_movement(
	direction: Vector2,
	is_moving: bool
) -> void:
	if direction != Vector2.ZERO:
		var new_direction := (
			_normalize_direction(
				direction
			)
		)

		if (
			new_direction
			!= current_direction
		):
			current_direction = (
				new_direction
			)

			_update_head()

	var animation_name := (
		_get_animation_name(
			current_direction
		)
	)

	if not body.sprite_frames.has_animation(
		animation_name
	):
		return

	if (
		body.animation
		!= animation_name
	):
		body.animation = (
			animation_name
		)

	if is_moving:
		if not body.is_playing():
			body.play()
	else:
		if body.is_playing():
			body.stop()




func _build_body_animations() -> void:
	var sprite_frames := (
		SpriteFrames.new()
	)

	if sprite_frames.has_animation(
		"default"
	):
		sprite_frames.remove_animation(
			"default"
		)

	var file_num: int = int(
		_body_definition.get(
			"file_num",
			0
		)
	)

	var body_texture: Texture2D = (
		AOResources.get_texture(
			file_num
		)
	)

	if body_texture == null:
		return

	var animations: Dictionary = (
		_body_definition.get(
			"animations",
			{}
		)
	)

	for direction_name: String in animations:
		var animation_name := (
			"walk_%s"
			% direction_name
		)

		sprite_frames.add_animation(
			animation_name
		)

		sprite_frames.set_animation_speed(
			animation_name,
			ANIMATION_SPEED
		)

		sprite_frames.set_animation_loop(
			animation_name,
			true
		)

		var regions: Array = (
			animations[
				direction_name
			]
		)

		for frame_index in range(
			regions.size()
		):
			var region: Rect2 = (
				regions[
					frame_index
				]
			)

			var atlas_texture := (
				AtlasTexture.new()
			)

			atlas_texture.atlas = (
				body_texture
			)

			atlas_texture.region = (
				region
			)

			sprite_frames.add_frame(
				animation_name,
				atlas_texture
			)

	body.sprite_frames = (
		sprite_frames
	)


func _build_head_textures() -> void:
	_head_textures.clear()

	var directions: Dictionary = (
		_head_definition.get(
			"directions",
			{}
		)
	)

	for direction_name: String in directions:
		var direction_data: Dictionary = (
			directions[
				direction_name
			]
		)

		var file_num: int = int(
			direction_data.get(
				"file_num",
				0
			)
		)

		var texture: Texture2D = (
			AOResources.get_texture(
				file_num
			)
		)

		if texture == null:
			continue

		var region: Rect2 = (
			direction_data.get(
				"region",
				Rect2()
			)
		)

		var atlas_texture := (
			AtlasTexture.new()
		)

		atlas_texture.atlas = texture
		atlas_texture.region = region

		_head_textures[
			direction_name
		] = atlas_texture


func _update_head() -> void:
	var direction_name := (
		_get_direction_name(
			current_direction
		)
	)

	if not _head_textures.has(
		direction_name
	):
		return

	head.texture = (
		_head_textures[
			direction_name
		]
	)


func _update_head_position() -> void:
	if (
		_body_definition.is_empty()
		or _head_definition.is_empty()
	):
		return

	var body_size: Vector2 = (
		_body_definition.get(
			"frame_size",
			Vector2.ZERO
		)
	)

	var source_offset: Vector2 = (
		_body_definition.get(
			"head_offset",
			Vector2.ZERO
		)
	)

	var directions: Dictionary = (
		_head_definition.get(
			"directions",
			{}
		)
	)

	if not directions.has("down"):
		return

	var down_data: Dictionary = (
		directions["down"]
	)

	var head_region: Rect2 = (
		down_data.get(
			"region",
			Rect2()
		)
	)

	var head_size := (
		head_region.size
	)

	head.position = (
		source_offset
		+ (
			body_size
			- head_size
		) * 0.5
	)


func _normalize_direction(
	direction: Vector2
) -> Vector2:
	if abs(direction.x) > abs(direction.y):
		return (
			Vector2.RIGHT
			if direction.x > 0.0
			else Vector2.LEFT
		)

	return (
		Vector2.DOWN
		if direction.y > 0.0
		else Vector2.UP
	)


func _get_animation_name(
	direction: Vector2
) -> String:
	return (
		"walk_%s"
		% _get_direction_name(
			direction
		)
	)
	
func set_ghost_mode(
	enabled: bool
) -> void:
	var color := (
		GHOST_MODULATE
		if enabled
		else NORMAL_MODULATE
	)

	body.modulate = color
	head.modulate = color

func _get_direction_name(
	direction: Vector2
) -> String:
	if direction == Vector2.UP:
		return "up"

	if direction == Vector2.LEFT:
		return "left"

	if direction == Vector2.RIGHT:
		return "right"

	return "down"
