extends SceneTree
## Native 1x review, with a real avatar for impact size/foot anchoring.

var capture_directory := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	capture_directory = OS.get_environment("AO_UI_CAPTURE_DIR")
	if capture_directory.is_empty(): capture_directory = "user://spell-identity-gallery"
	DirAccess.make_dir_recursive_absolute(capture_directory)
	_setup_window(Vector2i(1400, 1440))
	var page := Node2D.new()
	root.add_child(page)
	var visuals: Array[ArenaSpellVisual] = []
	var index := 0
	for id in SpellCatalog.loadout_ids():
		var cell := Vector2((index % 7) * 200, (index / 7) * 240)
		visuals.append(_cell(page, id, cell, Vector2(100, 173), true))
		index += 1
	for fraction in [0.12, 0.35, 0.58, 0.82]:
		for visual in visuals: visual.set_age(visual.lifetime * fraction)
		await _capture("spell-modern-all-%d.png" % roundi(fraction * 100))
	page.queue_free()
	await process_frame
	_setup_window(Vector2i(1120, 1120))
	var phases := [0.12, 0.35, 0.58, 0.82]
	var core_ids := [53, 51, 41, 13]
	var core := Node2D.new()
	root.add_child(core)
	for row in range(4):
		for column in range(4):
			var cell := Vector2(column*280, row*280)
			var visual := _cell(core, core_ids[row], cell, Vector2(140, 216), true)
			visual.set_age(visual.lifetime * phases[column])
			var label := Label.new()
			label.position = cell + Vector2(207, 6)
			label.text = "%d %%" % roundi(phases[column]*100)
			label.add_theme_font_size_override("font_size", 13)
			core.add_child(label)
	await _capture("spell-modern-core-phases.png")
	# Draw every early/late frame as well, catching zero-sized polygons and
	# other rendering errors which a headless geometry-only test cannot see.
	for fraction in [0.001, 0.05, 0.09, 0.18, 0.48, 0.72, 0.96, 1.01]:
		for child in core.get_children():
			if child is ArenaSpellVisual: child.set_age(child.lifetime*fraction)
		await process_frame
		await RenderingServer.frame_post_draw
	quit()

func _setup_window(dimensions: Vector2i) -> void:
	root.size = dimensions
	root.content_scale_size = dimensions
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.transparent_bg = false
	RenderingServer.set_default_clear_color(Color("15232d"))

func _cell(page: Node2D, id: int, cell: Vector2, avatar_at: Vector2, show_name: bool) -> ArenaSpellVisual:
	var spell := SpellCatalog.get_spell(id)
	if show_name:
		var label := Label.new()
		label.position = cell + Vector2(35, 7)
		label.text = "%d · %s" % [id, spell.name]
		label.add_theme_font_size_override("font_size", 12)
		page.add_child(label)
	var icon := TextureRect.new()
	icon.position = cell + Vector2(5, 5)
	icon.size = Vector2(26, 26)
	icon.texture = ArenaIcons.spell(id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	page.add_child(icon)
	var avatar = load("res://client/characters/player_visual.tscn").instantiate()
	avatar.position = cell + avatar_at
	page.add_child(avatar)
	avatar.set_process(false)
	var visual := ArenaSpellVisual.new()
	visual.configure(spell)
	visual.position = avatar.position + Vector2(0, 30)
	page.add_child(visual)
	return visual

func _capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_directory.path_join(filename))
