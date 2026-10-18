extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This regression needs a rendered viewport at the arena's 1x pixel scale.")
		quit(2)
		return
	var world = load("res://client/scenes/client_world.gd").new()
	root.add_child(world)
	world.set_process(false)
	world.configure_viewport(Vector2(1000, 700))
	world.set_pixel_scale(1)
	for sample: Dictionary in [{"class_id":1,"skin":"explorer"},{"class_id":1,"skin":"light"},{"class_id":3,"skin":"light"}]:
		var caster := PlayerState.new(1, "Arquero", Vector2i(4,5))
		var target := PlayerState.new(2, "Objetivo", Vector2i(7,5))
		target.class_id = int(sample.class_id)
		target.skin_id = str(sample.skin)
		target.reset_preset_inventory()
		world._on_snapshot_received([caster.to_dictionary(), target.to_dictionary()])
		for avatar: Node in world._avatars.values():
			avatar.set_process(false)
		world._on_spell_resolved({"action":"shot","spell_id":247,"amount":190,"words":"","caster_id":1,"target_id":2,"origin_x":4,"origin_y":5,"target_x":7,"target_y":5})
		var arrow = world._spell_effects[-1]
		arrow.set_process(false)
		arrow._process(0.17)
		_check(not arrow._blood_active, "No blood appears before projectile impact")
		arrow._process(0.01)
		arrow._process(0.12)
		_check(arrow._blood_active, "Confirmed hit holds a visible burst at 120 ms after impact")
		# Identical character pose/time: remove only the blood draw to measure
		# actual rendered pixels rather than trusting an internal active flag.
		arrow._blood_active = false
		arrow.queue_redraw()
		var baseline: Image = await _frame()
		arrow._blood_active = true
		arrow.queue_redraw()
		var with_blood: Image = await _frame()
		var center: Vector2 = world.get_global_transform() * world._avatars[2].position
		var changed := 0
		var bounds := Rect2i()
		for y in range(maxi(0,int(center.y)-45),mini(with_blood.get_height(),int(center.y)+45)):
			for x in range(maxi(0,int(center.x)-45),mini(with_blood.get_width(),int(center.x)+45)):
				var a := baseline.get_pixel(x,y)
				var b := with_blood.get_pixel(x,y)
				if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b) > 0.15:
					bounds = Rect2i(x,y,1,1) if changed == 0 else bounds.merge(Rect2i(x,y,1,1))
					changed += 1
		print("Blood pixels class=",sample.class_id," skin=",sample.skin," changed=",changed," bounds=",bounds.size)
		_check(changed >= 60 and bounds.size.x >= 14 and bounds.size.y >= 10, "Blood has measurable spread and contrast over the outfit at actual 1x scale")
		var folder := OS.get_environment("AO_UI_CAPTURE_DIR")
		if not folder.is_empty():
			with_blood.save_png(folder.path_join("blood-visible-%s-%s.png" % [sample.class_id,sample.skin]))
		var old_anchor: Vector2 = arrow._blood_origin
		world._avatars[2].position += Vector2(24,0)
		arrow._process(0.06)
		_check(arrow._blood_origin.is_equal_approx(old_anchor+Vector2(24,0)), "Rendered burst tracks the moving victim")
		arrow._process(0.45)
		_check(not arrow._blood_active, "Burst clears after 500 ms without replaying its audio")
		world.clear_session()
		await process_frame
	world.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	print("Blood visual checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)

func _frame() -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+message)
