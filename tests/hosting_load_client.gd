extends SceneTree
var index := 0
var count := 2
var folder := ""
var seconds := 10.0
var url := "ws://127.0.0.1:17901"
var delays: Array[float] = []
var events := 0
var sent_chat_at := -1
var states: Dictionary = {}
func _initialize() -> void: call_deferred("_run")
func wait_for(predicate: Callable, timeout: float = 20) -> bool:
	await process_frame
	var deadline := Time.get_ticks_msec()+int(timeout*1000)
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		await create_timer(0.025).timeout
	return false
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--load-index="): index=int(arg.trim_prefix("--load-index="))
		if arg.begins_with("--load-count="): count=int(arg.trim_prefix("--load-count="))
		if arg.begins_with("--load-folder="): folder=arg.trim_prefix("--load-folder=")
		if arg.begins_with("--load-seconds="): seconds=float(arg.trim_prefix("--load-seconds="))
	if not OS.get_environment("AO_QA_URL").is_empty(): url = OS.get_environment("AO_QA_URL")
	var network := root.get_node("NetworkManager")
	var lobby := root.get_node("LobbyNetwork")
	var ranking := root.get_node("RankingNetwork")
	var chat := root.get_node("ChatNetwork")
	var players := root.get_node("PlayerNetwork")
	var spells := root.get_node("SpellNetwork")
	var recovery := root.get_node("RecoveryNetwork")
	var diagnostics := root.get_node("NetworkDiagnostics")
	players.snapshot_received.connect(func(snapshot: Array) -> void:
		states.clear()
		for state: Dictionary in snapshot: states[int(state.peer_id)] = state
	)
	players.player_stats_updated.connect(func(state: Dictionary) -> void: states[int(state.peer_id)] = state)
	players.player_moved.connect(func(state: Dictionary) -> void: states[int(state.peer_id)] = state)
	spells.spell_resolved.connect(func(_event: Dictionary) -> void: events+=1)
	chat.completed.connect(func(ok: bool,_message: String) -> void:
		if ok and sent_chat_at>=0: delays.append(float(Time.get_ticks_msec()-sent_chat_at));sent_chat_at=-1
	)
	network.connected_to_server.connect(spells.query_server)
	network.start_client(url)
	if not await wait_for(func() -> bool: return lobby.available and ranking.registered): finish(false,"connect");return
	var title := "LOAD-%d" % (index/2)
	if index%2==0: lobby.command("create",{"title":title,"arena_id":"forest"})
	else:
		if not await wait_for(func() -> bool:
			for room: Dictionary in lobby.rooms:
				if room.title==title: return true
			return false
		): finish(false,"directory");return
		for room: Dictionary in lobby.rooms:
			if room.title==title: lobby.command("join",{"room_id":room.id});break
	if not await wait_for(func() -> bool: return lobby.room.get("members",[]).size()==2 and not lobby.pending): finish(false,"join");return
	await create_timer(0.3).timeout
	lobby.command("ready",{"ready":true,"revision":int(lobby.room.revision)})
	if not await wait_for(func() -> bool: return str(lobby.room.get("phase",""))=="fighting"): finish(false,"ready");return
	var marker := FileAccess.open(folder.path_join("ready-%d"%index),FileAccess.WRITE)
	marker.store_string("ready");marker.close()
	if not await wait_for(func() -> bool: return FileAccess.file_exists(folder.path_join("go"))): finish(false,"barrier");return
	var own_id := root.multiplayer.get_unique_id()
	var started := Time.get_ticks_msec()
	var next_spell := 0
	var next_move := 0
	var move_index := 0
	var next_chat := 0
	var next_potion := 0
	var request := 1
	while Time.get_ticks_msec()-started<int(seconds*1000):
		var elapsed := Time.get_ticks_msec()-started
		if elapsed>=next_spell and states.has(own_id):
			var own: Dictionary = states[own_id]
			spells.request_cast(31,Vector2i(int(own.grid_x),int(own.grid_y)),request)
			request+=1;next_spell=elapsed+1050
		if elapsed>=next_potion:
			recovery.request_action("mana_potion");next_potion=elapsed+300
		if elapsed>=next_chat and not chat.pending:
			sent_chat_at=Time.get_ticks_msec()
			chat.send("Prueba de carga %d"%index)
			next_chat=elapsed+1500
		if elapsed>=next_move:
			var direction := MovementRules.Direction.EAST if (move_index+index)%2==0 else MovementRules.Direction.WEST
			if diagnostics.measured_moves: diagnostics.request_move(direction)
			else: players.request_move(direction)
			move_index+=1;next_move=elapsed+150
		await create_timer(0.05).timeout
	var success: bool = lobby.room.get("phase","")=="fighting" and events>0 and delays.size()>0 and network.is_network_connected()
	var done := FileAccess.open(folder.path_join("done-%d"%index),FileAccess.WRITE)
	done.store_string("done");done.close()
	await wait_for(func() -> bool: return FileAccess.file_exists(folder.path_join("stop")))
	lobby.command("leave")
	await wait_for(func() -> bool: return lobby.room.is_empty() and not lobby.pending)
	await create_timer(0.3+index*0.15).timeout
	finish(success,"")
func finish(ok: bool, failure: String) -> void:
	var result := {"ok":ok,"index":index,"failure":failure,"chat_rtt_ms":delays,"spell_events":events}
	var diagnostics := root.get_node("NetworkDiagnostics")
	result.merge({"confirmed_moves":diagnostics.confirmed,"blocked_moves":diagnostics.blocked,"move_timeouts":diagnostics.move_timeouts,"probe_timeouts":diagnostics.probe_timeouts,"ping_samples_ms":diagnostics.ping_samples,"move_samples_ms":diagnostics.move_samples,"server_samples_ms":diagnostics.server_samples})
	var file := FileAccess.open(folder.path_join("client-%d.json"%index),FileAccess.WRITE)
	file.store_string(JSON.stringify(result));file.close()
	root.get_node("NetworkManager").stop()
	quit(0 if ok else 1)
