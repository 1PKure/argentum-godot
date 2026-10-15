extends SceneTree

var failures := 0
var checks := 0
var target_role := false
var client: Node
var hud: Control
var manager: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	target_role = "--ui-target" in OS.get_cmdline_user_args()
	manager = root.get_node("NetworkManager")
	client = load("res://client/scenes/client_main.tscn").instantiate()
	root.add_child(client)
	hud = client.get_node("CombatHUD")
	var deadline := Time.get_ticks_msec() + 8000
	while hud._players.size() < 2 and Time.get_ticks_msec() < deadline:
		await create_timer(0.02).timeout
	_check(hud._players.size() == 2, "Two real clients populate HUD and minimap")
	if hud._players.size() != 2:
		_finish()
		return
	var local_id: int = root.multiplayer.get_unique_id()
	if target_role:
		deadline = Time.get_ticks_msec() + 7000
		while hud._players[local_id].current_health == 100 and Time.get_ticks_msec() < deadline:
			await create_timer(0.02).timeout
		_check(hud._players[local_id].current_health == 90, "Target HUD receives actual basic attack damage")
		_check(hud._health_label.text == "90 / 100", "Target health bar shows confirmed damage")
		_check(hud.console.get_parsed_text().contains("Tu personaje recibió 10 de daño."), "Target combat console receives confirmed hit")
		_check(hud._players[local_id].current_mana == 100, "Target mana is unchanged by physical attack")
		await create_timer(1.5).timeout
		_finish()
		return
	_click(hud._spell_button)
	await process_frame
	_check(hud._spell_panel.visible, "Real GUI click opens spell tab")
	_check(root.gui_get_focus_owner() == null, "Spell tab does not retain keyboard focus")
	_key(KEY_D, true)
	await create_timer(1.55).timeout
	_key(KEY_D, false)
	await create_timer(0.1).timeout
	_check(hud._players[local_id].grid_position == Vector2i(14, 5), "Held movement still reaches the opponent after UI click")
	_check(hud._players[local_id].current_mana == 100, "UI interaction and movement do not consume mana")
	_key(KEY_CTRL, true)
	_key(KEY_CTRL, false)
	await create_timer(0.15).timeout
	_check(hud.console.get_parsed_text().contains("recibió 10 de daño."), "Attacker console receives the same server-confirmed hit")
	_check(hud._players[local_id].current_mana == 100, "CTRL attack does not consume mana")
	if not OS.has_feature("headless") and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var output := OS.get_environment("AO_UI_CAPTURE_DIR")
		if not output.is_empty():
			root.get_texture().get_image().save_png(output.path_join("combat-ui-spells.png"))
	_click(hud._inventory_button)
	await process_frame
	_check(hud._inventory_panel.visible, "Real GUI click returns to inventory")
	_key(KEY_A, true)
	await create_timer(0.32).timeout
	_key(KEY_A, false)
	await create_timer(0.1).timeout
	_check(hud._players[local_id].grid_position.x < 14, "Movement also works after returning to inventory")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var output := OS.get_environment("AO_UI_CAPTURE_DIR")
		if not output.is_empty():
			root.get_texture().get_image().save_png(output.path_join("combat-ui-inventory.png"))
	deadline = Time.get_ticks_msec() + 3000
	while hud._players.size() == 2 and Time.get_ticks_msec() < deadline:
		await create_timer(0.02).timeout
	_check(hud._players.size() == 1, "Peer disconnect updates HUD and minimap")
	_check(hud.console.get_parsed_text().contains("salió de la arena"), "Peer disconnect appears in console")
	hud.disconnect_requested.emit()
	await process_frame
	_check(hud._players.is_empty() and not client._local_input.is_processing(), "Disconnect clears state and stops local movement")
	_finish()


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


func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + message)


func _finish() -> void:
	manager.stop()
	print("Network UI checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
