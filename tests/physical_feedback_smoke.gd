extends SceneTree
var checks:=0
var failures:=0
func _initialize():call_deferred("_run")
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",label)
func _run():
 var world=load("res://client/scenes/client_world.gd").new()
 root.add_child(world)
 world._spawn_player(PlayerState.new(7,"Actor",Vector2i(4,5)).to_dictionary())
 world._spawn_player(PlayerState.new(8,"Rival",Vector2i(5,5)).to_dictionary())
 for outcome:String in ["evaded","blocked"]:
  world._on_melee_resolved({"caster_id":7,"target_id":8,"amount":0,"outcome":outcome})
  check(world._blood_impacts.is_empty() and world._melee_audio.is_empty(),"avoided melee has no hit blood/audio")
  var feedback=world._spell_effects[-1]
  check(feedback._label.text==("Bloqueó" if outcome=="blocked" else "Esquivó"),"precise avoidance text")
  feedback.set_process(false)
  world._avatars[8].position+=Vector2(5,0)
  feedback._process(0.1)
  check(feedback.position.x==world._avatars[8].position.x,"feedback follows moving target")
 var hud=load("res://client/ui/combat_hud.gd").new()
 root.add_child(hud)
 hud._local_peer_id=7
 hud._on_basic_attack_event({"caster_id":7,"target_id":8,"caster_name":"Actor","target_name":"Rival","amount":0,"outcome":"blocked"})
 check(hud.console.entries[-1].text.contains("bloqueó"),"block is not shown as zero damage")
 hud._local_peer_id=99
 var n:int=hud.console.entries.size()
 hud._on_basic_attack_event({"caster_id":7,"target_id":8,"amount":0,"outcome":"evaded"})
 check(hud.console.entries.size()==n,"unrelated actor sees no combat log")
 world.queue_free();hud.queue_free()
 await process_frame
 await create_timer(0.25).timeout
 print("Physical feedback checks: %d; failures: %d"%[checks,failures])
 quit(1 if failures else 0)
