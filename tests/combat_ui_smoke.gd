extends SceneTree

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var hud = load("res://client/ui/combat_hud.gd").new()
	var player_network = root.get_node("PlayerNetwork")
	root.add_child(hud)
	await process_frame
	hud.start_session(7)
	var self_state := PlayerState.new(7, "Mati", Vector2i(4, 5))
	var other := PlayerState.new(8, "[color=red]Rival[/color]", Vector2i(15, 5))
	var messages_before: int = hud.console.entries.size()
	player_network.snapshot_received.emit([self_state.to_dictionary(), other.to_dictionary()])
	_check(hud.console.entries.size() == messages_before + 1, "Snapshot does not report initial health as damage")
	_check(hud._health_label.text == "100 / 100" and hud._mana_label.text == "100 / 100", "HUD displays local server health and mana")
	_check(hud._minimap.players.size() == 2, "Minimap uses actual synchronized players")
	_check(hud._inventory_panel.visible and not hud._spell_panel.visible, "Inventory opens first")
	hud.show_spells()
	_check(hud._spell_panel.visible and not hud._inventory_panel.visible, "Spell tab changes the visible panel")
	_check(hud._spell_panel.get_node("LaunchButton").disabled, "Launch is unavailable without a spellbook")
	var after_snapshot: int = hud.console.entries.size()
	self_state.grid_position = Vector2i(5, 5)
	player_network.player_moved.emit(self_state.to_dictionary())
	_check(hud.console.entries.size() == after_snapshot, "Movement does not spam combat console")
	other.apply_damage(10)
	player_network.player_stats_updated.emit(other.to_dictionary())
	_check(hud.console.entries[-1].text.contains("10 de daño"), "Confirmed damage is logged")
	_check(hud.console.get_parsed_text().contains("[color=red]Rival[/color]"), "Names remain literal text without BBCode injection")
	player_network.player_stats_updated.emit(other.to_dictionary())
	_check(hud.console.entries.size() == after_snapshot + 1, "Duplicate state does not duplicate a hit")
	self_state.spend_mana(10)
	player_network.player_stats_updated.emit(self_state.to_dictionary())
	_check(hud._mana_label.text == "90 / 100", "Mana bar follows a confirmed resource update")
	other.restore_health(5)
	player_network.player_stats_updated.emit(other.to_dictionary())
	_check(hud.console.entries[-1].channel == "healing", "Healing uses the healing channel")
	other.apply_damage(100)
	player_network.player_stats_updated.emit(other.to_dictionary())
	_check(hud.console.entries[-1].channel == "death", "Death is reported after confirmed damage")
	var after_death: int = hud.console.entries.size()
	player_network.player_stats_updated.emit(other.to_dictionary())
	_check(hud.console.entries.size() == after_death, "Repeated death state is silent")
	hud.console.set_channel_filter("system")
	_check(not hud.console.get_parsed_text().contains("de daño"), "System filter hides combat messages")
	hud.console.set_channel_filter("combat")
	_check(hud.console.get_parsed_text().contains("de daño") and not hud.console.get_parsed_text().contains("Arena lista"), "Combat filter preserves combat history")
	hud.console.set_channel_filter("all")
	for index in range(210):
		hud.console.append_message("Mensaje %d" % index)
	_check(hud.console.entries.size() == CombatConsole.MAX_MESSAGES, "Console history is bounded")
	_check(hud.console.entries[-1].text == "Mensaje 209", "Bounded history preserves newest messages")
	_check(_all_buttons_ignore_keyboard_focus(hud), "All interactive HUD controls preserve keyboard input")
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(800, 600)]:
		root.size = resolution
		hud._fit_interface()
		var frame_rect := Rect2(hud._frame.position, hud._frame.size * hud._frame.scale)
		_check(hud.get_viewport_rect().encloses(frame_rect), "Whole interface fits %s" % resolution)
	hud.end_session("Desconectado")
	_check(hud._players.is_empty() and hud._health_label.text == "—", "Disconnect clears stale HUD state")
	hud.start_session(9)
	_check(hud.console.entries.size() == 1, "Reconnect starts a fresh console session")
	hud.queue_free()
	await process_frame
	print("UI checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)


func _all_buttons_ignore_keyboard_focus(node: Node) -> bool:
	if node is BaseButton or node is ScrollBar:
		if node.focus_mode != Control.FOCUS_NONE:
			return false
	for child in node.get_children():
		if not _all_buttons_ignore_keyboard_focus(child):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + message)
