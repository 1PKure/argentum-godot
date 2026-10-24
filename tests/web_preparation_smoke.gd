extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("FAIL: ",label)
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var registry:=PlayerRegistry.new();root.add_child(registry)
 var actor:=registry.add_player(901);var rival:=registry.add_player(902)
 registry.try_select_class(901,8,1000)
 rival.max_health=100000;rival.current_health=100000
 var now:=10000
 for arena:String in ArenaData.IDS:
  registry.set_arena(arena)
  var definition:=ArenaData.get_definition(arena)
  for cell:Vector2i in definition.scenery_cells:
   actor.grid_position=cell+Vector2i.LEFT;rival.grid_position=Vector2i(15,5)
   var moved:=registry.try_move_player(901,MovementRules.Direction.EAST,now)
   check(moved!=null and actor.grid_position==cell,"Authoritative movement enters former corner obstacle: %s/%s"%[arena,cell])
   actor.grid_position=cell+Vector2i.LEFT;rival.grid_position=cell+Vector2i.RIGHT
   var shot:=registry.try_ranged_attack(901,rival.grid_position,now,now+1000)
   check(shot.ok,"Real arrow crosses decorative prop: %s/%s"%[arena,cell])
   now+=3000
  check(not ArenaData.is_walkable(arena,Vector2i(-1,2)) and not ArenaData.is_walkable(arena,Vector2i(20,2)),"Arena retains outer boundaries: "+arena)
 registry.remove_player(902)
 var manager:=ArenaPracticeBot.new(registry,2410)
 registry.try_select_class(901,1,now)
 manager.request(901,true,1,1,now);manager.tick(now+3000)
 var bot:=registry.get_player(ArenaPracticeBot.BOT_ID)
 bot.grid_position=Vector2i(9,5);actor.grid_position=Vector2i(5,5)
 manager._observed_cell=actor.grid_position;manager._combo_rebuilding=true;manager._fallback_used=true
 manager._next_spell=now+4000;bot.current_mana=1400
 var actions:Array[Dictionary]=[]
 manager._attack(bot,true,true,now+4000,actions)
 check(actions.is_empty() and manager._next_offense==now+4000+ArenaPracticeBot.THINK_MSEC,"Mage reevaluates empty combo budget without wasting an entire cast interval")
 bot.current_mana=1530
 manager._attack(bot,true,true,manager._next_offense,actions)
 check(actions.any(func(event:Dictionary)->bool:return event.kind=="cast" and int(event.result.event.spell_id)==53),"Real blue-sized recovery immediately resumes Apocalypse pressure")
 check(NetworkConstants.server_url_from_arguments(["--server-url=wss://arena.example/duel"],"",true)=="wss://arena.example/duel","Web deployment can supply remote WSS without rebuilding")
 check(NetworkConstants.server_url_from_arguments(["--server-url=ws://unsafe.example"],"",true)==NetworkConstants.LOCAL_SECURE_WEBSOCKET_URL,"Web rejects insecure launch override")
 check(NetworkConstants.server_url_from_arguments([],"",false)==NetworkConstants.LOCAL_WEBSOCKET_URL,"Native development default remains intact")
 check(NetworkConstants.get_server_url()=="wss://launch.example/arena","Actual launch argument reaches connection default")
 registry.queue_free();await process_frame
 print("Web preparation checks: %d; failures: %d"%[checks,failures]);quit(1 if failures else 0)
