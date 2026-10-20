extends SceneTree

var main: Node
var role := ""
var directory: String
var checks := 0
var failed := 0
var received: Array = []
var fx: Array = []
var members: Array = []

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		print("FAIL [%s]: %s" % [role,label])
func _wait(predicate: Callable, seconds: float = 12.0) -> bool:
	# Always yield once: callers await this helper even when a marker already exists.
	await process_frame
	var until := Time.get_ticks_msec() + int(seconds*1000)
	while Time.get_ticks_msec() < until:
		if predicate.call(): return true
		await create_timer(0.05).timeout
	return false
func _marker(name_value: String) -> String: return directory.path_join(name_value)
func _mark(name_value: String) -> void:
	var file := FileAccess.open(_marker(name_value),FileAccess.WRITE)
	file.store_string("ok")
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--lobby-role="): role = arg.trim_prefix("--lobby-role=")
		if arg.begins_with("--lobby-markers="): directory = arg.trim_prefix("--lobby-markers=")
	if role.is_empty() or directory.is_empty(): quit(2); return
	root.get_node("InputBindings").use_profile("__ranking_network_"+role)
	ProjectSettings.set_setting("network/server_url","ws://127.0.0.1:17877")
	var net := root.get_node("LobbyNetwork")
	var players := root.get_node("PlayerNetwork")
	players.snapshot_received.connect(func(data: Array) -> void:
		for item: Dictionary in data: received.append(int(item.peer_id))
	)
	players.player_stats_updated.connect(func(data: Dictionary) -> void: received.append(int(data.peer_id)))
	players.player_moved.connect(func(data: Dictionary) -> void: received.append(int(data.peer_id)))
	root.get_node("SpellNetwork").spell_resolved.connect(func(data: Dictionary) -> void: fx.append(int(data.caster_id)))
	main = load("res://client/scenes/client_main.tscn").instantiate()
	root.add_child(main)
	_check(await _wait(func() -> bool: return net.available),"protocol22 capabilities")
	var ranking := root.get_node("RankingNetwork")
	_check(await _wait(func() -> bool: return ranking.registered),"ranking profile authenticated over real WS")
	_check(ranking.snapshot.get("entries",[]).size() >= 1 and ranking.snapshot.entries[0].nickname == "milusita","honorary ranking received from authority")
	ranking.refresh()
	_check(net.room.is_empty() and main._world._avatars.is_empty(),"connect enters browser without a player in global world")
	if role == "S":
		await _solo(net)
		await _finish()
		return
	if role in ["A","B"]:
		net.command("create",{"title":"TEST"+role,"arena_id":"forest" if role=="A" else "desert"})
	else:
		var title := "TESTA" if role=="C" else "TESTB"
		_check(await _wait(func() -> bool:
			for entry: Dictionary in net.rooms:
				if str(entry.title)==title: return true
			return false
		),"target room appears in directory")
		for entry: Dictionary in net.rooms:
			if str(entry.title)==title: net.command("join",{"room_id":entry.id}); break
	_check(await _wait(func() -> bool: return net.room.get("members",[]).size()==2 and not net.pending),"two people join the same room")
	if net.room.is_empty(): await _finish(); return
	for member: Dictionary in net.room.members: members.append(int(member.peer_id))
	_check(main._hud._players.size()==2,"room snapshot contains exactly two avatars")
	_check(not main._local_input.is_processing(),"lobby blocks movement input")
	_check(net.rooms.size()==2,"both rooms listed")
	await create_timer(0.3).timeout
	net.command("ready",{"ready":true,"revision":int(net.room.revision)})
	_check(await _wait(func() -> bool: return str(net.room.phase)=="countdown"),"both Listo starts authoritative countdown")
	_check(not main._local_input.is_processing(),"countdown blocks movement input")
	_check(await _wait(func() -> bool: return str(net.room.phase)=="fighting"),"countdown enters fighting")
	_check(main._local_input.is_processing(),"fight enables gameplay")
	_check(main._world._arena_id == ("forest" if role in ["A","C"] else "desert"),"own room map")
	_mark(role+"-fighting")
	_check(await _wait(func() -> bool: return FileAccess.file_exists(_marker("A-fighting")) and FileAccess.file_exists(_marker("B-fighting")) and FileAccess.file_exists(_marker("C-fighting")) and FileAccess.file_exists(_marker("D-fighting"))),"two simultaneous duels")
	if role=="A":
		var opponent: int = members[1]
		root.get_node("SpellNetwork").request_cast(25,main._hud._players[opponent].grid_position,1)
		await create_timer(0.6).timeout
		_mark("A-cast")
	else:
		_check(await _wait(func() -> bool: return FileAccess.file_exists(_marker("A-cast"))),"room A completes spell")
	await create_timer(0.2).timeout
	_check(received.all(func(peer_id: int) -> bool: return members.has(peer_id)),"no foreign room snapshot/movement/stats")
	_check(fx.all(func(peer_id: int) -> bool: return members.has(peer_id)),"no foreign room combat FX")
	if role in ["B","D"]:
		_check(fx.is_empty(),"room B never receives room A cast")
		for player: PlayerState in main._hud._players.values():
			_check(player.current_health==player.max_health,"room B remains undamaged")
	if role=="C": _check(not fx.is_empty(),"opponent in room A receives cast")
	_mark(role+"-done")
	await _wait(func() -> bool: return FileAccess.file_exists(_marker("A-done")) and FileAccess.file_exists(_marker("B-done")) and FileAccess.file_exists(_marker("C-done")) and FileAccess.file_exists(_marker("D-done")))
	await _finish()
