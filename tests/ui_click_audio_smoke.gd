extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("FAIL: ",label)
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var ui:=root.get_node("UIClickAudio")
 var button:=Button.new();root.add_child(button);await process_frame
 var transient:=Button.new();root.add_child(transient);transient.free();await process_frame
 check(not is_instance_valid(transient),"Freed transient controls do not leave deferred callbacks")
 var before:int=ui.played_count
 button.pressed.emit();check(ui.played_count==before+1,"New lobby/game button produces click")
 await create_timer(.04).timeout
 ui._wire(button);button.pressed.emit()
 check(button.pressed.get_connections().size()==1,"Repeated registration does not duplicate sound")
 before=ui.played_count
 await create_timer(.04).timeout
 button.disabled=true;button.position=Vector2(20,20);button.size=Vector2(100,40)
 await process_frame
 var down:=InputEventMouseButton.new();down.position=Vector2(50,40);down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true
 Input.parse_input_event(down);await process_frame
 var up:=InputEventMouseButton.new();up.position=down.position;up.button_index=MOUSE_BUTTON_LEFT
 Input.parse_input_event(up);await process_frame
 check(ui.played_count==before,"Disabled buttons stay silent")
 var popup:=PopupMenu.new();root.add_child(popup);await process_frame
 ui._last_click=-1000
 popup.id_pressed.emit(1);check(ui.played_count==before+1,"Dropdown selections share click sound")
 var stream:AudioStreamWAV=ui._player.stream
 check(stream.format==AudioStreamWAV.FORMAT_16_BITS and not stream.stereo and stream.get_length()<.06,"Click is a short reusable PCM sample")
 var peak:=0.0
 for index in range(stream.data.size()/2):peak=maxf(peak,absf(stream.data.decode_s16(index*2)/32768.0))
 check(peak>0.1 and peak<.8,"Click contains audible data with headroom")
 check(ui._player.bus==ArenaAudioMix.BUS,"UI click obeys effects volume")
 stream=null
 button.queue_free();popup.queue_free();ui._player.stop();ui._player.stream=null;await create_timer(.15).timeout
 print("UI click checks: %d; failures: %d"%[checks,failures]);quit(1 if failures else 0)
