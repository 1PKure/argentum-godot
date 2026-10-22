extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("FAIL: ",label)
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var registry:=PlayerRegistry.new();root.add_child(registry)
 var human:=registry.add_player(501)
 var manager:=ArenaPracticeBot.new(registry,924)
 manager.request(501,true,1,1,7000);manager.tick(10000)
 var bot:=registry.get_player(ArenaPracticeBot.BOT_ID)
 bot.current_mana=1000
 check(manager._combo_spell(bot,11000)==51,"Discharge preferred to Firestorm when affordable")
 manager._record_combo_spell(bot,51,11000)
 check(manager._combo_spell(bot,12500)==0,"Bot saves recovered mana instead of repeating cheap spells")
 bot.current_mana=bot.max_mana
 check(manager._combo_spell(bot,14000)==53,"Full budget returns to Apocalypse")
 manager._combo_step=0;manager._fallback_used=false;bot.current_mana=200
 check(manager._combo_spell(bot,16000)==41,"Firestorm is a last resort below Discharge cost")
 check(SpellCatalog.direct_damage(41,100)==90,"Firestorm reduced ten percent for every caster")
 # Damage under continuous red-potion pressure must still allow a legal heal.
 manager.request(501,true,1,2,20000);manager.tick(23000)
 bot=registry.get_player(ArenaPracticeBot.BOT_ID)
 human.max_health=100000;human.current_health=100000
 human.grid_position=Vector2i(5,5);bot.grid_position=Vector2i(9,5)
 var heals:Array[int]=[]
 var last_cast:=0
 var legal:=true
 for i in range(1500):
  var now:=24000+i*20
  registry.advance_runtime(now)
  if i%30==0:bot.current_health=maxi(70,bot.current_health-45)
  for event:Dictionary in manager.tick(now):
   if event.kind=="cast":
    if last_cast:legal=legal and now-last_cast>=ArenaPracticeBot.CAST_INTERVAL_MSEC
    last_cast=now
    if int(event.result.event.spell_id)==31:
     heals.append(now)
     check(manager._potion_due>=now+700,"Healing commits to a potion pause")
 check(not heals.is_empty(),"A pressured bot actually uses Heal while taking red potions")
 for i in range(1,heals.size()):check(heals[i]-heals[i-1]>=4200,"Healing has a real cooldown")
 check(legal,"Defensive healing shares normal cast cadence")
 print("Healing casts under pressure: ",heals.size())
 registry.queue_free();await process_frame
 print("Bot combo/recovery checks: %d; failures: %d"%[checks,failures]);quit(1 if failures else 0)
