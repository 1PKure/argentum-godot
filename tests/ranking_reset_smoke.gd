extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("FAIL: ",label)
func _initialize()->void:call_deferred("_run")
func _run()->void:
 # Runner uses an isolated XDG_DATA_HOME: this exercises actual default startup paths.
 var id:="a".repeat(32);var secret:="b".repeat(64)
 var legacy:=ArenaRankingStore.new(ArenaRankingStore.LEGACY_STORAGE_PATH)
 check(legacy.register(id,secret,"JugadorAnterior").ok,"Previous ranking has a real guest identity")
 check(legacy.record_victory("old-round",id,"pvp").ok,"Previous points exist before reset")
 var archived:=FileAccess.get_file_as_string(ArenaRankingStore.LEGACY_STORAGE_PATH).sha256_text()
 var current:=ArenaRankingStore.new()
 var snapshot:=current.snapshot()
 check(snapshot.entries.size()==1 and snapshot.entries[0].nickname=="milusita" and snapshot.entries[0].points==ArenaRankingStore.HONOR_POINTS,"New competition starts with honorary entry only")
 check(current.register(id,secret,"JugadorAnterior").ok and current.get_player(id).points==0,"Existing guest can reuse identity/nickname with zero points")
 check(current.record_victory("new-round",id,"bot").ok,"New competition accepts real victories")
 var reopened:=ArenaRankingStore.new()
 check(reopened.get_player(id).points==100,"Restart preserves new points instead of resetting every boot")
 check(FileAccess.get_file_as_string(ArenaRankingStore.LEGACY_STORAGE_PATH).sha256_text()==archived,"Previous private ranking archive remains untouched")
 check(ArenaRankingStore.new(ArenaRankingStore.LEGACY_STORAGE_PATH).get_player(id).pvp_wins==1,"Previous ledger remains readable for recovery")
 print("Ranking reset checks: %d; failures: %d"%[checks,failures]);quit(1 if failures else 0)
