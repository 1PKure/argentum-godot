class_name ArenaRankingRemote
extends Node
## Serialized persistence jobs. HTTP awaits yield to combat; only committed state is visible.
class Job extends RefCounted:
 signal completed(result:Dictionary)
 var kind:String
 var arguments:Array
 var operation:=Crypto.new().generate_random_bytes(16).hex_encode()
var store:ArenaRankingStore
var _url:=""
var _token:=""
var _busy:=false
var _jobs:Array[Job]=[]

func initialize(active:ArenaRankingStore,url:String,token:String)->bool:
 if not url.begins_with("http://127.0.0.1:") or token.length()<32:return false
 store=active;_url=url.trim_suffix("/");_token=token
 var response:=await _request(HTTPClient.METHOD_GET,"/state")
 if not response.ok:return false
 var payload:Variant=response.data.get("payload")
 if payload==null:payload={"schema":1,"revision":0,"updated_at":int(Time.get_unix_time_from_system()),"players":{},"awards":{}}
 return payload is Dictionary and store.accept_private_payload(payload)

func register(identity:String,secret:String,nickname:String)->Dictionary:
 return await _submit("register",[identity,secret,nickname])
func record_victory(round_id:String,identity:String,mode:String)->Dictionary:
 return await _submit("victory",[round_id,identity,mode])
func _submit(kind:String,arguments:Array)->Dictionary:
 if _jobs.size()>=128:return {"ok":false,"message":"El ranking está ocupado. Intentá nuevamente."}
 var job:=Job.new();job.kind=kind;job.arguments=arguments;_jobs.append(job)
 _pump.call_deferred()
 return await job.completed
func _pump()->void:
 if _busy:return
 _busy=true
 while not _jobs.is_empty():
  var job:=_jobs[0]
  var result:Dictionary={"ok":false,"message":"No se pudo confirmar el guardado del ranking. Intentá nuevamente."}
  for attempt in range(2):
   var candidate:=ArenaRankingStore.new(store.storage_path+".candidate")
   if not candidate.accept_private_payload(store.export_private_payload()):break
   result=candidate.register(str(job.arguments[0]),str(job.arguments[1]),str(job.arguments[2])) if job.kind=="register" else candidate.record_victory(str(job.arguments[0]),str(job.arguments[1]),str(job.arguments[2]))
   if not result.ok or candidate.revision==store.revision:break
   var response:=await _request(HTTPClient.METHOD_POST,"/commit",{"expected_revision":store.revision,"payload":candidate.export_private_payload(),"public_snapshot":candidate.snapshot(),"operation_id":job.operation})
   if response.ok and _accept(response.data.get("payload")):
    result.player=store.get_player(str(job.arguments[0] if job.kind=="register" else job.arguments[1]))
    break
   if int(response.get("code",0))==409 and _accept(response.data.get("payload")):
    result={"ok":false,"message":"El ranking cambió; intentá nuevamente."}
    continue
   result={"ok":false,"message":"No se pudo confirmar el guardado del ranking. Intentá nuevamente."}
   break
  _jobs.pop_front()
  job.completed.emit(result)
 _busy=false
func _accept(payload:Variant)->bool:
 return payload is Dictionary and store.accept_private_payload(payload)
func _request(method:int,path:String,data:Dictionary={})->Dictionary:
 var http:=HTTPRequest.new();http.timeout=8;http.use_threads=true;http.body_size_limit=9*1024*1024;add_child(http)
 var error:=http.request(_url+path,["Authorization: Bearer "+_token,"Content-Type: application/json"],method,JSON.stringify(data) if method==HTTPClient.METHOD_POST else "")
 if error!=OK:http.queue_free();return {"ok":false}
 var response:Array=await http.request_completed;http.queue_free()
 var parsed:Variant=JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
 return {"ok":int(response[0])==HTTPRequest.RESULT_SUCCESS and int(response[1])==200 and parsed is Dictionary,"code":int(response[1]),"data":parsed if parsed is Dictionary else {}}
