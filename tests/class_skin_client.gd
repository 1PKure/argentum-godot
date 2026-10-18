extends SceneTree
var checks := 0
var failures := 0
var main: Node
var hud: Control
var world: Node
var controller: Node
var local_id := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	main = load("res://client/scenes/client_main.tscn").instantiate()
	root.add_child(main)
	hud = main._hud
	world = main._world
	controller = main._spell_controller
	await _wait_for(func() -> bool: return controller.server_ready and hud._players.size() == 2, 20)
	local_id = root.multiplayer.get_unique_id()
	_check(controller.server_ready and hud._players.size() == 2, "Two clients negotiate class-aware cosmetic protocol 14")
	if not controller.server_ready or hud._players.size() != 2:
		await _finish()
		return
	if "--skin-observer" in OS.get_cmdline_user_args():
		await _observer()
		return
	var skins = root.get_node("Skins")
	skins.progress.storage_path = "user://class-skin-network-test.cfg"
	DirAccess.remove_absolute(skins.progress.storage_path)
	skins.progress.restore()
	for index in range(5):
		skins.progress.award("class-cosmetic-fixture-%d" % index)
	skins.changed.emit()
	var opponent: int = hud._players.keys().filter(func(id: int) -> bool: return id != local_id)[0]
	for id: int in ClassCatalog.all_ids():
		var ack_cell: Vector2i = hud._players[opponent].grid_position
		if id != 1:
			await _choose_class(id)
		await _click(hud._reserved_buttons[3])
		var panel = hud._skins_panel
		_check(panel.visible and panel._title.text.contains(str(ClassCatalog.get_profile(id).name)) and not main._local_input.is_processing(), "Class %d opens its own cosmetic collection and blocks movement" % id)
		var bodies: Array[int] = [int(ClassCatalog.get_profile(id).body_id)]
		var previews_match := true
		for skin: Dictionary in SkinCatalog.for_class(id).slice(1):
			previews_match = previews_match and panel._names[skin.id].text == str(skin.name) and panel.previews[skin.id]._body_definition == root.get_node("AOResources").get_body_definition(int(skin.body_id)) and not bodies.has(int(skin.body_id))
			bodies.append(int(skin.body_id))
		_check(previews_match, "Class %d shows three correct previews distinct from its starter" % id)
		if id == 1:
			await _click(panel.buttons.light)
		await _wait_for(func() -> bool: return hud._players[local_id].skin_id == "light" and hud._players[opponent].grid_position != ack_cell)
		_check(panel.buttons.light.text == "Equipada" and world._avatars[local_id]._player_visual._body_definition == root.get_node("AOResources").get_body_definition(int(SkinCatalog.get_skin("light", id).body_id)), "Class %d keeps the saved tier while rendering its own outfit" % id)
		if id in [1, 7, 8]:
			await _capture("class-skins-%d.png" % id)
		_key(KEY_ESCAPE, true)
		_key(KEY_ESCAPE, false)
		await process_frame
	var restored := SkinProgress.new()
	restored.storage_path = skins.progress.storage_path
	restored.restore()
	_check(restored.wins == 5 and restored.selected == "light", "Changing among all nine classes preserves victory progress and selection")
	main._disconnect_from_arena()
	await _finish()

func _observer() -> void:
	var owner: int = hud._players.keys().filter(func(id: int) -> bool: return id != local_id)[0]
	for id: int in ClassCatalog.all_ids():
		await _wait_for(func() -> bool: return hud._players.has(owner) and hud._players[owner].class_id == id and hud._players[owner].skin_id == "light", 15)
		var correct: bool = hud._players.has(owner) and hud._players[owner].class_id == id and hud._players[owner].skin_id == "light"
		if correct:
			correct = world._avatars[owner]._player_visual._body_definition == root.get_node("AOResources").get_body_definition(int(SkinCatalog.get_skin("light", id).body_id))
		_check(correct, "Remote client renders class %d reward from replicated class and skin tier" % id)
		root.get_node("PlayerNetwork").request_move(MovementRules.Direction.SOUTH if id % 2 else MovementRules.Direction.NORTH)
	await _wait_for(func() -> bool: return not hud._players.has(owner))
	main._disconnect_from_arena()
	await _finish()

func _choose_class(id: int) -> void:
	await _click(hud._reserved_buttons[0])
	var panel = hud._class_panel
	panel.selector.select(panel.selector.get_item_index(id))
	panel.selector.item_selected.emit(panel.selector.selected)
	await process_frame
	await process_frame
	await _click(panel.apply_button)
	await _wait_for(func() -> bool: return hud._players[local_id].class_id == id and not panel.visible)
	await process_frame
	await process_frame

func _wait_for(predicate: Callable, duration: float = 8.0) -> void:
	var deadline := Time.get_ticks_msec() + int(duration * 1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await create_timer(0.02).timeout


func _click(button: Control) -> void:
	await _click_at(button.get_global_rect().get_center())


func _click_world(peer_id: int) -> void:
	var avatar = world._avatars[peer_id]
	await _click_at(world.get_global_transform() * (avatar.position + Vector2(0, -25)))


func _click_at(point: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _drag(source: Control, target: Control) -> void:
	var start := source.get_global_rect().get_center()
	var finish := target.get_global_rect().get_center()
	var hover := InputEventMouseMotion.new()
	hover.position = start
	hover.global_position = start
	Input.parse_input_event(hover)
	await process_frame
	var down := InputEventMouseButton.new()
	down.position = start
	down.global_position = start
	down.button_index = MOUSE_BUTTON_RIGHT
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var previous := start
	for point: Vector2 in [start + Vector2(20, 15), finish]:
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		motion.relative = point - previous
		motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
		Input.parse_input_event(motion)
		await process_frame
		previous = point
	var up := InputEventMouseButton.new()
	up.position = finish
	up.global_position = finish
	up.button_index = MOUSE_BUTTON_RIGHT
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame
	await process_frame


func _key(code: int, pressed: bool, control: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.ctrl_pressed = control
	event.pressed = pressed
	Input.parse_input_event(event)


func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("AO_UI_CAPTURE_DIR")
	if not directory.is_empty():
		root.get_texture().get_image().save_png(directory.path_join(filename))


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + message)


func _finish() -> void:
	root.get_node("NetworkManager").stop()
	# Release active FX/audio while the engine is still processing frames.
	# Immediate process exit can leave an audio playback pending in the mixer.
	world.clear_session()
	main.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("Class skin network checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
