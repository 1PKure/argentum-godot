extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 960)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var index := 0
	for biome in ArenaData.IDS:
		var panel := Control.new()
		panel.position = Vector2((index%2)*640,(index/2)*480)
		panel.size = Vector2(640,480)
		panel.clip_contents = true
		root.add_child(panel)
		var world = load("res://client/scenes/client_world.gd").new()
		panel.add_child(world)
		world.set_arena(biome)
		world.configure_viewport(Vector2(640,480))
		var actor := PlayerState.new(1,"Arena",Vector2i(9,7))
		actor.is_meditating = false
		world._on_snapshot_received([actor.to_dictionary()])
		world._local_avatar_peer_id = 1
		world._update_camera()
		world.set_process(false)
		world._biome_ambient.set_process(false)
		world._biome_ambient.set_age(19.0)
		var title := Label.new()
		title.position = Vector2(12,8)
		title.text = "Ambiente · " + biome
		title.add_theme_color_override("font_shadow_color",Color.BLACK)
		title.add_theme_constant_override("shadow_offset_x",1)
		title.add_theme_constant_override("shadow_offset_y",1)
		title.add_theme_font_size_override("font_size",18)
		panel.add_child(title)
		index += 1
	await process_frame
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("AO_UI_CAPTURE_DIR")
	if directory.is_empty(): directory = "user://biome-gallery"
	DirAccess.make_dir_recursive_absolute(directory)
	var image := root.get_texture().get_image()
	image.save_png(directory.path_join("biome-ambient-arenas.png"))
	for i in range(ArenaData.IDS.size()):
		image.get_region(Rect2i((i%2)*640,floori(i/2.0)*480,640,480)).save_png(directory.path_join("biome-ambient-%s.png" % ArenaData.IDS[i]))
	quit()
