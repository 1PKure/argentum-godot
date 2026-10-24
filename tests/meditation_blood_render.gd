extends SceneTree
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1000,560)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var background := ColorRect.new()
	background.color = Color("202a28")
	background.size = Vector2(1000,560)
	root.add_child(background)
	ArenaVisualSettings.uses_original_fx()
	var original_mode := ArenaVisualSettings._original
	var calls: Array = []
	var failed := false
	for index in range(2):
		ArenaVisualSettings._original = index == 0
		var avatar = load("res://client/characters/player_avatar.tscn").instantiate()
		root.add_child(avatar)
		var state := PlayerState.new(index+1,"Original" if index == 0 else "Moderna",Vector2i(4,5))
		state.class_id = 1
		state.is_meditating = true
		state.equipped_items = ClassCatalog.default_equipment(1)
		avatar.setup(state,false,Vector2(230+index*420,230))
		avatar.set_process(false)
		avatar._player_visual.body.stop()
		var fx = avatar._meditation_fx
		fx.set_process(false)
		fx.set_age(1.5)
		fx.active_sprite().pause()
		for frame in range(5):
			await process_frame
			await RenderingServer.frame_post_draw
		calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	# Captured at the same 1x world scale as gameplay; show several impact ages.
	var Blood = load("res://client/effects/arena_blood_impact.gd")
	for index in range(3):
		var target := Node2D.new()
		target.position = Vector2(230+index*240,425)
		root.add_child(target)
		var blood = Blood.new()
		blood.setup(target,Vector2.RIGHT)
		root.add_child(blood)
		blood.set_process(false)
		blood.age = [0.04,0.14,0.27][index]
		blood.queue_redraw()
	for frame in range(5):
		await process_frame
		await RenderingServer.frame_post_draw
	var total := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	failed = total > 60
	var folder := OS.get_environment("AO_PERF_OUTPUT")
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder)
		root.get_texture().get_image().save_png(folder.path_join("meditation-blood.png"))
	print(JSON.stringify({"scope":"Native GL, two full avatars with meditation and three blood bursts; not browser FPS","meditation_scene_draw_calls":calls,"total_draw_calls":total,"failed":failed}))
	ArenaVisualSettings._original = original_mode
	quit(1 if failed else 0)
