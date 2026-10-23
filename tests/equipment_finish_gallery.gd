extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1152,640)
	RenderingServer.set_default_clear_color(Color("111722"))
	var canvas := Node2D.new()
	root.add_child(canvas)
	for row in range(2):
		for column in range(4):
			var visual = load("res://client/characters/player_visual.tscn").instantiate()
			canvas.add_child(visual)
			visual.scale = Vector2.ONE * (1.5 if column < 2 else 3.0)
			visual.position = Vector2(144 + column * 288,180 + row * 290)
			var class_id := 1 if row == 0 else 3
			visual.set_loadout(class_id,ClassCatalog.default_equipment(class_id))
			visual.set_movement(Vector2.DOWN,false)
			visual.set_process(false)
			if column % 2 == 0:
				visual.body.material = null
				visual.head.material = null
				for sprite in visual._equipment.values(): sprite.material = null
			var label := Label.new()
			label.text = ("Original" if column % 2 == 0 else "Acabado") + (" · 1x" if column < 2 else " · 2x") + (" · Mago" if row == 0 else " · Guerrero")
			label.position = Vector2(50 + column * 288,35 + row * 290)
			label.add_theme_color_override("font_color",Color("d6b66a"))
			canvas.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/equipment-gesture-gallery/sprite-finish-comparison.png")
	print("Finish comparison saved")
	canvas.queue_free()
	await process_frame
	quit()
