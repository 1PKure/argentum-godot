extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("FAIL: ",label)
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var registry:=PlayerRegistry.new();root.add_child(registry)
 var human:=registry.add_player(801)
 var manager:=ArenaPracticeBot.new(registry,2410)
 manager.request(801,true,1,1,7000);manager.tick(10000)
 var bot:=registry.get_player(ArenaPracticeBot.BOT_ID)
 bot.grid_position=Vector2i(9,5);human.grid_position=Vector2i(5,5)
 human.current_health=100000;human.max_health=100000
 bot.current_health=150;bot.current_mana=0
 var lanes:Dictionary={};var previous:=0;var intervals:Array[int]=[];var legal:=true
 for i in range(150):
  var now:=11000+i*10
  registry.advance_runtime(now)
  for event:Dictionary in manager.tick(now):
   if event.kind=="recovery" and str(event.result.event.action).ends_with("potion"):
    var source:=str(event.result.event.source)
    if lanes.has(source):legal=legal and now-int(lanes[source])>=RecoveryRules.POTION_INTERVAL_MSEC
    if previous:intervals.append(now-previous)
    lanes[source]=now;previous=now
 check(lanes.size()==2 and legal,"Bot uses two legal potion lanes without bypassing per-lane cooldowns")
 check(intervals.has(250) and intervals.all(func(gap:int)->bool:return gap>=RecoveryRules.POTION_COMBINED_MIN_MSEC),"Recovery is slightly faster, retaining the human shared floor")
 # A fresh root with spell ready retains perception delay, without instant removal.
 manager.request(801,true,1,2,20000);manager.tick(23000)
 bot=registry.get_player(ArenaPracticeBot.BOT_ID)
 bot.grid_position=Vector2i(9,5);human.grid_position=Vector2i(5,5)
 check(registry.try_cast_spell(801,25,bot.grid_position,1,24000).ok,"Player can root bot for reaction test")
 manager._next_offense=100000;manager._next_move=100000
 var removed:=0
 for i in range(100):
  var now:=24000+i*10
  registry.advance_runtime(now)
  for event:Dictionary in manager.tick(now):
   if event.kind=="cast" and int(event.result.event.spell_id)==27:removed=now
 check(removed>=24520 and removed<=24700,"Remove reacts in520–700ms when the shared spell clock is ready")
 # A moderately wounded hybrid with a pending red still lands a real melee follow-up.
 manager.request(801,true,2,3,30000);manager.tick(33000)
 bot=registry.get_player(ArenaPracticeBot.BOT_ID)
 bot.grid_position=Vector2i(6,5);human.grid_position=Vector2i(5,5)
 bot.current_health=roundi(bot.max_health*.5)
 manager._defending=true;manager._potion_due=35000
 manager._observed_cell=human.grid_position;manager._observed_rooted=true
 manager._next_offense=34000;manager._next_spell=34000;manager._next_melee=34000
 manager._next_move=100000;manager._next_heal=100000
 var actions:Array[Dictionary]=[];manager._semi_attack(bot,34000,actions)
 check(actions.any(func(event:Dictionary)->bool:return event.kind=="melee"),"Pending potion no longer starves hybrid melee at moderate health")
 check(manager._semi_step==2,"Melee commits hybrid to its Discharge finisher")
 actions.clear();manager._semi_attack(bot,34600,actions)
 check(actions.any(func(event:Dictionary)->bool:return event.kind=="cast" and int(event.result.event.spell_id)==51),"Wounded hybrid completes legal melee→Discharge")
 registry.queue_free();await process_frame
 print("Bot pressure checks: %d; failures: %d"%[checks,failures]);quit(1 if failures else 0)
