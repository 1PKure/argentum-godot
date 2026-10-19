extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1400, 1380)
	root.content_scale_size = Vector2i(1400, 1380)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var background := ColorRect.new()
	background.color = Color("15232d")
	background.size = Vector2(1400, 1380)
	root.add_child(background)
	var visuals: Array[ArenaSpellVisual] = []
	var index := 0
	for id in SpellCatalog.loadout_ids():
		var spell := SpellCatalog.get_spell(id)
		var cell := Vector2((index % 7) * 200, (index / 7) * 230)
		var label := Label.new()
		label.position = cell + Vector2(35, 7)
		label.text = "%d · %s" % [id, spell.name]
		label.add_theme_font_size_override("font_size", 12)
		root.add_child(label)
		var icon := TextureRect.new()
		icon.position = cell + Vector2(5, 5)
		icon.size = Vector2(26, 26)
		icon.texture = ArenaIcons.spell(id)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		root.add_child(icon)
		var avatar = load("res://client/characters/player_visual.tscn").instantiate()
		avatar.position = cell + Vector2(100, 164)
		root.add_child(avatar)
		avatar.set_process(false)
		var visual := ArenaSpellVisual.new()
		visual.configure(spell)
		visual.position = avatar.position + Vector2(0, 30)
		root.add_child(visual)
		visuals.append(visual)
		index += 1
	var capture_directory := OS.get_environment("AO_UI_CAPTURE_DIR")
	if capture_directory.is_empty(): capture_directory = "user://spell-identity-gallery"
	DirAccess.make_dir_recursive_absolute(capture_directory)
	for fraction in [0.35, 0.65]:
		for visual in visuals: visual.set_age(visual.lifetime * fraction)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_directory.path_join("spell-identity-%d.png" % int(fraction * 100)))
	quit()
