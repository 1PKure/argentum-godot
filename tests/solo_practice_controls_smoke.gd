extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("FAIL: ",label)
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var room:=ArenaLobbyRoom.new(91,"Practice","forest");room.add_member(5)
 check(room.configure_practice(5,true,1,false,10000).ok,"solo host enables practice")
 room.set_ready(5,true,room.revision,11000);room.tick(14000)
 var old:=room.round_id
 check(room.phase=="fighting" and room.set_paused(5,true,15000).ok,"running practice pauses")
 check(room.configure_practice(5,true,6,true,18000).ok,"paused host restarts with new class")
 check(room.phase=="countdown" and room.round_id!=old and not room.paused,"restart resets clock and countdown")
 check(room.bot_class==6 and room.registry.get_player(ArenaPracticeBot.BOT_ID).class_id==6,"class is authoritative")
 check(room.registry.get_player(5).is_alive and room.winner_id==0,"restart restores player without reward")
 room.tick(21000);check(room.phase=="fighting","new clock reaches combat")
 room.set_paused(5,true,22000)
 check(room.configure_practice(5,false,6,true,25000).ok,"paused host removes bot")
 check(room.phase=="waiting" and not room.paused and not room.registry.has_player(ArenaPracticeBot.BOT_ID),"removal clears avatar and pause")
 check(room.winner_id==0 and room.round_id!=old,"cancellation grants no win")
 room.add_member(6)
 check(not room.configure_practice(5,true,1,true,26000).ok,"PvP cannot replace rival")
 check(not room.configure_practice(6,true,1,true,26000).ok,"guest cannot control practice")
 room.dispose();print("Solo practice checks: %d; failures: %d"%[checks,failures]);quit(1 if failures else 0)
