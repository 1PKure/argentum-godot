extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL: ",label)
func _run() -> void:
	var registry = load("res://server/systems/player_registry.gd").new();root.add_child(registry)
	var human: PlayerState=registry.add_player(101)
	var manager:=ArenaPracticeBot.new(registry,924)
	manager.request(101,true,1,1,7000);manager.tick(10000)
	var bot: PlayerState=registry.get_player(ArenaPracticeBot.BOT_ID)
	bot.grid_position=Vector2i(9,5);human.grid_position=Vector2i(5,5)
	human.max_health=100000;human.current_health=100000
	var reds:Array[int]=[];var spells:Array[Dictionary]=[];var previous_health:=bot.current_health
	for step in range(1000):
		var now:=10000+step*20
		registry.advance_runtime(now)
		if step%48==0: bot.current_health=maxi(70,bot.current_health-60)
		for action:Dictionary in manager.tick(now):
			if action.kind=="recovery" and action.result.event.action=="health_potion":
				reds.append(now)
				if bot.current_health<bot.max_health*.45:check(manager._next_offense>=now+220,"Emergency red commits to recovery")
			if action.kind=="cast":
				var id:=int(action.result.event.spell_id)
				if id==31 and not reds.is_empty():check(manager._potion_due>=now+700,"Heal pauses potion recovery rather than stacking both instantly")
				spells.append({"id":id,"time":now})
	check(reds.size()>=3,"Pressure produces actual health potions")
	for index in range(1,reds.size()):check(reds[index]-reds[index-1]>=300,"Bot potions respect their recovery cadence")
	check(spells.any(func(event:Dictionary)->bool:return event.id in [53,51,41,39]),"Bot still attacks between recovery windows")
	check(RecoveryRules.get_potion("health_potion").min==27,"Human red potion remains 27HP")
	registry.queue_free();await process_frame
	print("Bot recovery commitment checks: %d; failures: %d"%[checks,failures]);quit(1 if failures else 0)