func _finish() -> void:
	var result_file := FileAccess.open(_marker(role+"-result.json"),FileAccess.WRITE)
	result_file.store_string(JSON.stringify({"role":role,"checks":checks,"failures":failed}))
	result_file.close()
	print("Lobby network checks [%s]: %d; failures: %d" % [role,checks,failed])
	if main != null:
		main.queue_free()
		await process_frame
	# Close peers in separate polls; simultaneous transport teardown itself emits Godot WS diagnostics.
	await create_timer(0.25 * ["A","B","C","D","S"].find(role)).timeout
	root.get_node("NetworkManager").stop()
	# Let already-completed RPC timeout coroutines release their timers before exiting.
	await create_timer(3.1).timeout
	quit(1 if failed else 0)

func _solo(net: Node) -> void:
	var bot_network := root.get_node("BotNetwork")
	var skins := root.get_node("Skins")
	var wins: int = skins.progress.wins
	net.command("create",{"title":"SOLO","arena_id":"duel_room"})
	_check(await _wait(func() -> bool: return not net.room.is_empty() and not net.pending),"solo creates duel room")
	main._lobby_panel.presets_requested.emit()
	_check(main._hud._class_panel.visible and main._hud._class_panel.layer > main._lobby_panel.layer,"class preset window usable above lobby")
	main._lobby_panel.skins_requested.emit()
	_check(main._hud._skins_panel.visible and not main._hud._class_panel.visible and main._hud._skins_panel.layer > main._lobby_panel.layer,"skins window usable above lobby")
	await create_timer(0.2).timeout
	net.command("bot",{"enabled":true,"class_id":8})
	_check(await _wait(func() -> bool: return bool(net.room.get("bot_enabled",false)) and not net.pending),"bot configured before ready")
	_check(main._hud._players.size()==1 and not bool(bot_network.state.enabled),"configured bot waits for Listo")
	await create_timer(0.2).timeout
	net.command("ready",{"ready":true,"revision":int(net.room.revision)})
	_check(await _wait(func() -> bool: return str(net.room.phase)=="countdown" and bool(bot_network.state.enabled)),"solo Listo starts bot countdown")
	_check(not main._local_input.is_processing(),"solo countdown locks controls")
	_check(not main._hud._skins_panel.visible and not main._hud._class_panel.visible and not main._hud._menu_panel.visible,"countdown closes old lobby modals")
	_check(str(bot_network.state.round_id)==str(net.room.round_id),"room and bot share authoritative round ID")
	_check(await _wait(func() -> bool: return str(net.room.phase)=="fighting" and str(bot_network.state.phase)=="active"),"solo countdown enters active bot round")
	_check(main._local_input.is_processing() and main._hud._players.size()==2,"player and bot playable")
	net.request_pause(true)
	_check(await _wait(func() -> bool: return net.is_paused() and not net.pause_pending),"server confirms solo bot pause")
	_check(not net.gameplay_active(),"pause blocks gameplay")
	await create_timer(0.1).timeout
	var observed := received.size()
	root.get_node("PlayerNetwork").request_move(MovementRules.Direction.EAST)
	root.get_node("PlayerNetwork").request_basic_attack()
	root.get_node("RecoveryNetwork").request_action("red")
	await create_timer(1.5).timeout
	_check(received.size() == observed,"server freezes bot and rejects player actions while paused")
	net.request_pause(false)
	_check(await _wait(func() -> bool: return not net.is_paused() and not net.pause_pending),"server confirms resume")
	_check(net.gameplay_active(),"resume restores gameplay")
	net.request_pause(true)
	net.request_pause(false)
	_check(await _wait(func() -> bool: return not net.is_paused() and not net.pause_pending),"rapid open close does not leave bot paused")
	await create_timer(1.0).timeout
	main._spell_controller.aim_spell(25)
	main._spell_controller.pending_request = 999
	root.get_node("RecoveryNetwork").begin_using_selected()
	net.command("leave")
	_check(await _wait(func() -> bool: return net.room.is_empty() and not net.pending),"leave active bot round returns browser")
	_check(main._world._avatars.is_empty() and not main._local_input.is_processing(),"leave clears avatars and input")
	_check(not bool(bot_network.state.get("enabled",false)) and skins.progress.wins==wins,"interrupted solo round grants no reward")
	_check(net.rooms.is_empty(),"empty solo room deleted")
	_check(main._spell_controller.aimed_spell_id==0 and main._spell_controller.pending_request==0 and not root.get_node("RecoveryNetwork").using_selected,"leave clears aim, pending spell and held potion")
	await create_timer(0.2).timeout
	net.command("create",{"title":"NEW ROOM","arena_id":"desert"})
	_check(await _wait(func() -> bool: return not net.room.is_empty() and not net.pending),"create another room on the same connection")
	_check(int(root.get_node("ArenaNetwork").state.revision)==0 and main._world._arena_id=="desert","new room revision zero replaces previous room revision zero map")
	_check(main._hud._players.size()==1 and not bool(bot_network.state.get("enabled",false)),"new room has no old bot or avatars")
	var arena_network := root.get_node("ArenaNetwork")
	arena_network.select_arena("lava")
	_check(await _wait(func() -> bool: return str(arena_network.state.get("arena_id",""))=="lava" and not arena_network.pending),"host changes map while preparing lobby")
	_check(await _wait(func() -> bool: return not bool(arena_network.state.get("transitioning",true))),"map transition expiry reaches client and enables readiness")
	await create_timer(0.2).timeout
	net.command("leave")
	_check(await _wait(func() -> bool: return net.room.is_empty() and not net.pending),"leave second room cleanly")
