extends SceneTree
var main: Node
var hud: Control
var net: Node
var controller: Node
var role := "host"
var directory := ""
var checks := 0
var failed := 0
var spells: Array = []
var drinks: Array = []
func _initialize() -> void: call_deferred("_run")
func _check(value: bool, label: String) -> void:
	checks += 1
	if not value: failed += 1
	print(("PASS" if value else "FAIL")+" ["+role+"]: "+label)
func _wait(predicate: Callable, seconds: float = 15.0) -> bool:
	await process_frame
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		await create_timer(0.025).timeout
	return false
func _path(name_value: String) -> String: return directory.path_join(name_value)
func _mark(name_value: String) -> void:
	var file := FileAccess.open(_path(name_value),FileAccess.WRITE)
	file.store_string("ok")
func _find_button(parent: Node, text_value: String) -> Button:
	if parent.is_queued_for_deletion(): return null
	if parent is Button and parent.text == text_value and parent.is_visible_in_tree(): return parent
	for child in parent.get_children():
		var result := _find_button(child,text_value)
		if result != null: return result
	return null
func _click(button: Control) -> void:
	await process_frame
	await process_frame
	if button == null:
		_check(false,"Required GUI button exists")
		return
	await _mouse(button.get_global_rect().get_center())
func _mouse(point: Vector2, mouse_button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = mouse_button
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await process_frame
func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func _tap(code: Key) -> void:
	_key(code,true)
	await process_frame
	_key(code,false)
	await process_frame
func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_path(filename))
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--lobby-role="): role = argument.trim_prefix("--lobby-role=")
		if argument.begins_with("--lobby-markers="): directory = argument.trim_prefix("--lobby-markers=")
	ProjectSettings.set_setting("network/server_url","ws://127.0.0.1:7777")
	net = root.get_node("LobbyNetwork")
	root.get_node("InputBindings").use_profile("__native_revision_"+role)
	root.get_node("InputBindings").reset_defaults()
	root.get_node("SpellNetwork").spell_resolved.connect(func(event: Dictionary) -> void: spells.append(event.duplicate(true)))
	root.get_node("RecoveryNetwork").action_resolved.connect(func(event: Dictionary) -> void:
		if str(event.action).ends_with("potion"): drinks.append(event.duplicate(true))
	)
	main = load("res://client/scenes/client_main.tscn").instantiate()
	root.add_child(main)
	hud = main._hud
	controller = main._spell_controller
	_check(await _wait(func() -> bool: return net.available),"exported PCK negotiates protocol24")
	if not net.available: await _finish(); return
	var ranking := root.get_node("RankingNetwork")
	_check(await _wait(func() -> bool: return ranking.registered),"ranking profile registered with dedicated server")
	main._lobby_panel._nickname.text = ""
	if role == "host":
		await _click(main._lobby_panel._create_button)
		_check(net.room.is_empty() and not main._lobby_panel._feedback.is_empty(),"Create requires an explicit nickname before opening Ranking")
	main._lobby_panel._nickname.text = "Polish_"+role
	if role=="solo":
		await _solo()
		await _finish()
		return
	if role=="host":
		await _click(main._lobby_panel._name)
		main._lobby_panel._name.text = "Native GUI"
		main._lobby_panel._arena.select(0)
		await _click(main._lobby_panel._create_button)
	else:
		_check(await _wait(func() -> bool: return not net.rooms.is_empty()),"room appears in browser")
		await _click(_find_button(main._lobby_panel,"Unirse"))
	_check(await _wait(func() -> bool: return net.room.get("members",[]).size()==2 and not net.pending),"actual Create/Join clicks enter a room")
	if net.room.is_empty(): await _finish(); return
	_check(net.room.members.any(func(member: Dictionary) -> bool: return str(member.name)=="Polish_"+role),"Create/Join uses chosen nickname without first opening Ranking")
	await _click(_find_button(main._lobby_panel,"Ranking"))
	_check(main._lobby_panel._ranking.visible,"Ranking button opens shared-theme panel")
	_check(main._lobby_panel._ranking._rows.get_child_count() >= 2,"ranking includes header and honorary first place")
	if role == "host": await _capture("ranking.png")
	await _click(_find_button(main._lobby_panel._ranking,"Volver"))
	_check(not main._lobby_panel._ranking.visible,"Volver closes ranking and returns to lobby")

	_check(not main._local_input.is_processing(),"waiting room blocks movement")
	if role=="host": await _host()
	else: await _guest()
	await _finish()
