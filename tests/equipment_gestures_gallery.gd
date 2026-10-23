extends SceneTree
var views: Array = []
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
			visual.scale = Vector2.ONE * 4.0
			visual.position = Vector2(144 + column * 288,180 + row * 290)
			var class_id := 3 if row == 0 else 1
			visual.set_loadout(class_id,ClassCatalog.default_equipment(class_id))
			visual.set_movement([Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT][column],false)
			views.append(visual)
			var label := Label.new()
			label.text = ("Espada" if row == 0 else "Báculo") + " · " + ["Norte","Este","Sur","Oeste"][column]
			label.position = Vector2(70 + column * 288,35 + row * 290)
			label.add_theme_color_override("font_color",Color("d6b66a"))
			canvas.add_child(label)
	var output := "/tmp/equipment-gesture-gallery"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--gallery-output="): output = argument.trim_prefix("--gallery-output=")
	DirAccess.make_dir_recursive_absolute(output)
	var previous := 0.0
	for age: float in [0.0,0.06,0.12,0.20,0.35]:
		for index in range(views.size()):
			var visual = views[index]
			if age == 0:
				if index < 4: visual.play_melee_swing()
				else: visual.play_spell_cast()
			visual.set_process(false)
			visual._process(age - previous)
		previous = age
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output + "/pose-%03d.png" % roundi(age * 1000))
	print("Equipment gallery saved: ",output)
	canvas.queue_free()
	await process_frame
	quit()
