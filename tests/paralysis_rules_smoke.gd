extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:failures += 1;print("FAIL: ",message)
func _run() -> void:
	var registry = load("res://server/systems/player_registry.gd").new()
	root.add_child(registry)
	var caster: PlayerState = registry.add_player(701)
	var target: PlayerState = registry.add_player(702)
	registry.try_select_class(702,8,0)
	caster.grid_position = Vector2i(5,4)
	target.grid_position = Vector2i(5,5)
	target.facing_direction = MovementRules.Direction.WEST
	check(registry.try_cast_spell(701,25,target.grid_position,1,10000).ok,"real Paralizar reaches the server status system")
	for direction in range(4):
		check(registry.try_move_player(702,direction,10020+direction*160) == null and target.grid_position == Vector2i(5,5) and target.facing_direction == MovementRules.Direction.WEST,"Paralizar blocks translation and rotation in direction%d"%direction)
	check(registry.try_ranged_attack(702,caster.grid_position,1,11000).ok and target.facing_direction == MovementRules.Direction.WEST,"aimed arrow does not turn a paralyzed hunter")
	check(registry.try_cast_spell(701,27,target.grid_position,2,11050).ok,"Remove clears full paralysis")
	check(registry.try_move_player(702,MovementRules.Direction.EAST,11200) == target and target.grid_position == Vector2i(6,5),"movement resumes after a real Remove")
	target.grid_position = Vector2i(5,5)
	check(registry.try_cast_spell(701,26,target.grid_position,3,12100).ok,"real Inmovilizar remains available")
	check(registry.try_move_player(702,MovementRules.Direction.NORTH,12200) == target and target.grid_position == Vector2i(5,5) and target.facing_direction == MovementRules.Direction.NORTH,"Inmovilizar permits turning without taking a step")
	check(int(SpellCatalog.get_spell(26).mana) < int(SpellCatalog.get_spell(25).mana),"the cheaper immobilize keeps its existing distinct mana cost")
	registry.queue_free()
	for id: int in ClassCatalog.all_ids():
		var r = load("res://server/systems/player_registry.gd").new()
		root.add_child(r)
		var human: PlayerState = r.add_player(801)
		var bot = ArenaPracticeBot.new(r,231+id)
		bot.request(801,true,id,1,7000)
		bot.tick(10000)
		var victim: PlayerState = r.get_player(ArenaPracticeBot.BOT_ID)
		human.max_health = 100000
		human.current_health = 100000
		human.grid_position = Vector2i(9,4)
		victim.grid_position = Vector2i(9,5)
		victim.facing_direction = MovementRules.Direction.WEST
		r._status_system.apply_spell(human,victim,SpellCatalog.get_spell(25),11000)
		var frozen := true
		for step in range(51):
			var now := 11000+step*20
			r.advance_runtime(now)
			bot.tick(now)
			frozen = frozen and victim.grid_position == Vector2i(9,5) and victim.facing_direction == MovementRules.Direction.WEST
		check(frozen,"bot class%d cannot rotate or move during the first second of Paralizar"%id)
		r.queue_free()
	var r = load("res://server/systems/player_registry.gd").new()
	root.add_child(r)
	var human: PlayerState = r.add_player(901)
	var bot = ArenaPracticeBot.new(r,1234)
	bot.request(901,true,1,1,7000)
	bot.tick(10000)
	var victim: PlayerState = r.get_player(ArenaPracticeBot.BOT_ID)
	human.grid_position = Vector2i(5,5)
	victim.grid_position = Vector2i(9,5)
	r._status_system.apply_spell(human,victim,SpellCatalog.get_spell(25),11000)
	bot._next_spell = 11000
	bot._next_offense = 100000
	var removed := 0
	for step in range(81):
		var now := 11000+step*20
		r.advance_runtime(now)
		for event: Dictionary in bot.tick(now):
			if event.kind == "cast" and int(event.result.event.spell_id) == 27:removed = now
	check(removed >= 12100 and removed <= 12420,"bot Remove has a real1.1–1.4s reaction window when its cast timer is ready")
	# Refreshing a root must not postpone an already observed reaction forever.
	bot.request(901,true,1,2,20000)
	bot.tick(23000)
	victim = r.get_player(ArenaPracticeBot.BOT_ID)
	r._status_system.apply_spell(human,victim,SpellCatalog.get_spell(26),24000)
	bot._next_spell = 24000
	bot._next_offense = 100000
	bot.tick(24000)
	var first_deadline: int = bot._root_due
	r._status_system.apply_spell(human,victim,SpellCatalog.get_spell(25),25000)
	bot.tick(25000)
	check(bot._root_due == first_deadline and r._status_system.is_paralyzed(ArenaPracticeBot.BOT_ID,25000),"refreshing a root preserves the ongoing reaction deadline instead of postponing forever")
	r._status_system.apply_spell(human,victim,SpellCatalog.get_spell(26),25100)
	check(r._status_system.is_paralyzed(ArenaPracticeBot.BOT_ID,25100),"cheaper Inmovilizar cannot erase active Paralizar")
	r.advance_runtime(38000)
	check(not r._status_system.is_paralyzed(ArenaPracticeBot.BOT_ID,38000) and r._status_system.is_rooted(ArenaPracticeBot.BOT_ID,38000),"paralysis expiry restores turning while the longer immobilize remains")
	r.queue_free()
	await process_frame
	print("Paralysis checks: %d; failures: %d"%[checks,failures])
	quit(1 if failures else 0)
