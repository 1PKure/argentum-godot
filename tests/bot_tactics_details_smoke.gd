extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("FAIL: ",label)
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var registry:=PlayerRegistry.new();root.add_child(registry);registry.add_player(701)
 var manager:=ArenaPracticeBot.new(registry,2410)
 for id:int in [2,4,5,7,12]:
  manager.request(701,true,id,id,10000+id*1000);manager.tick(13000+id*1000)
  var bot:=registry.get_player(ArenaPracticeBot.BOT_ID)
  check(manager._move_interval(bot)==170,"Hybrid%d uses the slower hybrid cadence"%id)
  bot.current_mana=300
  manager._semi_combos=0
  check(manager._semi_finish_spell(bot)==0,"Hybrid%d cannot open with cheap fallback"%id)
  manager._semi_combos=2
  check(manager._semi_finish_spell(bot)==0,"Hybrid%d waits for several complete combos"%id)
  manager._semi_combos=3
  var fallback:=manager._semi_finish_spell(bot)
  check(fallback in [0,39,41] and fallback not in [43,3],"Hybrid%d only permits legal fire fallback"%id)
  bot.current_mana=bot.max_mana
  check(manager._semi_finish_spell(bot)==51,"Hybrid%d prioritizes Discharge when affordable"%id)
 manager.request(701,true,1,100,50000);manager.tick(53000)
 var mage:=registry.get_player(ArenaPracticeBot.BOT_ID)
 mage.current_mana=1500;manager._combo_rebuilding=true
 check(manager._combo_spell(mage,54000)==53,"Recovering mage presses with an Apocalypse+Discharge budget")
 check(manager._move_interval(mage)==160,"Mage no longer outruns the human movement profile")
 check(manager._ready_at-manager._starts_at>=450 and manager._ready_at-manager._starts_at<=650,"Mage engages earlier after countdown")
 registry.queue_free();await process_frame
 print("Bot detail checks: %d; failures: %d"%[checks,failures]);quit(1 if failures else 0)