func _host() -> void:
	var chat := root.get_node("ChatNetwork")
	await _click(main._lobby_panel._chat.input)
	main._lobby_panel._chat.input.text = "Hola desde el lobby"
	await _tap(KEY_ENTER)
	_check(await _wait(func() -> bool: return chat.messages.size()>=2 and not chat.pending),"real lobby chat Enter exchanges messages with second player")
	_check(main._lobby_panel._chat.input.text.is_empty(),"confirmed lobby send clears draft")
	_check(await _wait(func() -> bool: return _find_button(main._lobby_panel,"Ver preset") != null),"preset action is rendered before clicking")
	await _capture("lobby-waiting.png")
	await _click(_find_button(main._lobby_panel,"Ver preset"))
	_check(hud._class_panel.visible and hud._class_panel.layer > main._lobby_panel.layer,"actual preset click opens modern class window above lobby")
	await _capture("lobby-presets.png")
	await _click(_find_button(hud._class_panel,"Volver"))
	await _click(_find_button(main._lobby_panel,"Listo"))
	_check(await _wait(func() -> bool:
		for member: Dictionary in net.room.members:
			if int(member.peer_id)==root.multiplayer.get_unique_id(): return bool(member.ready)
		return false
	),"actual Listo click marks host ready")
	await _click(_find_button(main._lobby_panel,"Skins"))
	_check(hud._skins_panel.visible and hud._skins_panel.layer > main._lobby_panel.layer,"actual Skins click opens collection above lobby")
	_mark("host-skins-open")
	_check(await _wait(func() -> bool: return str(net.room.phase)=="countdown"),"guest ready starts countdown")
	_check(not hud._skins_panel.visible and not main._local_input.is_processing(),"countdown closes Skins and blocks input")
	_check(await _wait(func() -> bool: return str(net.room.phase)=="fighting"),"countdown reaches real combat")
	await create_timer(0.7).timeout
	_check(main._local_input.is_processing() and not controller.input_blocked,"actual gameplay input is active after Ya")
	var local_id := root.multiplayer.get_unique_id()
	await _tap(KEY_ENTER)
	_check(hud._chat_input.visible and hud._chat_input.has_focus() and controller.input_blocked and not main._local_input.is_processing(),"Enter opens combat chat and blocks combat controls")
	var typing_cell: Vector2i = hud._players[local_id].grid_position
	var typing_casts := spells.size()
	var typing_potions := drinks.size()
	await _tap(KEY_1)
	_key(KEY_D,true)
	_key(KEY_SPACE,true)
	await create_timer(0.3).timeout
	_key(KEY_D,false)
	_key(KEY_SPACE,false)
	_check(hud._players[local_id].grid_position==typing_cell and spells.size()==typing_casts and drinks.size()==typing_potions,"typing WASD, macros and Space never moves, casts or drinks")
	await _tap(KEY_ESCAPE)
	_check(not hud._chat_input.visible and not hud._menu_panel.visible and not controller.input_blocked,"Escape cancels draft and restores combat without opening Menu")
	await _click(hud._chat_button)
	hud._chat_input.text = "Mensaje en combate"
	await _tap(KEY_ENTER)
	_check(await _wait(func() -> bool: return not hud._chat_input.visible and chat.messages.size()>=3),"combat Enter sends server chat and resumes gameplay")
	_check(main._world._speech.entries.has(main._world._avatars[local_id].get_instance_id()),"live message appears above speaker")
	await _capture("combat-chat.png")
	var old_cell: Vector2i = hud._players[local_id].grid_position
	_key(KEY_D,true)
	await create_timer(0.32).timeout
	_key(KEY_D,false)
	await create_timer(0.2).timeout
	_check(hud._players[local_id].grid_position.x > old_cell.x,"WASD changes authoritative player position")
	var opponent := 0
	for member: Dictionary in net.room.members:
		if int(member.peer_id)!=local_id: opponent = int(member.peer_id)
	await _tap(KEY_1)
	_check(controller.aimed_spell_id==controller.bindings[0] and controller.aimed_spell_id>0,"macro1 prepares an actual targeting cursor")
	var mana_before: int = hud._players[local_id].current_mana
	var avatar = main._world._avatars[opponent]
	await _mouse(main._world.get_global_transform()*(avatar.position+Vector2(0,-25)))
	_check(await _wait(func() -> bool: return not spells.is_empty()),"world click resolves a real spell on server")
	_check(hud._players[local_id].current_mana < mana_before,"spell spends authoritative mana")
	_check(main._world._speech.entries[main._world._avatars[local_id].get_instance_id()].kind=="spell","real cast replaces chat overhead with spell words")
	await _tap(KEY_1)
	var aimed: int = controller.aimed_spell_id
	var mana_spent: int = hud._players[local_id].current_mana
	var potion_click_before: int = root.get_node("UIClickAudio").played_count
	await _click(hud._inventory_slots[1])
	_check(root.get_node("UIClickAudio").played_count==potion_click_before,"actual inventory potion click has no generic UI sound")
	_check(await _wait(func() -> bool: return hud._players[local_id].current_mana > mana_spent),"inventory blue click drinks potion")
	_check(controller.aimed_spell_id==aimed and hud._inventory_panel.visible,"inventory potion preserves macro cursor and inventory tab")
	drinks.clear()
	_key(KEY_SPACE,true)
	await create_timer(0.8).timeout
	_key(KEY_SPACE,false)
	await create_timer(0.2).timeout
	_check(drinks.size()>=1 and drinks.any(func(event: Dictionary) -> bool: return str(event.source)=="use"),"Space uses selected blue while macro remains prepared")
	_check(controller.aimed_spell_id==aimed and not root.get_node("RecoveryNetwork").using_selected,"release stops drinking and preserves spell cursor")
	await _layout_and_controls()
	await _capture("combat-modern.png")
	controller.cancel_targeting()
	await _click(hud._spell_button)
	_check(hud._spell_panel.visible,"modern spellbook opens by GUI click")
	_check(hud._spell_search.get_global_rect().end.y <= hud._spell_scroll.get_global_rect().position.y,"search stays above the first spell row")
	_check(hud._spell_scroll.size.y>=248 and not hud._minimap.visible,"manual-cast book prioritizes at least six rows")
	_check([1,2,3,12,13,291].all(func(id: int) -> bool: return not hud._spell_buttons.has(id)),"starter spells absent from combat book")
	var before_order: Array[int] = hud._book_order.duplicate()
	var before_macros: Array = controller.bindings.duplicate()
	var from_button: Control = hud._spell_buttons[before_order[0]]
	var to_button: Control = hud._spell_buttons[before_order[1]]
	var start := from_button.get_global_rect().get_center()
	var finish := to_button.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = start
	Input.parse_input_event(press)
	await process_frame
	var drag := InputEventMouseMotion.new()
	drag.position = finish
	drag.button_mask = MOUSE_BUTTON_MASK_RIGHT
	Input.parse_input_event(drag)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	release.position = finish
	Input.parse_input_event(release)
	await process_frame
	_check(hud._book_order[1]==before_order[0],"actual right drag reorders spellbook")
	_check(controller.bindings==before_macros and controller.aimed_spell_id==0,"book management preserves macros without casting")
	_check(ArenaSpellBookOrder.load_order(root.get_node("InputBindings").profile_id,controller.class_id)==hud._book_order,"right drag persists class book order")
	await _click(hud._inventory_button)
	await _click(hud._spell_button)
	_check(hud._book_order[1]==before_order[0],"tab changes retain book order")
	ArenaSpellBookOrder.save_order(root.get_node("InputBindings").profile_id,controller.class_id,before_order)
	var book_casts := spells.size()
	await _click(hud._spell_buttons[25])
	await _click(hud._launch_button)
	_check(controller.aimed_spell_id==25,"book selection plus real Launch prepares target cursor")
	var book_target = main._world._avatars[opponent]
	await _mouse(main._world.get_global_transform()*(book_target.position+Vector2(0,-25)))
	_check(await _wait(func() -> bool: return spells.size()>book_casts),"manual book Launch resolves actual server spell")

	await _capture("combat-spells.png")
	for hit in range(4):
		if str(net.room.phase)=="result": break
		await create_timer(1.05).timeout
		var before := spells.size()
		controller.aim_spell(51)
		var victim = main._world._avatars[opponent]
		await _mouse(main._world.get_global_transform()*(victim.position+Vector2(0,-25)))
		await _wait(func() -> bool: return spells.size()>before or str(net.room.phase)=="result",2)
	_check(await _wait(func() -> bool: return str(net.room.phase)=="result"),"actual combat ends in result")
	_check(not main._lobby_panel._surface.visible and hud._round_strip.visible,"result stays in arena with inline rematch")
	_check(main._world._avatars[opponent]._player_visual._ghost_sprite.visible,"opponent ghost visible after real death")
	await _capture("ghost-result.png")
	_mark("host-result")
	await _click(hud._rematch_button)
	_check(await _wait(func() -> bool: return str(net.room.phase)=="fighting",20),"real ready clicks restart round without lobby")
	_check(not main._world._avatars[opponent].is_ghost and not main._lobby_panel._surface.visible,"rematch restores living players in arena")
	await _click(hud._menu_button)
	await _click(hud._menu_disconnect_button)
	_check(await _wait(func() -> bool: return net.room.is_empty() and not net.pending),"Menu Exit Room returns to browser")
	_check(root.get_node("NetworkManager").is_network_connected() and main._world._avatars.is_empty(),"leaving room preserves connection and clears world")
	await create_timer(0.2).timeout
	main._lobby_panel._name.text = "Second room"
	main._lobby_panel._arena.select(ArenaData.IDS.find("desert"))
	await _click(main._lobby_panel._create_button)
	_check(await _wait(func() -> bool: return str(net.room.get("arena_id",""))=="desert" and not net.pending),"GUI creates a different arena on same connection")
	_check(int(root.get_node("ArenaNetwork").state.revision)==0 and main._world._arena_id=="desert","new map loads even with same revisionzero")
	_check(chat.messages.is_empty(),"leaving/joining another room clears old chat history")
	_mark("host-second-room")
	_check(await _wait(func() -> bool: return FileAccess.file_exists(_path("guest-done"))),"remaining guest confirms own room unchanged")
	await _click(_find_button(main._lobby_panel,"Salir de la sala"))
	await _wait(func() -> bool: return net.room.is_empty() and not net.pending)
	_mark("host-done")
