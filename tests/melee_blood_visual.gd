extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool,message: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: ",message)
func _frame() -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	var world = load("res://client/scenes/client_world.gd").new()
	root.add_child(world)
	world.set_process(false)
	world._biome_ambient.set_process(false)
	world._biome_ambient.set_age(19)
	world.configure_viewport(Vector2(1000,700))
	world.scale = Vector2.ONE
	world.resize_viewport(Vector2(1000,700))
	for class_id: int in [1,3,8]:
		var caster := PlayerState.new(1,"Espadachín",Vector2i(4,5))
		caster.class_id = 3
		caster.reset_preset_inventory()
		var victim := PlayerState.new(2,"Objetivo",Vector2i(5,5))
		victim.class_id = class_id
		victim.reset_preset_inventory()
		world._on_snapshot_received([caster.to_dictionary(),victim.to_dictionary()])
		for avatar in world._avatars.values(): avatar.set_process(false)
		world._on_melee_resolved({"caster_id":1,"target_id":2,"amount":100})
		check(world._blood_impacts.size()==1,"one melee contact produces one burst")
		var blood = world._blood_impacts[0]
		blood.set_process(false)
		blood._process(0.12)
		blood.visible = false
		for avatar in world._avatars.values():
			avatar._player_visual.set_process(false)
			avatar._player_visual.body.pause()
		var baseline: Image = await _frame()
		blood.visible = true
		blood.queue_redraw()
		var rendered: Image = await _frame()
		var center: Vector2 = world.get_global_transform()*world._avatars[2].position
		var changed := 0
		var bounds := Rect2i()
		for y in range(maxi(0,int(center.y)-45),mini(rendered.get_height(),int(center.y)+45)):
			for x in range(maxi(0,int(center.x)-45),mini(rendered.get_width(),int(center.x)+45)):
				var a := baseline.get_pixel(x,y)
				var b := rendered.get_pixel(x,y)
				if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>0.15:
					bounds = Rect2i(x,y,1,1) if changed==0 else bounds.merge(Rect2i(x,y,1,1))
					changed += 1
		print("Melee blood class=",class_id," pixels=",changed," bounds=",bounds.size)
		check(changed>=60 and bounds.size.x>=14 and bounds.size.y>=10,"melee blood remains visible over class%d at 1x"%class_id)
		var folder := OS.get_environment("AO_UI_CAPTURE_DIR")
		if not folder.is_empty(): rendered.save_png(folder.path_join("melee-blood-%d.png"%class_id))
		world.clear_session()
		await process_frame
	world.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("Melee blood visual checks: %d; failures: %d"%[checks,failures])
	quit(1 if failures else 0)
