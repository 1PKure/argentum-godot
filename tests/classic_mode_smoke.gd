extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)
func _run() -> void:
	var inputs := root.get_node("InputBindings")
	var original: String = inputs.profile_id
	inputs.use_profile("__classic_mode_qa__")
	inputs.set_classic_mode(false)
	var controller = load("res://client/input/spell_targeting_controller.gd").new()
	root.add_child(controller)
	controller.assign_hotkey(0,51)
	var saved: Array = controller.bindings.duplicate()
	controller.session_active = true
	controller.server_ready = true
	controller.aim_hotkey(0)
	check(controller.aimed_spell_id == 51,"macro still aims in macro mode")
	var hud = load("res://client/ui/combat_hud.gd").new()
	root.add_child(hud)
	hud.configure_spells(controller)
	var panel = hud._controls_panel
	panel._classic_button.pressed.emit()
	check(inputs.classic_mode and controller.aimed_spell_id == 0,"classic switch cancels old targeting")
	controller.aim_hotkey(0)
	check(controller.aimed_spell_id == 0,"classic blocks macros, including direct activation")
	controller.select_spell(25)
	controller.aim_selected()
	check(controller.aimed_spell_id == 25,"classic preserves selected spell plus Launch")
	check(controller.bindings == saved,"classic never erases custom macro assignments")
	for resolution: Vector2i in [Vector2i(1280,800),Vector2i(1280,720),Vector2i(800,600)]:
		root.size = resolution
		hud._fit_interface()
		await process_frame
		await process_frame
		check(hud._inventory_panel.visible and hud._spell_panel.visible,"classic shows objects and spells together %s"%resolution)
		check(not hud._macro_back.visible and hud._hotkey_buttons.all(func(b: Button) -> bool: return not b.visible),"classic removes macro bar %s"%resolution)
		check(hud._inventory_panel.get_global_rect().end.y < hud._spell_panel.get_global_rect().position.y,"inventory and book never overlap %s"%resolution)
		check(hud._spell_panel.get_global_rect().end.y < hud._health_bar.get_global_rect().position.y,"book stays above health %s"%resolution)
		check(hud._spell_scroll.size.y >= 140 and hud._launch_button.visible,"classic Launch and spell list remain usable %s"%resolution)
	check(panel._macro_rows.all(func(row: Control) -> bool: return not row.visible),"classic hides inactive macro configuration rows")
	controller.apply_class(6,1)
	check(inputs.classic_mode,"class change preserves classic mode")
	inputs.use_profile("__classic_other_qa__")
	inputs.set_classic_mode(false)
	check(not inputs.classic_mode,"other profile has independent mode")
	inputs.use_profile("__classic_mode_qa__")
	check(inputs.classic_mode,"classic choice survives profile reload")
	hud._play_style_button.pressed.emit()
	controller.apply_class(1,2)
	check(not inputs.classic_mode and controller.bindings == saved,"return to macros restores saved assignments")
	check(hud._inventory_panel.visible and not hud._spell_panel.visible and hud._macro_back.visible,"return restores regular inventory and macro layout")
	var registry = load("res://server/systems/player_registry.gd").new()
	root.add_child(registry)
	var caster: PlayerState = registry.add_player(701)
	var victim: PlayerState = registry.add_player(702)
	var mana := caster.current_mana
	var health := victim.current_health
	check(not SpellCatalog.is_available(4) and not ClassCatalog.combat_book_ids(1).has(4),"Dragon Breath retired from catalog and combat book")
	check(not registry.try_cast_spell(701,4,victim.grid_position,1,10000).ok and caster.current_mana == mana and victim.current_health == health,"server rejects a stale Dragon Breath request without spending or damage")
	registry.queue_free()
	hud.queue_free()
	controller.queue_free()
	inputs.use_profile(original)
	await process_frame
	print("Classic mode checks: %d; failures: %d"%[checks,failures])
	quit(1 if failures else 0)
