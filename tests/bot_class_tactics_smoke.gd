extends SceneTree

class AvoidedRegistry extends PlayerRegistry:
	var forced_outcome := "evaded"
	func _roll_physical_outcome(_target: PlayerState) -> String:
		return forced_outcome

var checks := 0
var failures := 0
var registries: Array[Node] = []

func _initialize() -> void:
	call_deferred("_run")

func _fixture(class_id: int, outcome: String = "") -> Dictionary:
	var registry = load("res://server/systems/player_registry.gd").new() if outcome.is_empty() else AvoidedRegistry.new()
	registry._physical_rng.seed = 224+class_id
	if not outcome.is_empty(): registry.forced_outcome = outcome
	root.add_child(registry)
	registries.append(registry)
	var human: PlayerState = registry.add_player(301)
	var manager := ArenaPracticeBot.new(registry,924)
	manager.request(301,true,class_id,1,7000)
	manager.tick(10000)
	var bot: PlayerState = registry.get_player(ArenaPracticeBot.BOT_ID)
	bot.grid_position = Vector2i(9,5)
	human.grid_position = Vector2i(5,5)
	human.max_health = 100000
	human.current_health = human.max_health
	return {"registry":registry,"manager":manager,"bot":bot,"human":human}

func _run() -> void:
	seed(224)
	for class_id in [1,6]: _test_caster(class_id)
	for class_id in [2,4,5,7,12]: _test_hybrid(class_id)
	_test_avoided_melee()
	_test_resource_pressure()
	_test_range_and_obstacles()
	for registry in registries: registry.queue_free()
	await process_frame
	print("Bot class tactics checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)

func _test_caster(class_id: int) -> void:
	var f := _fixture(class_id)
	var bot: PlayerState = f.bot
	var manager: ArenaPracticeBot = f.manager
	var offensive: Array[int] = []
	var times: Array[int] = []
	var legal := true
	var ledger := true
	var high_blue := false
	var last_potion := 0
	var heavy := 53 if class_id==1 else 59
	for step in range(1500):
		var now := 10000+step*20
		f.registry.advance_runtime(now)
		var mana_before := bot.current_mana
		var expected := mana_before
		for action: Dictionary in manager.tick(now):
			if action.kind=="cast":
				var id := int(action.result.event.spell_id)
				legal = legal and ClassCatalog.can_cast(class_id,id)
				expected -= int(SpellCatalog.get_spell(id).mana)
				if int(action.result.event.target_id)==301 and id!=25:
					offensive.append(id)
					times.append(now)
			elif action.kind=="recovery" and str(action.result.event.action).ends_with("potion"):
				legal = legal and (last_potion==0 or now-last_potion>=RecoveryRules.POTION_INTERVAL_MSEC)
				last_potion=now
				if action.result.event.action=="mana_potion":
					expected+=int(action.result.event.amount)
					high_blue=high_blue or mana_before>=bot.max_mana*0.65
		ledger = ledger and bot.current_mana==expected and bot.current_mana>=0 and bot.current_mana<=bot.max_mana
	var pairs := 0
	for i in range(1,offensive.size()):
		if offensive[i]==heavy and offensive[i-1]==heavy: pairs+=1
		legal = legal and times[i]-times[i-1]>=ArenaPracticeBot.CAST_INTERVAL_MSEC
	_check(offensive.size()>=6 and offensive.slice(0,2)==[heavy,heavy],"Caster%d opens with its two strongest legal spells" % class_id)
	_check(pairs>=2,"Caster%d rebuilds mana and returns to a heavy pair (%d pairs)" % [class_id,pairs])
	_check(legal and ledger,"Caster%d pays real costs, recovers real mana and respects intervals" % class_id)
	_check(not offensive.has(53) if class_id==6 else high_blue,"Druid never borrows Apocalypse; mage replenishes beyond the old65%% mana ceiling")
	if class_id==1: _check(offensive.has(51) and offensive.has(41),"Mana-limited mage uses Discharge then economical Firestorm before rebuilding")
	print("Caster%d sequence: %s" % [class_id,str(offensive)])

func _test_hybrid(class_id: int) -> void:
	var f := _fixture(class_id)
	var manager: ArenaPracticeBot = f.manager
	var history: Array[Dictionary] = []
	var legal := true
	var last_spell := 0
	var last_melee := 0
	for step in range(700):
		var now := 10000+step*20
		f.registry.advance_runtime(now)
		for action: Dictionary in manager.tick(now):
			if action.kind=="cast":
				var id := int(action.result.event.spell_id)
				legal = legal and ClassCatalog.can_cast(class_id,id) and (last_melee==0 or now-last_melee>=SpellCatalog.ATTACK_SPELL_GAP_MSEC)
				last_spell=now
				if int(action.result.event.target_id)==301: history.append({"id":id,"time":now})
			elif action.kind=="melee":
				legal = legal and (last_spell==0 or now-last_spell>=SpellCatalog.SPELL_ATTACK_GAP_MSEC) and (last_melee==0 or now-last_melee>=CombatRules.BASIC_ATTACK_COOLDOWN_MSEC)
				last_melee=now
				history.append({"id":-1,"time":now})
	var chain := false
	for i in range(history.size()-2):
		if history[i].id==25 and history[i+1].id==-1 and history[i+2].id==51: chain=true
	_check(chain,"Hybrid%d performs legal Paralyze→melee→Discharge" % class_id)
	_check(legal,"Hybrid%d keeps both600ms transitions and real melee cooldown, including misses" % class_id)
	print("Hybrid%d actions: %s" % [class_id,str(history.slice(0,6))])

func _test_avoided_melee() -> void:
	for outcome in ["evaded","blocked"]:
		var f := _fixture(2,outcome)
		f.bot.grid_position=Vector2i(6,5)
		var events: Array[Dictionary]=[]
		var clock := {"now":0}
		f.registry.basic_attack_resolved.connect(func(event: Dictionary) -> void:
			var copy := event.duplicate()
			copy["time"]=clock.now
			events.append(copy))
		var follows := false
		for step in range(350):
			var now := 10000+step*20
			clock.now=now
			f.registry.advance_runtime(now)
			for action: Dictionary in f.manager.tick(now):
				if action.kind=="cast" and int(action.result.event.spell_id)==51 and not events.is_empty(): follows = follows or now-int(events[-1].time)>=SpellCatalog.ATTACK_SPELL_GAP_MSEC
		var legal := events.size()>=2
		for i in range(events.size()):
			legal = legal and events[i].outcome==outcome and int(events[i].amount)==0
			if i>0: legal = legal and int(events[i].time)-int(events[i-1].time)>=CombatRules.BASIC_ATTACK_COOLDOWN_MSEC
		_check(legal,"A %s melee consumes the normal bot attack cadence without fake damage" % outcome)
		_check(follows,"Bot naturally follows %s melee with a legal Discharge instead of free retries" % outcome)

func _test_resource_pressure() -> void:
	var f := _fixture(1)
	var bot: PlayerState = f.bot
	var manager: ArenaPracticeBot = f.manager
	bot.current_health=100
	bot.current_mana=0
	var red := 0
	var blue := 0
	var legal := true
	for step in range(700):
		var now := 10000+step*20
		f.registry.advance_runtime(now)
		for action: Dictionary in manager.tick(now):
			if action.kind=="recovery":
				if action.result.event.action=="health_potion": red+=1
				if action.result.event.action=="mana_potion": blue+=1
		legal = legal and bot.current_health>0 and bot.current_mana>=0 and bot.current_mana<=bot.max_mana
	_check(red>=8 and blue>=8 and legal,"Under simultaneous low HP/MP, bot keeps emergency reds then rebuilds useful mana")

func _test_range_and_obstacles() -> void:
	var f := _fixture(1)
	var manager: ArenaPracticeBot = f.manager
	manager._observed_cell=Vector2i(19,11)
	var actions: Array[Dictionary]=[]
	manager._attack(f.bot,true,true,12000,actions)
	_check(actions.is_empty(),"Out-of-range rival cannot unlock a combo or trigger a remote cast")
	f.bot.grid_position=Vector2i(1,2)
	f.human.grid_position=Vector2i(3,2)
	manager._observed_cell=f.human.grid_position
	actions.clear()
	manager._attack(f.bot,true,true,12000,actions)
	var direction := manager._movement_step(f.bot,f.human.grid_position,true,12000)
	_check(not CombatRules.has_clear_shot(f.registry.get_arena_id(),f.bot.grid_position,f.human.grid_position) and actions.is_empty() and direction!=-1 and ArenaData.is_walkable(f.registry.get_arena_id(),f.bot.grid_position+MovementRules.get_offset(direction)),"Blocked line of sight triggers legal repositioning rather than casting through a tree")
	f.bot.current_mana=999
	manager._combo_step=1
	var spell := manager._combo_spell(f.bot,12000)
	_check(spell!=53 and int(SpellCatalog.get_spell(spell).mana)<=f.bot.current_mana,"Mana loss before second Apocalypse chooses an affordable fallback")

func _check(condition: bool, message: String) -> void:
	checks+=1
	if not condition: failures+=1
	print(("PASS: " if condition else "FAIL: ")+message)
