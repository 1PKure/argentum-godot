extends SceneTree

var checks := 0
var failures := 0
var main: Node
var hud: Control
var controller: Node
var local_id := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	main = load("res://client/scenes/client_main.tscn").instantiate()
	root.add_child(main)
	hud = main._hud
	controller = main._spell_controller
	await _wait_for(func() -> bool: return controller.server_ready and hud._players.size() == 1)
	_check(controller.server_ready and hud._players.size() == 1, "Real client connects to the dedicated server")
	if not controller.server_ready:
		await _finish()
		return
	local_id = root.multiplayer.get_unique_id()
	hud.show_spells()
	_key(KEY_1, true)
	_key(KEY_1, false)
	await process_frame
	_check(controller.aimed_spell_id > 0, "Combat cursor is active before opening the menu")
	await _click(hud._menu_button)
	_check(hud._menu_panel.visible and not main._local_input.is_processing() and controller.aimed_spell_id == 0, "Menu cancels targeting and pauses movement input")
	await _capture("hud-clean-menu.png")
	var tile: Vector2i = hud._players[local_id].grid_position
	var health: int = hud._players[local_id].current_health
	var mana: int = hud._players[local_id].current_mana
	for key: Key in [KEY_1, KEY_CTRL, KEY_M, KEY_Q, KEY_E, KEY_SPACE]:
		_key(key, true)
		_key(key, false)
	_key(KEY_D, true)
	await create_timer(0.25).timeout
	_key(KEY_D, false)
	_check(hud._players[local_id].grid_position == tile and hud._players[local_id].current_health == health and hud._players[local_id].current_mana == mana and controller.aimed_spell_id == 0 and not hud._players[local_id].is_meditating, "Movement, attacks, macros and recovery keys do not act behind the menu")
	await _click(hud._menu_close_button)
	_check(not hud._menu_panel.visible and main._local_input.is_processing(), "Volver closes the modal and resumes movement input")
	await _click(hud._menu_button)
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await process_frame
	_check(not hud._menu_panel.visible and main._local_input.is_processing(), "Escape closes the menu without capturing later controls")
	for index in range(50):
		root.get_node("PlayerNetwork").request_debug_damage()
	await _wait_for(func() -> bool: return not hud._players[local_id].is_alive)
	_check(hud._status_label.z_index > hud._bottom_back.z_index, "Status text draws above the footer background")
	_check(hud._stats_button.visible and not hud._stats_button.disabled and hud._status_label.text == "Fantasma", "Ghost shows one status and a separate respawn action")
	_check(hud._name_label.text == hud._players[local_id].display_name and not hud._name_label.text.contains("Fantasma"), "Character name does not duplicate class or ghost state")
	await _capture("hud-clean-ghost.png")
	await _click(hud._menu_button)
	await _click(hud._stats_button)
	await create_timer(0.15).timeout
	_check(not hud._menu_panel.visible and not hud._players[local_id].is_alive, "Clicking a covered respawn button only dismisses the backdrop")
	await _click(hud._stats_button)
	await _wait_for(func() -> bool: return hud._players[local_id].is_alive)
	_check(hud._players[local_id].is_alive and not hud._stats_button.visible, "Respawn works after closing the menu and hides its inactive action")
	# Use the longest existing status case while checking footer and content bounds.
	hud._status_label.text = "Paralizado · Inmovilizado · Putrefacción"
	hud._spell_status.text = "Este hechizo requiere un sistema que todavía no está disponible en la arena de pruebas."
	hud.set_menu_opened(true)
	for resolution: Vector2i in [Vector2i(1280, 800), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(800, 600)]:
		root.size = resolution
		hud._fit_interface()
		await process_frame
		await process_frame
		_check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(hud._menu_card.get_global_rect()), "Menu card fits %s" % resolution)
		_check(hud._menu_panel.z_index > hud._bottom_back.z_index, "Menu draws above footer at %s" % resolution)
		_check(not hud._menu_credits.get_global_rect().intersects(hud._menu_disconnect_button.get_global_rect()), "Credits and disconnect do not overlap at %s" % resolution)
		_check(not hud._menu_close_button.get_global_rect().intersects(hud._menu_disconnect_button.get_global_rect()), "Menu actions have distinct hit areas at %s" % resolution)
		_check(not hud._use_button.get_global_rect().intersects(hud._meditate_button.get_global_rect()) and Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(hud._use_button.get_global_rect()), "Use and Meditate fit without overlap at %s" % resolution)
		_check(not hud._status_label.get_global_rect().intersects(hud._meditate_button.get_global_rect()) and not hud._status_label.get_global_rect().intersects(hud._mana_label.get_global_rect()), "Status has a dedicated footer row at %s" % resolution)
		_check(not hud._spell_status.get_global_rect().intersects(hud._launch_button.get_global_rect()) and not hud._spell_status.get_global_rect().intersects(hud._spell_scroll.get_global_rect()), "Long spell status stays separate from list and Launch at %s" % resolution)
	root.size = Vector2i(1280, 800)
	hud._fit_interface()
	await process_frame
	await process_frame
	await _capture("hud-clean-layout.png")
	hud.set_menu_opened(false)
	await _click(hud._reserved_buttons[3])
	for resolution: Vector2i in [Vector2i(1280, 800), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(800, 600)]:
		root.size = resolution
		hud._fit_interface()
		await process_frame
		await process_frame
		var card: Control = hud._skins_panel.get_child(1).get_child(0)
		_check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(card.get_global_rect()), "Skin collection fits %s" % resolution)
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await process_frame
	_check(not hud._skins_panel.visible and main._local_input.is_processing(), "Skin dialog closes cleanly after responsive layout")
	root.size = Vector2i(1280, 800)
	hud._fit_interface()
	await process_frame
	await process_frame
	hud.set_menu_opened(true)
	await process_frame
	await process_frame
	await _click(hud._menu_disconnect_button)
	_check(not hud._menu_panel.visible and hud._players.is_empty() and not main._local_input.is_processing(), "Disconnect from menu closes the modal and clears the session")
	await _finish()

func _wait_for(predicate: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 8000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await create_timer(0.02).timeout

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _click(button: Control) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await process_frame

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("AO_UI_CAPTURE_DIR")
	if not directory.is_empty():
		root.get_texture().get_image().save_png(directory.path_join(filename))

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + message)

func _finish() -> void:
	root.get_node("NetworkManager").stop()
	main._world.clear_session()
	main.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("HUD layout checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
