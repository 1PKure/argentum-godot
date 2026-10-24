extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:failures += 1;print("FAIL: ",message)
func _run() -> void:
	var Visual = load("res://client/effects/arena_meditation_visual.gd")
	ArenaVisualSettings.uses_original_fx()
	var original := ArenaVisualSettings._original
	for mode: bool in [true,false]:
		ArenaVisualSettings._original = mode
		var first = Visual.new()
		root.add_child(first)
		var second = Visual.new()
		root.add_child(second)
		var sprite: AnimatedSprite2D = first.active_sprite()
		check(sprite != null and sprite.sprite_frames.get_animation_loop("default"),"both meditation modes loop")
		check(sprite.sprite_frames == second.active_sprite().sprite_frames,"meditation shares cached frames across players")
		var height := 0.0
		for index in range(sprite.sprite_frames.get_frame_count("default")):
			height = maxf(height,sprite.sprite_frames.get_frame_texture("default",index).get_height()*sprite.scale.y)
		check(height <= Visual.MAX_HEIGHT+0.01,"meditation height is bounded to108px")
		check(not first.get_meta("procedural_only",true),"meditation avoids per-frame procedural geometry")
		first.set_age(1.0)
		check(sprite.frame > 0,"cached animation advances")
		first.hide()
		check(not first.is_processing() and not sprite.is_playing(),"hidden meditation stops its animation")
		first.show()
		check(first.is_processing() and sprite.is_playing(),"visible meditation resumes")
		check((first._legacy != null) == mode and (first._modern != null) != mode,"each mode lazily loads its own distinct artwork")
		var avatar = load("res://client/characters/player_avatar.tscn").instantiate()
		root.add_child(avatar)
		var state := PlayerState.new(900,"Escala",Vector2i(5,5))
		state.is_meditating = true
		state.equipped_items = ClassCatalog.default_equipment(1)
		avatar.setup(state,true,Vector2.ZERO)
		var attached = avatar._meditation_fx
		var actual: AnimatedSprite2D = attached.active_sprite()
		var rendered_height: float = actual.sprite_frames.get_frame_texture("default",0).get_height()*actual.scale.y*attached.scale.y
		check(rendered_height <= 120.0,"the slightly enlarged meditation stays below120px at gameplay scale")
		avatar.free()
		first.free()
		second.free()
	ArenaVisualSettings._original = original
	var Blood = load("res://client/effects/arena_blood_impact.gd")
	check(Blood.MAX_DROPLETS <= 10 and Blood.SECONDS <= 0.55,"blood remains brief with a bounded droplet count")
	check(Blood.PALETTE.all(func(color: Color) -> bool:return color.r > color.g*3 and color.r > color.b*3 and color.r < 0.8),"blood palette uses dark reds rather than pink")
	await process_frame
	print("Meditation/blood visual checks: %d; failures: %d"%[checks,failures])
	quit(1 if failures else 0)
