extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(960,600)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var folder := OS.get_environment("AO_UI_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(folder)
	for id: String in ArenaData.IDS:
		var world = load("res://client/scenes/client_world.gd").new()
		root.add_child(world)
		world.scale = Vector2.ONE*0.78
		world.position = Vector2(0,14)
		world.set_arena(id)
		var first := PlayerState.new(1,"Mago",Vector2i(5,5))
		first.class_id = 1
		first.equipped_items = ClassCatalog.default_equipment(1)
		var second := PlayerState.new(2,"Cazador",Vector2i(14,5))
		second.class_id = 8
		second.equipped_items = ClassCatalog.default_equipment(8)
		world._on_snapshot_received([first.to_dictionary(),second.to_dictionary()])
		world.set_process(false)
		world._biome_ambient.set_age(19)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_webp(folder.path_join("arena-%s.webp"%id),false,0.86)
		world.queue_free()
		await process_frame
	quit()
