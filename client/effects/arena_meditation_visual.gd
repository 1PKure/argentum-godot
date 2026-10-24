class_name ArenaMeditationVisual
extends Node2D
## Two bounded sprites: original AO and the recovered gold whirlwind baked offline.
const MAX_HEIGHT := 108.0
const MODERN_MAX_HEIGHT := 128.0
const MODERN_DATA := "res://client/effects/modern_atlas/meditation.json"
static var _modern_frames: SpriteFrames
static var _modern_data: Dictionary = {}
var _elapsed := 0.0
var _mode := ""
var _legacy: AnimatedSprite2D
var _modern: AnimatedSprite2D

func _ready() -> void:
	set_meta("foot_anchored",true)
	set_meta("procedural_only",false)
	_sync_profile()
	visibility_changed.connect(_sync_visibility)

static func modern_frames() -> SpriteFrames:
	if _modern_frames != null:return _modern_frames
	_modern_data = JSON.parse_string(FileAccess.get_file_as_string(MODERN_DATA))
	var texture := load("res://client/effects/modern_atlas/meditation.png") as Texture2D
	_modern_frames = SpriteFrames.new()
	_modern_frames.set_animation_speed("default",float(_modern_data.fps))
	_modern_frames.set_animation_loop("default",true)
	var frame_size := Vector2(_modern_data.size[0],_modern_data.size[1])
	for index in range(int(_modern_data.count)):
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(Vector2(index%8,index/8)*frame_size,frame_size)
		_modern_frames.add_frame("default",frame)
	return _modern_frames

func _process(delta: float) -> void:
	_elapsed += delta
	_sync_profile()

func set_age(seconds: float) -> void:
	_elapsed = maxf(0,seconds)
	var sprite := active_sprite()
	if sprite != null:
		var frames := sprite.sprite_frames
		sprite.frame = int(_elapsed*frames.get_animation_speed("default"))%frames.get_frame_count("default")

func active_sprite() -> AnimatedSprite2D:
	return _legacy if _mode == "original" else _modern

func _sync_profile() -> void:
	var mode := "original" if ArenaVisualSettings.uses_original_fx() else "modern"
	if mode == _mode:return
	_mode = mode
	if mode == "original" and _legacy == null:
		_legacy = get_tree().root.get_node("AOResources").create_fx_sprite(120,true,true)
		if _legacy != null:
			_fit_sprite(_legacy)
			add_child(_legacy)
	elif mode == "modern" and _modern == null:
		_modern = AnimatedSprite2D.new()
		_modern.sprite_frames = modern_frames()
		_modern.centered = false
		_modern.position = Vector2(_modern_data.offset[0],_modern_data.offset[1])
		_modern.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_fit_sprite(_modern)
		# Offset and image must scale together to keep their zero at the feet.
		_modern.position *= _modern.scale
		add_child(_modern)
	set_meta("modern_fx",mode == "modern")
	set_meta("baked_procedural",mode == "modern")
	set_meta("concept","golden_rising_whirlwind" if mode == "modern" else "original_ao_whirlwind")
	_sync_visibility()

func max_height() -> float:
	return MODERN_MAX_HEIGHT if _mode == "modern" else MAX_HEIGHT

func _fit_sprite(sprite: AnimatedSprite2D) -> void:
	var height := 1.0
	for index in range(sprite.sprite_frames.get_frame_count("default")):
		height = maxf(height,sprite.sprite_frames.get_frame_texture("default",index).get_height())
	sprite.scale = Vector2.ONE*minf(1.2 if sprite == _modern else 1.0,max_height()/height)

func _sync_visibility() -> void:
	set_process(visible)
	for sprite: AnimatedSprite2D in [_legacy,_modern]:
		if sprite == null:continue
		sprite.visible = visible and sprite == active_sprite()
		if sprite.visible:sprite.play()
		else:sprite.pause()
