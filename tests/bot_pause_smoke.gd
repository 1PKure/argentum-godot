extends SceneTree

var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ", label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var directory := ArenaLobbyDirectory.new()
	check(directory.command(1,"create",{"arena_id":"forest"},1,10000).ok,"create solo")
	var room := directory.room_for(1)
	check(not directory.pause(1,true,1,10010).ok,"waiting room cannot pause")
	check(directory.command(1,"bot",{"enabled":true,"class_id":8},2,10200).ok,"configure bot")
	check(directory.command(1,"ready",{"ready":true,"revision":room.revision},3,10400).ok,"countdown")
	room.tick(10900)
	var remaining := room.starts_at - room.game_time(10900)
	check(directory.pause(1,true,2,10900).ok,"countdown pause")
	check(room.game_time(60900) == 10900,"clock stays frozen for 50 seconds")
	check(room.tick(60900).actions.is_empty() and room.countdown == 3,"no countdown or bot catchup while paused")
	check(directory.pause(1,false,3,60900).ok,"resume")
	check(room.starts_at - room.game_time(60900) == remaining,"countdown retains remaining duration")
	room.tick(60900+remaining)
	check(room.phase == "fighting" and room.bot.phase == "active","countdown resumes normally")
	var wall := 60900+remaining
	var logical := room.game_time(wall)
	var human := room.registry.get_player(1)
	human.current_mana = 0
	human.is_meditating = true
	room.registry._next_meditation_tick[1] = logical+500
	room.registry._status_system.effects[1] = [{"kind":"root","name":"Paralizado","negative":true,"expires":logical+700}]
	room.registry._last_attack_time[1] = logical
	room.registry._last_potion_time[1] = logical
	check(directory.pause(1,true,4,wall).ok,"combat pause")
	var snapshot := room.registry.get_snapshot()
	room.tick(wall+100000)
	check(room.registry.get_snapshot() == snapshot,"paused world and meditation unchanged")
	check(directory.pause(1,false,5,wall+100000).ok,"resume combat")
	check(room.game_time(wall+100000) == logical,"game clock preserved after second pause")
	check(room.registry._last_attack_time[1]+CombatRules.BASIC_ATTACK_COOLDOWN_MSEC-room.game_time(wall+100000) == 1200,"melee cooldown not consumed by pause")
	check(room.registry._last_potion_time[1] == logical,"potion timestamp unchanged")
	room.tick(wall+100001)
	check(human.current_mana == 0 and room.registry._status_system.is_rooted(1,room.game_time(wall+100001)),"regen and paralysis retain time after resume")
	# Both newest desired states must work even within the lobby edit rate limit.
	check(directory.pause(1,true,6,wall+100002).ok and directory.pause(1,false,7,wall+100003).ok,"rapid open close accepts both requests")
	check(not directory.pause(1,true,6,wall+100004).ok and not room.paused,"stale pause replay rejected")
	check(directory.command(2,"create",{"arena_id":"desert"},1,wall+100005).ok,"separate room")
	var other := directory.room_for(2)
	check(directory.pause(1,true,8,wall+100006).ok and not other.paused,"pause isolated to own room")
	check(not directory.pause(2,true,1,wall+100007).ok,"cannot pause unrelated non-bot room")
	check(directory.pause(1,false,9,wall+100008).ok,"resume again")
	check(directory.command(3,"join",{"room_id":other.id},1,wall+100010).ok,"PvP second member")
	check(not directory.pause(2,true,2,wall+100011).ok,"PvP pause refused")
	check(CombatRules.BASIC_ATTACK_COOLDOWN_MSEC == CombatRules.RANGED_ATTACK_COOLDOWN_MSEC,"melee and arrow interval match")
	var combat := PlayerRegistry.new()
	var attacker := combat.add_player(10)
	var target := combat.add_player(11)
	attacker.facing_direction = MovementRules.Direction.EAST
	target.grid_position = attacker.grid_position + Vector2i.RIGHT
	target.current_health = 10000
	target.max_health = 10000
	check(combat.try_basic_attack(10,20000) == target,"initial melee resolves")
	var health := target.current_health
	check(combat.try_basic_attack(10,21199) == null and target.current_health == health,"melee spam rejected before1200ms")
	check(combat.try_basic_attack(10,21200) == target and target.current_health < health,"melee allowed exactly at1200ms")
	combat.free()
	directory.dispose()
	print("Bot pause checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
