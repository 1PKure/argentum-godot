class_name ArenaMeditationVisual
extends Node2D
## Both modes animate a cached AO atlas. Modern meditation uses a gold finish.
var _elapsed := 0.0
var _mode := ""
var _legacy: AnimatedSprite2D
func _ready() -> void:
	set_meta("foot_anchored", true)
	set_meta("procedural_only", false)
	_legacy = get_tree().root.get_node("AOResources").create_fx_sprite(120, true, true)
	if _legacy != null:
		_legacy.scale = Vector2.ONE * 1.5
		add_child(_legacy)
		_legacy.play()
	_sync_profile()
	visibility_changed.connect(func() -> void:
		set_process(visible)
		if _legacy != null:
			if visible: _legacy.play()
			else: _legacy.pause()
	)
func _process(delta: float) -> void:
	_elapsed += delta
	_sync_profile()
func set_age(seconds: float) -> void:
	_elapsed = maxf(0, seconds)
	if _legacy != null:
		var frames := _legacy.sprite_frames
		_legacy.frame = int(_elapsed * frames.get_animation_speed("default")) % frames.get_frame_count("default")
func _sync_profile() -> void:
	var mode := "original" if ArenaVisualSettings.uses_original_fx() else "lightweight"
	if mode == _mode: return
	_mode = mode
	set_meta("modern_fx", mode == "lightweight")
	set_meta("concept", "golden_ao_whirlwind" if mode == "lightweight" else "original_ao_whirlwind")
	if _legacy != null: _legacy.material = ArenaSpellFinish.material(true) if mode == "lightweight" else null