func _guest() -> void:
	var chat := root.get_node("ChatNetwork")
	_check(await _wait(func() -> bool: return chat.messages.size()>=1),"guest receives host lobby message")
	await _click(main._lobby_panel._chat.input)
	main._lobby_panel._chat.input.text = "Hola, te leo"
	await _click(main._lobby_panel._chat.send_button)
	_check(await _wait(func() -> bool: return not chat.pending and chat.messages.size()>=2),"guest replies using real Enviar button")
	_check(await _wait(func() -> bool: return FileAccess.file_exists(_path("host-skins-open"))),"host reviews Skins before round")
	await _click(_find_button(main._lobby_panel,"Listo"))
	_check(await _wait(func() -> bool: return str(net.room.phase)=="fighting"),"guest GUI Listo completes countdown")
	_check(await _wait(func() -> bool: return not spells.is_empty()),"guest receives host macro spell")
	_check(await _wait(func() -> bool: return FileAccess.file_exists(_path("host-result")),65),"guest sees completed round")
	_check(not main._lobby_panel._surface.visible and main._world._avatars[root.multiplayer.get_unique_id()].is_ghost,"defeated guest stays visible as ghost")
	await _click(hud._rematch_button)
	_check(await _wait(func() -> bool: return str(net.room.phase) in ["countdown","fighting"]),"guest readies rematch directly in arena")
	_check(await _wait(func() -> bool: return FileAccess.file_exists(_path("host-second-room")),55),"host creates second room")
	_check(str(net.room.arena_id)=="forest" and main._world._arena_id=="forest" and net.room.members.size()==1,"host departure leaves guest in original map")
	_check(int(net.room.owner_id)==root.multiplayer.get_unique_id(),"guest inherits host after departure")
	_mark("guest-done")
	await _wait(func() -> bool: return FileAccess.file_exists(_path("host-done")))

