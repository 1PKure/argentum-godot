extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("FAIL: ",label)
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var registry:=PlayerRegistry.new();root.add_child(registry);var human:=registry.add_player(801)
 var manager:=ArenaPracticeBot.new(registry,2441)
 var now:=10000
 for id:int in [2,4,5,7,12]:
  manager.request(801,true,id,id,now);manager.tick(now+3000)
  var bot:=registry.get_player(ArenaPracticeBot.BOT_ID)
  bot.grid_position=Vector2i(9,5);human.grid_position=Vector2i(5,5)
  manager._observed_cell=human.grid_position;manager._observed_rooted=false
  manager._semi_combos=10;manager._semi_step=1;manager._semi_until=now+10000
  manager._next_control=now+4000;manager._next_spell=now+4000
  bot.current_mana=int(SpellCatalog.get_spell(25).mana)+int(SpellCatalog.get_spell(27).mana)
  var actions:Array[Dictionary]=[]
  manager._semi_attack(bot,now+4000,actions)
  check(actions.any(func(event:Dictionary)->bool:return event.kind=="cast" and int(event.result.event.spell_id)==25),"Hybrid%d re-roots fleeing rival without waiting for full damage budget"%id)
  check(manager._next_control>=now+7000 and manager._next_control<=now+8000,"Hybrid%d control has3–4second cooldown"%id)
  # A real remove invalidates the plan; while control cools down there is no air spam.
  manager._observed_rooted=false;manager._next_spell=now+5500
  manager._semi_combos=10;bot.current_mana=bot.max_mana
  actions.clear();manager._semi_step=0
  for retry in range(30):manager._semi_attack(bot,now+5500+retry*20,actions)
  check(actions.is_empty(),"Hybrid%d conserves its chase instead of air Discharge/fire"%id)
  now+=15000
 registry.queue_free()
 for id:int in [4,7,12]:_running_chase(id)
 await process_frame
 print("Hybrid chase checks: %d; failures: %d"%[checks,failures]);quit(1 if failures else 0)

func _running_chase(class_id:int)->void:
 var registry:=PlayerRegistry.new();root.add_child(registry)
 var human:=registry.add_player(901);var manager:=ArenaPracticeBot.new(registry,2431+class_id)
 manager.request(901,true,class_id,1,7000);manager.tick(10000)
 human.max_health=100000;human.current_health=100000
 human.grid_position=Vector2i(5,3);registry.get_player(ArenaPracticeBot.BOT_ID).grid_position=Vector2i(10,7)
 var roots:=0;var hits:=0;var next_move:=10000;var remove_due:=0;var request:=0;var last_root:=0;var legal:=true
 var direction:=MovementRules.Direction.EAST
 for step in range(1100):
  var now:=10000+step*20
  registry.advance_runtime(now)
  var rooted:=human.active_effects.has("Paralizado") or human.active_effects.has("Inmovilizado")
  if rooted:
   if remove_due==0:remove_due=now+400
   if now>=remove_due:
    request+=1;registry.try_cast_spell(901,27,human.grid_position,request,now)
  else:remove_due=0
  if now>=next_move:
   var cell:=human.grid_position
   if direction==1 and cell.x>=14:direction=2
   elif direction==2 and cell.y>=8:direction=3
   elif direction==3 and cell.x<=5:direction=0
   elif direction==0 and cell.y<=3:direction=1
   registry.try_move_player(901,direction,now);next_move=now+140
  for event:Dictionary in manager.tick(now):
   if event.kind=="cast" and int(event.result.event.spell_id)==25:
    roots+=1
    legal=legal and (last_root==0 or now-last_root>=3000)
    last_root=now
    if int(event.result.event.get("target_id",0))==901:hits+=1
 check(roots>=3 and hits>=2 and legal,"Hybrid%d actually roots a running mage repeatedly with legal costs/cooldowns (%d casts,%d hits)"%[class_id,roots,hits])
 registry.queue_free()
