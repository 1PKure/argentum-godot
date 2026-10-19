extends SceneTree
var checks := 0
var failures := 0
var registry: PlayerRegistry
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	for id: String in ArenaData.IDS:
		var definition := ArenaData.get_definition(id)
		_check(ArenaData.is_implemented(id) and ArenaData.get_spawn_points(id).size() == 2,"%s implemented with two spawns" % id)
		var open: Array[Vector2i] = [Vector2i(4,5)]
		var reached: Dictionary = {Vector2i(4,5):true}
		while not open.is_empty():
			var cell: Vector2i = open.pop_front()
			for delta: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next := cell+delta
				if ArenaData.is_walkable(id,next) and not reached.has(next):
					reached[next] = true
					open.append(next)
		_check(reached.size() == 236,"%s walkable area is connected" % id)
		for cell: Vector2i in definition.blocked_cells:
			_check(definition.blocked_cells.has(Vector2i(19-cell.x,cell.y)) and not ArenaData.is_walkable(id,cell),"%s obstacle is mirrored and blocked" % id)
		_check(not ArenaData.is_walkable(id,Vector2i(-1,5)) and not ArenaData.is_walkable(id,Vector2i(20,5)),"%s has server bounds" % id)
		for x in range(20):
			_check(ArenaData.is_walkable(id,Vector2i(x,5)),"%s central lane %d is clear" % [id,x])
		definition.blocked_cells.clear()
		_check(ArenaData.get_definition(id).blocked_cells.size() == 4,"%s returns independent definitions" % id)
	_check(not ArenaData.is_walkable("invalid",Vector2i(4,5)),"Unknown arena is not walkable")
	registry = PlayerRegistry.new()
	root.add_child(registry)
	var owner := registry.add_player(301)
	var guest := registry.add_player(302)
	var bot := ArenaPracticeBot.new(registry,72)
	var session := ArenaSession.new(registry,bot)
	var original := owner.to_dictionary()
	_check(not session.change(302,"desert",0,1,10000).ok and owner.to_dictionary() == original,"Guest cannot reset the arena")
	_check(not session.change(999,"desert",0,1,10000).ok,"Unknown member rejected")
	_check(not session.change(301,"invalid",0,1,10000).ok,"Unknown map rejected")
	_check(not session.change(301,"desert",9,2,10000).ok,"Stale revision rejected")
	owner.current_health = 1
	owner.current_mana = 0
	owner.is_meditating = true
	owner.skin_id = "explorer"
	_check(session.change(301,"desert",0,3,10000).ok,"Host changes map")
	_check(owner.current_health == owner.max_health and owner.current_mana == owner.max_mana and not owner.is_meditating and owner.skin_id == "explorer","Reset restores resources, clears meditation and preserves skin")
	_check(owner.grid_position == Vector2i(4,5) and guest.grid_position == Vector2i(15,5),"Reset restores distinct spawns")
	_check(registry.is_round_locked(301) and registry.try_move_player(301,MovementRules.Direction.EAST) == null,"Transition blocks server movement")
	_check(not session.change(301,"lava",1,4,10300).ok and not session.tick(10599),"Transition rejects early change and unlock")
	_check(session.tick(10600) and not registry.is_round_locked(301),"Transition unlocks at the visible boundary")
	_check(not session.change(301,"lava",1,4,10600).ok,"Replayed nonce rejected")
	_check(session.change(301,"lava",1,5,10600).ok,"Next choice accepted when UI becomes enabled")
	session.tick(11200)
	registry.remove_player(301)
	session.peer_left(301)
	_check(session.owner_id() == 302 and session.change(302,"duel_room",2,2,11200).ok,"Owner departure transfers control")
	session.tick(11800)
	for id: String in ArenaData.IDS:
		registry.set_arena(id)
		var now := 20000 + ArenaData.IDS.find(id)*20000
		bot._start_round(302,1,now)
		var round_id := bot.round_id
		var next_id: String = ArenaData.IDS[(ArenaData.IDS.find(id)+1)%4]
		_check(session.change(302,next_id,session.revision,10+ArenaData.IDS.find(id),now+4000).ok,"%s changes with bot active" % id)
		_check(bot.phase == "countdown" and not bot.round_id.is_empty() and bot.round_id != round_id,"Interrupted practice creates a fresh countdown, never a victory")
		session.tick(now+4600)
		_check(registry.is_round_locked(302) and bot.phase == "countdown","Map transition cannot release bot countdown")
		bot.tick(now+7100)
		_check(not registry.is_round_locked(302),"Bot countdown eventually releases input")
		var legal := true
		for step in range(30):
			bot.tick(now+8000+step*120)
			var rival := registry.get_player(ArenaPracticeBot.BOT_ID)
			legal = legal and rival != null and ArenaData.is_walkable(next_id,rival.grid_position)
		_check(legal,"%s bot uses legal cells" % next_id)
		bot.remove_bot(false)
	bot._start_round(302,1,200000)
	var other := "desert" if registry.get_arena_id() != "desert" else "forest"
	session.change(302,other,session.revision,20,204000)
	bot.peer_joining()
	registry.add_player(303)
	session.peer_joined()
	_check(registry.is_round_locked(302) and registry.is_round_locked(303),"Joining during a map transition keeps both humans locked after removing the bot")
	session.tick(204600)
	_check(not registry.is_round_locked(302) and not registry.is_round_locked(303),"Both humans unlock together at the transition boundary")
	registry.queue_free()
	await process_frame
	print("Arena environment rule checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
func _check(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+message)
