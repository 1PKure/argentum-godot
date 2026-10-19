extends Node

var lobbies := ArenaLobbyDirectory.new()

func _ready() -> void:
	print("Starting Argentum lobby server...")
	LobbyNetwork.command_requested.connect(_on_lobby_command)
	LobbyNetwork.pause_requested.connect(_on_pause_requested)
	LobbyNetwork.status_requested.connect(_send_lobby_state)
	ArenaNetwork.selection_requested.connect(_on_arena_selection)
	ArenaNetwork.status_requested.connect(func(peer_id: int) -> void:
		var room := lobbies.room_for(peer_id)
		ArenaNetwork.send_state(peer_id,room.arena.status() if room != null else {})
	)
	Skins.skin_requested.connect(func(peer_id: int, class_id: int, id: String, wins: int) -> void:
		var room := lobbies.room_for(peer_id)
		if room == null or room.paused: return
		var result := room.registry.try_select_skin(peer_id,id,wins,class_id)
		if result.ok: _stats(room,result.state)
	)
	BotNetwork.command_requested.connect(_on_bot_command)
	BotNetwork.status_requested.connect(func(peer_id: int) -> void:
		var room := lobbies.room_for(peer_id)
		BotNetwork.send_status(peer_id,room.bot.status() if room != null else {"enabled":false,"phase":"idle"})
	)
	NetworkManager.peer_connected.connect(_on_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	PlayerNetwork.move_requested.connect(_on_move_requested)
	PlayerNetwork.basic_attack_requested.connect(_on_basic_attack_requested)
	PlayerNetwork.debug_damage_requested.connect(func(_peer_id: int) -> void: pass)
	PlayerNetwork.debug_mana_spend_requested.connect(func(_peer_id: int) -> void: pass)
	SpellNetwork.cast_requested.connect(_on_spell_cast_requested)
	SpellNetwork.shot_requested.connect(_on_shot_requested)
	InventoryNetwork.move_requested.connect(_on_inventory_move)
	InventoryNetwork.use_requested.connect(_on_inventory_use)
	RecoveryNetwork.action_requested.connect(_on_recovery_action_requested)
	var port := NetworkConstants.DEFAULT_PORT
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--port=") and argument.trim_prefix("--port=").is_valid_int():
			port = int(argument.trim_prefix("--port="))
	if port < 1 or port > 65535:
		push_error("Port must be between 1 and 65535.")
		get_tree().quit(1)
		return
	var error := NetworkManager.start_server(port)
	if error != OK:
		push_error("Server startup failed.")
		get_tree().quit(1)
		return
	print("Argentum server ready.")

func _exit_tree() -> void:
	lobbies.dispose()

func _process(_delta: float) -> void:
	var directory_changed := false
	for room: ArenaLobbyRoom in lobbies.rooms.values():
		var result := room.tick()
		for player: Dictionary in result.players: _stats(room,player)
		for action: Dictionary in result.actions: _publish_bot_action(room,action)
		if result.changed:
			_publish_room(room,false)
			directory_changed = true
	if directory_changed: _broadcast_lobby_states()

func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.get_peers().size() > ArenaLobbyDirectory.MAX_CONNECTED:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	_send_lobby_state(peer_id)
	PlayerNetwork.send_snapshot_to(peer_id,[])

func _on_peer_disconnected(peer_id: int) -> void:
	var room := lobbies.room_for(peer_id)
	lobbies.disconnect_peer(peer_id)
	if room != null and lobbies.rooms.has(room.id): _publish_room(room,true)
	_broadcast_lobby_states()

func _on_lobby_command(peer_id: int, operation: String, payload: Dictionary, request: int) -> void:
	if operation.length() > 20 or payload.size() > 8:
		LobbyNetwork.send_result(peer_id,request,ArenaLobbyRoom.error("Solicitud inválida."))
		return
	var old_room := lobbies.room_for(peer_id)
	var result := lobbies.command(peer_id,operation,payload,request)
	var room := lobbies.room_for(peer_id)
	if result.ok:
		if room != null:
			_bind_room(room)
			_publish_room(room,true)
		else:
			ArenaNetwork.send_state(peer_id,{})
			BotNetwork.send_status(peer_id,{"enabled":false,"phase":"idle"})
			PlayerNetwork.send_snapshot_to(peer_id,[])
		if old_room != null and old_room != room and lobbies.rooms.has(old_room.id): _publish_room(old_room,true)
		_broadcast_lobby_states()
	LobbyNetwork.send_result(peer_id,request,result)

func _on_pause_requested(peer_id: int, value: bool, request: int) -> void:
	var result := lobbies.pause(peer_id,value,request)
	var room := lobbies.room_for(peer_id)
	if result.ok and room != null: _publish_room(room,false)
	LobbyNetwork.send_pause_result(peer_id,request,result)

func _bind_room(room: ArenaLobbyRoom) -> void:
	if room.registry.basic_attack_resolved.is_connected(PlayerNetwork.send_basic_attack_result): return
	room.registry.basic_attack_resolved.connect(PlayerNetwork.send_basic_attack_result)
	room.bot.reset_world.connect(func() -> void: _publish_room(room,true))
	room.bot.status_changed.connect(func(_status: Dictionary) -> void: _publish_room(room,false))

func _send_lobby_state(peer_id: int) -> void:
	if not _can_send(peer_id): return
	var room := lobbies.room_for(peer_id)
	LobbyNetwork.send_state(peer_id,lobbies.listings(),room.state() if room != null else {})

func _broadcast_lobby_states() -> void:
	for peer_id: int in multiplayer.get_peers(): _send_lobby_state(peer_id)

func _publish_room(room: ArenaLobbyRoom, snapshot: bool) -> void:
	for peer_id: int in room.members:
		if not _can_send(peer_id): continue
		# Room identity arrives first, so clients discard the old map revision/input before the new snapshot.
		_send_lobby_state(peer_id)
		ArenaNetwork.send_state(peer_id,room.arena.status())
		if snapshot: PlayerNetwork.send_snapshot_to(peer_id,room.registry.get_snapshot())
		BotNetwork.send_status(peer_id,room.bot.status())

func _stats(room: ArenaLobbyRoom, state: Dictionary) -> void:
	var recipients := _recipients(room)
	if not recipients.is_empty(): PlayerNetwork.broadcast_player_stats_updated(state,recipients)

func _moved(room: ArenaLobbyRoom, state: Dictionary) -> void:
	var recipients := _recipients(room)
	if not recipients.is_empty(): PlayerNetwork.broadcast_player_moved(state,recipients)

func _on_move_requested(peer_id: int, direction: int) -> void:
	var room := lobbies.room_for(peer_id)
	if room == null or room.paused or room.phase != "fighting": return
	var player := room.registry.try_move_player(peer_id,direction,room.game_time())
	if player != null: _moved(room,player.to_dictionary())

func _on_basic_attack_requested(peer_id: int) -> void:
	var room := lobbies.room_for(peer_id)
	if room == null or room.paused or room.phase != "fighting": return
	var attacker := room.registry.get_player(peer_id)
	var meditating := attacker.is_meditating
	var target := room.registry.try_basic_attack(peer_id,room.game_time())
	if meditating and not attacker.is_meditating: _stats(room,attacker.to_dictionary())
	if target != null: _stats(room,target.to_dictionary())
	if room.settle_round(): _publish_room(room,false); _broadcast_lobby_states()

func _on_spell_cast_requested(peer_id: int, spell_id: int, target: Vector2i, request: int) -> void:
	var room := lobbies.room_for(peer_id)
	if room == null or room.paused or room.phase != "fighting":
		SpellNetwork.send_rejection(peer_id,request,"La ronda todavía no comenzó.")
		return
	_publish_cast(room,peer_id,request,room.registry.try_cast_spell(peer_id,spell_id,target,request,room.game_time()))

func _on_shot_requested(peer_id: int, target: Vector2i, request: int) -> void:
	var room := lobbies.room_for(peer_id)
	if room == null or room.paused or room.phase != "fighting":
		SpellNetwork.send_rejection(peer_id,request,"La ronda todavía no comenzó.")
		return
	_publish_cast(room,peer_id,request,room.registry.try_ranged_attack(peer_id,target,request,room.game_time()))

func _publish_cast(room: ArenaLobbyRoom, peer_id: int, request: int, result: Dictionary) -> void:
	if not result.ok:
		SpellNetwork.send_rejection(peer_id,request,result.message,int(result.get("remaining_msec",0)))
		return
	_stats(room,result.caster_state)
	if int(result.target_state.peer_id) != peer_id: _stats(room,result.target_state)
	_spell_event(room,result.event)
	if room.settle_round(): _publish_room(room,false); _broadcast_lobby_states()

func _on_recovery_action_requested(peer_id: int, action: String, request: int, source: String) -> void:
	var room := lobbies.room_for(peer_id)
	if room == null:
		RecoveryNetwork.send_rejection(peer_id,request,"Entrá primero a una sala.")
		return
	var changing_class := action.begins_with("class:")
	if room.paused or (changing_class and room.phase not in ["waiting","result"]) or (not changing_class and room.phase != "fighting"):
		RecoveryNetwork.send_rejection(peer_id,request,"Esta acción no está disponible durante esta fase.")
		return
	if action == "respawn":
		RecoveryNetwork.send_rejection(peer_id,request,"Marcá Listo para la próxima ronda.")
		return
	var result := room.registry.try_recovery_action(peer_id,action,request,room.game_time(),source)
	if not result.ok:
		RecoveryNetwork.send_rejection(peer_id,request,str(result.message),int(result.get("remaining_msec",0)))
		return
	_stats(room,result.state)
	result.event.request_id = request
	RecoveryNetwork.broadcast_result(result.event)
	if changing_class:
		room.bot.remove_bot(false)
		room.invalidate_ready()
		_publish_room(room,true)
		_broadcast_lobby_states()

func _on_inventory_move(peer_id: int, source: int, destination: int, item_id: int, revision: int, request: int) -> void:
	var room := lobbies.room_for(peer_id)
	if room != null and not room.paused: _inventory_result(room,peer_id,room.registry.try_inventory_move(peer_id,source,destination,item_id,revision,request))

func _on_inventory_use(peer_id: int, slot: int, item_id: int, revision: int, request: int) -> void:
	var room := lobbies.room_for(peer_id)
	if room != null and not room.paused: _inventory_result(room,peer_id,room.registry.try_inventory_use(peer_id,slot,item_id,revision,request))

func _inventory_result(room: ArenaLobbyRoom, peer_id: int, result: Dictionary) -> void:
	if not result.ok: InventoryNetwork.send_rejection(peer_id,str(result.message))
	else: _stats(room,result.state)

func _on_bot_command(peer_id: int, enabled: bool, class_id: int, request: int) -> void:
	# The old practice window may configure a bot, but only Listo starts its round.
	var room := lobbies.room_for(peer_id)
	var result := ArenaLobbyRoom.error("Configurá el bot desde la sala.")
	if room != null and room.members[0] == peer_id and room.members.size() == 1 and room.phase in ["waiting","result"] and not ClassCatalog.get_profile(class_id).is_empty():
		room.bot.remove_bot(false)
		room.bot_enabled = enabled
		room.bot_class = class_id
		room.invalidate_ready()
		_publish_room(room,true)
		_broadcast_lobby_states()
		result = {"ok":true}
	BotNetwork.send_result(peer_id,request,result)

func _on_arena_selection(peer_id: int, id: String, revision: int, request: int) -> void:
	var room := lobbies.room_for(peer_id)
	var result := ArenaLobbyRoom.error("Entrá primero a una sala.")
	if room != null:
		if room.phase not in ["waiting","result"]:
			result = ArenaLobbyRoom.error("La arena se elige antes de comenzar la ronda.")
		else:
			result = room.arena.change(peer_id,id,revision,request,room.game_time())
			if result.ok:
				# ArenaSession may recreate a prior practice bot. Lobby Ready owns
				# the next countdown, so retain its configuration without an entity.
				room.bot.remove_bot(false)
				room.invalidate_ready()
				_publish_room(room,true)
				_broadcast_lobby_states()
	ArenaNetwork.send_result(peer_id,request,result)

func _publish_bot_action(room: ArenaLobbyRoom, action: Dictionary) -> void:
	match str(action.kind):
		"move": _moved(room,action.state)
		"cast":
			_stats(room,action.result.caster_state)
			if int(action.result.target_state.peer_id) != int(action.result.caster_state.peer_id): _stats(room,action.result.target_state)
			_spell_event(room,action.result.event)
		"recovery": _stats(room,action.result.state)
		"melee":
			_stats(room,action.attacker)
			_stats(room,action.target)

func _can_send(peer_id: int) -> bool:
	if NetworkManager.peer == null or not multiplayer.get_peers().has(peer_id): return false
	var socket := NetworkManager.peer.get_peer(peer_id)
	return socket != null and socket.get_ready_state() == WebSocketPeer.STATE_OPEN

func _recipients(room: ArenaLobbyRoom) -> Array:
	return room.members.filter(func(peer_id: int) -> bool: return _can_send(peer_id))

func _spell_event(room: ArenaLobbyRoom, event: Dictionary) -> void:
	var recipients := _recipients(room)
	if not recipients.is_empty(): SpellNetwork.broadcast_result(event,recipients)
