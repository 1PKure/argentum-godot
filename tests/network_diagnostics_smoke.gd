extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run_test")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("FAIL: ",label)
func run_test()->void:
 var d:=root.get_node("NetworkDiagnostics")
 d.set_process(false);d.reset()
 check(d.last_ping_ms==-1 and d.ping_samples.is_empty(),"No invented zero ping before first reply")
 d._pending_probes[1]=1000000
 d.accept_ping(1,true,1137000)
 check(d.last_ping_ms==137 and d.measured_moves,"RTT is measured with two client monotonic timestamps")
 d.accept_ping(1,true,2000000)
 d.accept_ping(999,true,2000000)
 check(d.ping_samples.size()==1,"Duplicate and uncorrelated replies cannot create samples")
 d._pending_moves[2]=2000000
 d.accept_move(2,true,3000,2190000)
 check(d.confirmed==1 and d.move_samples[0]==190.0 and d.server_samples[0]==3.0,"Movement acknowledgment separates full round trip and server handler time")
 d._pending_moves[3]=3000000
 d.accept_move(3,false,200,3190000)
 check(d.blocked==1 and d.move_samples.size()==1,"Blocked movement does not contaminate accepted confirmation percentiles")
 d._pending_moves[4]=0;d._pending_probes[5]=0;d.expire(7000)
 check(d.move_timeouts==1 and d.probe_timeouts==1 and d.last_ping_ms==-1,"Expired replies are marked unconfirmed and ping becomes stale")
 d.accept_move(4,true,1,7000000)
 check(d.confirmed==1,"Late expired acknowledgment is ignored")
 d.record_queue(4);d.record_queue(1)
 check(d.queued_steps==1 and d.peak_queued_steps==4,"Visual queue reports current and peak independently")
 for i in range(100): d._append(d.move_samples,float(i))
 check(d.move_samples.size()==60 and d.percentile(d.move_samples,0.95)==96,"Rolling window and p95 use bounded real samples")
 d.reset()
 check(d.move_samples.is_empty() and d._pending_moves.is_empty() and d.blocked==0 and not d.measured_moves,"Reconnect reset cannot reuse stale session data")
 print("Network diagnostic checks: %d; failures: %d"%[checks,failures]);quit(1 if failures else 0)
