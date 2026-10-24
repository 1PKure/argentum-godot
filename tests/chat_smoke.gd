extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value: failures+=1;push_error(message)
func _run() -> void:
	var service := ArenaChatService.new()
	check(not service.submit(1,[1,2],3,"Falso","Hola",1,0).ok,"outsider cannot inject into a room")
	var result := service.submit(1,[1,2],1,"Nick real"," Hola ñ [b]texto[/b]\n",1,0)
	check(result.ok and result.message.text=="Hola ñ [b]texto[/b]" and result.message.nickname=="Nick real","Unicode, plain markup and server nickname are preserved with one-line trim")
	check(not service.submit(1,[1,2],1,"Nick real","Duplicado",1,1000).ok,"replayed nonce is rejected")
	check(not service.submit(1,[1,2],1,"Nick real","Spam",2,100).ok,"same sender has an enforced cooldown")
	check(service.submit(1,[1,2],2,"Segundo","Hola",1,100).ok,"another sender has its own cooldown")
	check(not service.submit(1,[1,2],1,"Nick real","x".repeat(161),3,1000).ok,"oversized text rejected")
	check(not service.submit(1,[1,2],1,"Nick real","\n\t",4,2000).ok,"empty/control-only message rejected")
	check(ArenaChatService.clean("a\u202eb")=="ab","direction override cannot rearrange UI text")
	check(service.submit(2,[4,5],4,"Otra sala","Privado",1,0).ok and service.history(1).size()==2 and service.history(2).size()==1,"histories stay separated by actual room")
	for index in 40: service.submit(1,[1,2],1,"Nick real","Mensaje%d"%index,10+index,3000+index*800)
	check(service.history(1).size()==30,"history is bounded to 30 messages")
	var copy := service.history(1)
	copy[0].text="Modificado"
	check(service.history(1)[0].text!="Modificado","client snapshot cannot mutate stored history")
	service.prune([2])
	check(service.history(1).is_empty() and service.history(2).size()==1,"closing a room retires its conversation")
	service.forget_peer(4)
	check(service.submit(2,[4,5],4,"Otra sala","Nueva conexión",1,0).ok,"reconnection clears nonce/rate ownership")
	var world = load("res://client/scenes/client_world.gd").new()
	root.add_child(world)
	world._spawn_player(PlayerState.new(1,"Local",Vector2i(5,5)).to_dictionary())
	world._spawn_player(PlayerState.new(2,"Rival",Vector2i(6,5)).to_dictionary())
	var own = world._avatars[1]
	var other = world._avatars[2]
	own.set_process(false);other.set_process(false)
	world._speech.set_process(false)
	world._on_chat_message({"sender_id":1,"text":"Estamos muy cerca y podemos charlar"})
	world._on_chat_message({"sender_id":2,"text":"Este texto tampoco debería superponerse"})
	await process_frame
	world._speech._process(0)
	var ours: Label = world._speech.entries[own.get_instance_id()].label
	var theirs: Label = world._speech.entries[other.get_instance_id()].label
	check(not ours.get_rect().grow(3).intersects(theirs.get_rect()) and ours.position.y < theirs.position.y,"local speech rises above nearby player's text")
	var before := ours.position
	own.position+=Vector2(10,5)
	world._speech._process(0)
	check(ours.position.x==before.x+10,"speech follows interpolated actor position")
	var event := {"caster_id":1,"target_id":2,"spell_id":51,"amount":100,"words":"Vax In Tar","origin_x":5,"origin_y":5,"target_x":6,"target_y":5}
	world._on_spell_resolved(event)
	check(world._speech.entries[own.get_instance_id()].kind=="spell" and world._speech.entries[own.get_instance_id()].label.text=="Vax In Tar","confirmed spell replaces speaker's chat words")
	check(world._spell_effects[0].managed_words and not world._spell_effects[0]._words.visible,"spell visual does not duplicate managed overhead text")
	world._speech._process(1.26)
	check(not world._speech.entries.has(own.get_instance_id()) and world._speech.entries.has(other.get_instance_id()),"spell words expire without removing other player's chat")
	world._speech._process(3)
	check(world._speech.entries.is_empty(),"chat disappears after four seconds")
	world._on_chat_message({"sender_id":1,"text":"Una última frase"})
	world.clear_session()
	check(world._speech.entries.is_empty(),"leaving/rebuilding world clears speech immediately")
	world.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	print("Chat service/speech checks: %d; failures: %d"%[checks,failures])
	quit(1 if failures else 0)