func _layout_and_controls() -> void:
	await _click(hud._menu_button)
	await _click(hud._volume_sliders.effects)
	_check(ArenaAudioMix.volume("effects") == hud._volume_sliders.effects.value and ArenaAudioMix.volume("effects") < 100,"real menu slider changes effects volume immediately")
	var choice = hud._menu_panel.find_child("SpellVisualMode",true,false)
	var metrics = hud._menu_panel.find_child("PerformanceMetrics",true,false)
	_check(choice != null and metrics != null,"visual selector and performance switch exist")
	await _click(choice)
	_check(ArenaVisualSettings.uses_original_fx(),"real click selects original atlas FX")
	await _click(metrics)
	_check(ArenaVisualSettings.metrics,"real checkbox enables performance meter")
	await process_frame
	_check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(hud._menu_card.get_global_rect()),"menu fits with visual controls")
	await _capture("menu-audio.png")
	await _click(choice)
	_check(not ArenaVisualSettings.uses_original_fx(),"real click restores modern FX")
	hud._volume_sliders.effects.value = 100
	await _click(hud._menu_close_button)
	var input := root.get_node("InputBindings")
	for resolution: Vector2i in [Vector2i(1280,800),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(800,600)]:
		root.size = resolution
		hud._fit_interface()
		await process_frame
		await process_frame
		_check(hud._mana_bar.get_global_rect().position.y > hud._health_bar.get_global_rect().end.y,"mana always under health %s"%resolution)
		_check(hud._console_back.get_global_rect().end.y < hud.game_area.get_global_rect().position.y,"console above arena %s"%resolution)
		_check(hud._health_bar.get_global_rect().end.y < hud._menu_button.get_global_rect().position.y and hud._health_bar.get_global_rect().position.y > hud._inventory_panel.get_global_rect().end.y,"health directly above options %s"%resolution)
		_check(not hud._disconnect_button.get_global_rect().intersects(hud._menu_button.get_global_rect()) and Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(hud._disconnect_button.get_global_rect()),"footer disconnect has its own hit area %s"%resolution)
		_check(hud._minimap.size.x >= 160 and hud._minimap.get_global_rect().position.y > hud._mana_bar.get_global_rect().end.y,"larger minimap separate from inventory %s"%resolution)
	root.size = Vector2i(1280,800)
	hud._fit_interface()
	await process_frame
	await process_frame
	_check(hud._inventory_slots.filter(func(slot: Control) -> bool: return slot.visible).size()>=24 and hud._inventory_panel.size.y>128,"inventory grows into the available HUD height")
	_check(hud._bottom_back.position.y-hud._inventory_panel.position.y-hud._inventory_panel.size.y==12,"resources sit directly below inventory")
	_check(hud._footer_back.position.y>hud._bottom_back.position.y+hud._bottom_back.size.y,"footer buttons have their own panel")
	hud._inventory_layout.actions[41]="item:126"
	hud._compact_inventory_slots()
	await process_frame
	_check(hud._inventory_slots[41].visible,"occupied legacy slot stays accessible")
	hud._inventory_scroll.scroll_vertical = 1000
	await process_frame
	_check(hud._inventory_panel.get_global_rect().encloses(hud._inventory_slots[41].get_global_rect()),"last inventory slot reachable by scroll")
	hud._inventory_scroll.scroll_vertical = 0
	hud._inventory_layout.actions[41]=""
	hud._compact_inventory_slots()
	var saved: int = controller.bindings[0]
	await _mouse(hud._hotkey_buttons[0].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
	_check(controller.bindings[0]==0 and hud._hotkey_buttons[0].icon==null,"real right click clears macro without cast")
	controller.apply_class(controller.class_id,902)
	_check(controller.bindings[0]==0,"cleared macro survives a preset refresh")
	controller.assign_hotkey(0,saved)
	await _click(hud._menu_button)
	_check(not net.is_paused(),"human PvP keeps running while menu is open")
	_check(hud._menu_credits.text.contains("Desarrollado por Matias Pulido") and hud._menu_credits.text.contains("Créditos de recursos"),"developer and resource credits are separate")
	await _click(hud._controls_button)
	_check(hud._controls_panel.visible and not main._local_input.is_processing(),"Controls opens and blocks gameplay")
	var bind_button: Control = hud._controls_panel._buttons["use_selected"]
	var bind_scroll: ScrollContainer = bind_button.get_parent().get_parent().get_parent()
	bind_scroll.ensure_control_visible(bind_button)
	await process_frame
	await process_frame
	await _click(bind_button)
	await _tap(KEY_K)
	_check(input.label_for("use_selected")=="K","real GUI input rebinds Use")
	await _capture("controls-modern.png")
	await _click(_find_button(hud._controls_panel,"Volver"))
	var count := spells.size()
	await _tap(KEY_1)
	for peer: int in hud._players:
		if peer != root.multiplayer.get_unique_id():
			var avatar = main._world._avatars[peer]
			await _mouse(main._world.get_global_transform()*(avatar.position+Vector2(0,-25)))
			break
	_check(await _wait(func() -> bool: return spells.size()>count),"spell spends mana before testing rebound Use")
	drinks.clear()
	_key(KEY_K,true)
	await create_timer(0.6).timeout
	_key(KEY_K,false)
	await create_timer(0.15).timeout
	_check(drinks.any(func(event: Dictionary) -> bool: return str(event.source)=="use") and not root.get_node("RecoveryNetwork").using_selected,"rebound Use drinks and releases")
	input.reset_defaults()

func _solo() -> void:
	var click_before: int = root.get_node("UIClickAudio").played_count
	main._lobby_panel._name.text = "Pause native"
	await _click(main._lobby_panel._create_button)
	_check(await _wait(func() -> bool: return not net.room.is_empty() and not net.pending),"solo creates room")
	_check(root.get_node("UIClickAudio").played_count>click_before,"actual lobby Create button plays UI click")
	await _click(_find_button(main._lobby_panel,"Añadir bot"))
	_check(await _wait(func() -> bool: return bool(net.room.get("bot_enabled",false)) and not net.pending),"actual Add Bot enables bot")
	await _click(_find_button(main._lobby_panel,"Listo"))
	_check(await _wait(func() -> bool: return str(net.room.get("phase",""))=="fighting"),"solo Ready starts round")
	click_before=root.get_node("UIClickAudio").played_count
	await _click(hud._menu_button)
	_check(await _wait(func() -> bool: return net.is_paused() and not net.pause_pending),"actual Menu pauses the server bot room")
	_check(root.get_node("UIClickAudio").played_count>click_before,"actual game Menu button plays UI click")
	var id: int = root.multiplayer.get_unique_id()
	var before := {}
	for peer in hud._players: before[peer] = hud._players[peer].to_dictionary()
	_check(main._world._game_paused and not main._local_input.is_processing(),"client animations and input freeze with server")
	_key(KEY_D,true)
	_key(KEY_SPACE,true)
	await create_timer(1.1).timeout
	_key(KEY_D,false)
	_key(KEY_SPACE,false)
	var unchanged := true
	for peer in before:
		var after: Dictionary = hud._players[peer].to_dictionary()
		for field in ["grid_x","grid_y","current_health","current_mana"]:
			if before[peer].get(field)!=after.get(field): unchanged = false
	_check(unchanged,"bot, health, mana and player movement stay frozen")
	await _capture("bot-menu-paused.png")
	await _click(hud._controls_button)
	_check(net.is_paused() and hud._controls_panel.visible,"opening Controls keeps same bot pause")
	await _click(_find_button(hud._controls_panel,"Volver"))
	_check(await _wait(func() -> bool: return not net.is_paused() and not net.pause_pending),"closing Controls resumes bot room")
	_check(not main._world._game_paused and main._local_input.is_processing(),"resume restores animation and input")
	await _click(hud._menu_button)
	await _click(hud._menu_close_button)
	_check(await _wait(func() -> bool: return not net.is_paused() and not net.pause_pending),"rapid Menu/Back ends resumed")
	var old_round: String = str(net.room.round_id)
	hud._bot_panel.open_panel()
	_check(await _wait(func() -> bool: return net.is_paused()),"bot settings pause active practice")
	await _click(hud._bot_panel.start_button)
	_check(await _wait(func() -> bool: return str(net.room.round_id)!=old_round and str(net.room.phase)=="countdown"),"Restart button resets active practice with a fresh countdown")
	_check(await _wait(func() -> bool: return str(net.room.phase)=="fighting"),"restarted practice resumes actual combat")
	hud._bot_panel.open_panel()
	_check(await _wait(func() -> bool: return net.is_paused()),"bot settings can pause the restarted round")
	await _click(hud._bot_panel.stop_button)
	_check(await _wait(func() -> bool: return not bool(net.room.get("bot_enabled",true)) and not hud._players.has(ArenaPracticeBot.BOT_ID)),"Remove button removes bot during paused combat")
	_check(str(net.room.phase)=="waiting" and not bool(net.room.paused) and int(net.room.winner_id)==0,"removing bot neither awards a win nor leaves a frozen room")
	await _click(hud._disconnect_button)
	_check(await _wait(func() -> bool: return not root.get_node("NetworkManager").is_network_connected()),"footer Disconnect closes actual connection")
	_check(main._connection_panel.visible and not hud._menu_panel.visible and main._world._avatars.is_empty(),"disconnect restores connection screen and clears world")

func _finish() -> void:
	var file := FileAccess.open(_path(role+"-result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"role":role,"checks":checks,"failures":failed}))
	file.close()
	print("Native lobby checks [%s]: %d; failures: %d" % [role,checks,failed])
	_key(KEY_D,false)
	_key(KEY_SPACE,false)
	if main!=null:
		main.queue_free()
		await process_frame
	await create_timer(0.3 if role=="guest" else 0.0).timeout
	root.get_node("NetworkManager").stop()
	await create_timer(3.1).timeout
	quit(1 if failed else 0)
