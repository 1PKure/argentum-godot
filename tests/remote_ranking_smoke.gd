extends SceneTree
var checks:=0
var failures:=0
var frames:=0
func _initialize()->void:
 process_frame.connect(func()->void:frames+=1)
 call_deferred("_run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("FAIL: ",label)
func _mode(value:String)->void:
 var file:=FileAccess.open(OS.get_environment("AO_TEST_CONTROL"),FileAccess.WRITE);file.store_string(value);file.close()
func _run()->void:
 var active:=ArenaRankingStore.new("user://remote-test.json")
 var remote:=ArenaRankingRemote.new();root.add_child(remote)
 check(await remote.initialize(active,OS.get_environment("AO_STORE_URL"),OS.get_environment("AO_STORE_TOKEN")),"Actual HTTP coordinator initializes from external PostgreSQL")
 var id:="a".repeat(32);var secret:="b".repeat(64)
 if OS.get_cmdline_user_args().has("--restore"):
  check(active.get_player(id).points==200,"Fresh process with empty local cache restores200points from external storage")
  check((await remote.register(id,secret,"Probador")).ok,"Guest ownership survives process restart")
 else:
  check((await remote.register(id,secret,"Probador")).ok,"Profile confirms only after durable storage")
  _mode("delay");var before:=frames
  check((await remote.record_victory("one",id,"pvp")).ok,"Confirmed victory persists through real SQL function")
  check(frames-before>=5,"Delayed storage does not block the Godot frame loop")
  check(active.get_player(id).points==100,"Live snapshot includes committed points")
  var revision:=active.revision
  var duplicate:=await remote.record_victory("one",id,"pvp")
  check(duplicate.ok and not duplicate.awarded and active.revision==revision,"Duplicate victory cannot award again")
  _mode("fail")
  check(not (await remote.record_victory("failure",id,"bot")).ok and active.get_player(id).points==100,"Storage outage never confirms or exposes unsaved points")
  _mode("lost")
  check(not (await remote.record_victory("lost-reply",id,"bot")).ok and active.get_player(id).points==100,"Lost acknowledgment keeps last committed client snapshot")
  check((await remote.record_victory("lost-reply",id,"bot")).ok and active.get_player(id).points==200,"CAS recovery finds persisted victory without duplicating it")
  check(not (await remote.register(id,"c".repeat(64),"Intruso")).ok,"Remote persistence preserves guest identity verification")
 remote.queue_free();await process_frame
 print("Remote ranking checks: %d; failures: %d"%[checks,failures]);quit(1 if failures else 0)
