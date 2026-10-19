extends SceneTree
var checks := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failed += 1; print("FAIL: ",label)
func _run() -> void:
	var inputs := root.get_node("InputBindings")
	var original: String = inputs.profile_id
	inputs.use_profile("__combat_book_qa__")
	for id: int in ClassCatalog.all_ids():
		var profile := ClassCatalog.get_profile(id)
		var book := ClassCatalog.combat_book_ids(id)
		check(book.all(func(spell: int) -> bool: return ClassCatalog.can_cast(id,spell)),"curated book uses legal class spells")
		check(not book.any(func(spell: int) -> bool: return spell in [1,2,3,12,13,39,40,43,50,291]),"beginner and redundant spells hidden")
		check(book.is_empty()==(int(profile.max_mana)==0),"magic classes retain combat options")
		check(profile.bindings.all(func(spell: int) -> bool: return spell in [0,ClassCatalog.ATTACK_BINDING] or book.has(spell)),"default macros use combat book or physical attack")
	var config := ConfigFile.new()
	config.load("user://spell_hotkeys.cfg")
	var section := "profile:__combat_book_qa__:class:1"
	config.set_value(section,"0",0)
	config.set_value(section,"2",3)
	config.set_value(section,"8",12)
	config.set_value(section,"4",53)
	config.save("user://spell_hotkeys.cfg")
	var controller = load("res://client/input/spell_targeting_controller.gd").new()
	root.add_child(controller)
	check(controller.bindings[0]==0,"empty macro survives curation")
	check(controller.bindings[2]==51 and controller.bindings[8]==112,"retired beginner assignments migrate to combat defaults")
	check(controller.bindings[4]==53,"custom valid assignment preserved")
	controller.assign_hotkey(0,1)
	check(controller.bindings[0]==0,"hidden basic cannot be assigned back")
	var hud = load("res://client/ui/combat_hud.gd").new()
	root.add_child(hud)
	hud.configure_spells(controller)
	controller.class_id = 1
	controller.session_active = true
	controller.server_ready = true
	controller.changed.emit()
	hud.show_spells()
	for resolution: Vector2i in [Vector2i(1280,800),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(800,600)]:
		root.size = resolution
		hud._fit_interface()
		await process_frame
		await process_frame
		check(hud._spell_search.get_global_rect().end.y <= hud._spell_scroll.get_global_rect().position.y,"search and list do not overlap")
		check(hud._spell_scroll.size.y>=300,"book keeps six-row space %s"%resolution)
		check(hud._spell_scroll.get_global_rect().end.y<=hud._launch_button.get_global_rect().position.y,"book and Launch do not overlap")
		check(hud._health_bar.get_global_rect().end.y<hud._mana_bar.get_global_rect().position.y,"health above mana")
		check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(hud._launch_button.get_global_rect()),"Launch fits viewport")
	hud._spell_search.text = "descarga"
	hud._filter_spellbook()
	check(hud._spell_buttons[51].visible and not hud._spell_buttons[25].visible,"search filters combat book")
	hud.show_inventory()
	check(hud._minimap.visible,"inventory restores larger minimap")
	check(hud._menu_credits.text.contains("Desarrollado por Mati") and hud._menu_credits.text.contains("Créditos de recursos"),"credits separate developer and third-party art")
	hud.queue_free()
	controller.queue_free()
	inputs.use_profile(original)
	await process_frame
	print("Combat book checks: %d; failures: %d"%[checks,failed])
	quit(1 if failed else 0)
