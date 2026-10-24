extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run_test")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("FAIL: ",label)
func run_test()->void:
 var n:=root.get_node("NetworkManager")
 var d:=root.get_node("NetworkDiagnostics")
 if OS.get_cmdline_user_args().has("--diagnostic-server"):
  d.move_requested.connect(func(id:int,direction:int,sequence:int)->void:
   var started:=Time.get_ticks_usec()
   # Controlled processing delay verifies that the acknowledgment is awaited.
   await create_timer(0.2).timeout
   d.send_move_receipt(id,sequence,direction==1,Time.get_ticks_usec()-started)
  )
  n.start_server(17881,"127.0.0.1")
  print("DIAGNOSTIC SERVER READY")
  await create_timer(15).timeout
  n.stop();quit();return
 n.start_client("ws://127.0.0.1:17881")
 var deadline:=Time.get_ticks_msec()+5000
 while not d.measured_moves and Time.get_ticks_msec()<deadline:await process_frame
 check(d.measured_moves and d.last_ping_ms>=0,"Real WebSocket ping negotiates diagnostic movement")
 check(d.request_move(1),"Measured movement travels over the real connection")
 deadline=Time.get_ticks_msec()+3000
 while d.confirmed==0 and Time.get_ticks_msec()<deadline:await process_frame
 check(d.confirmed==1,"Server confirms correlated movement receipt")
 check(d.move_samples.size()==1 and d.move_samples[0]>=190 and d.move_samples[0]<1500,"Movement RTT includes the injected200ms delay")
 check(d.server_samples.size()==1 and d.server_samples[0]>=190,"Server processing duration is reported independently")
 d.request_move(0)
 deadline=Time.get_ticks_msec()+3000
 while d.blocked==0 and Time.get_ticks_msec()<deadline:await process_frame
 check(d.blocked==1 and d.confirmed==1,"Blocked reply stays separate from accepted movement")
 print("Actual ping RTT ms: ",d.last_ping_ms,"; movement confirmation ms: ",d.move_samples)
 n.stop();d.reset()
 check(d.last_ping_ms==-1 and d._pending_moves.is_empty(),"Disconnect clears pending measurements")
 print("Diagnostic network checks: %d; failures: %d"%[checks,failures]);quit(1 if failures else 0)
