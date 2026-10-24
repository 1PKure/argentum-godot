extends SceneTree

var checks := 0
var failed := 0
var directory := ArenaLobbyDirectory.new()
var requests: Dictionary = {}
var clock := 10000

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failed += 1
		print("FAIL: ",label)

func _command(peer_id: int, op: String, payload: Dictionary = {}) -> Dictionary:
	clock += 200
	requests[peer_id] = int(requests.get(peer_id,0)) + 1
	return directory.command(peer_id,op,payload,requests[peer_id],clock)

func _run() -> void:
	_check(directory.room_for(1) == null,"unassigned connection has no world")
	_check(not _command(1,"create",{"arena_id":"invalid"}).ok,"invalid map rejected")
	_check(_command(1,"create",{"arena_id":"forest","title":"Bosque"}).ok,"create first room")
	var first := directory.room_for(1)
	_check(first.members == [1] and first.state().owner_id == 1,"first member hosts")
	_check(first.registry.is_round_locked(1),"waiting member locked server side")
	_check(not _command(1,"ready",{"ready":true,"revision":first.revision}).ok,"solo without bot cannot ready")
	_check(_command(2,"join",{"room_id":first.id}).ok,"second member joins")
	_check(first.members.size() == 2,"two human capacity")
	_check(not _command(3,"join",{"room_id":first.id}).ok,"third human rejected")
	_check(_command(3,"create",{"arena_id":"desert"}).ok,"create second room")
	var second := directory.room_for(3)
	_check(first.registry != second.registry and first.bot != second.bot and first.arena != second.arena,"independent room systems")
	_check(first.registry.get_snapshot().size() == 2 and second.registry.get_snapshot().size() == 1,"snapshots contain own room only")
	_check(not first.registry.has_player(3) and not second.registry.has_player(1),"registry membership isolated")
	_check(not _command(2,"bot",{"enabled":true,"class_id":1}).ok,"guest cannot configure bot")
	_check(not _command(1,"bot",{"enabled":true,"class_id":1}).ok,"bot unavailable with two humans")
	_check(_command(3,"bot",{"enabled":true,"class_id":1}).ok,"solo bot configuration")
	_check(second.bot_enabled and second.bot.phase == "idle","configuring bot does not start round")
	var revision := first.revision
	_check(_command(1,"ready",{"ready":true,"revision":revision}).ok,"first player ready")
	_check(first.phase == "waiting","one ready does not start PvP")
	_check(not _command(2,"ready",{"ready":true,"revision":revision-1}).ok,"stale ready rejected")
	_check(_command(2,"ready",{"ready":true,"revision":revision}).ok,"second ready starts countdown")
	_check(first.phase == "countdown" and first.countdown == 3,"PvP countdown")
	_check(first.registry.is_round_locked(1) and first.registry.is_round_locked(2),"both countdown locks")
	_check(first.registry.try_move_player(1,MovementRules.Direction.EAST,clock+1000) == null,"cannot move during countdown")
	_check(not _command(2,"ready",{"ready":false,"revision":first.revision}).ok,"ready cannot cancel active countdown")
	_check(_command(3,"ready",{"ready":true,"revision":second.revision}).ok,"solo bot ready")
	_check(second.phase == "countdown" and second.bot.phase == "countdown","bot round shares countdown")
	_check(second.registry.has_player(ArenaPracticeBot.BOT_ID) and not first.registry.has_player(ArenaPracticeBot.BOT_ID),"bot entity isolated")
	var start := maxi(first.starts_at,second.starts_at)
	first.tick(start)
	second.tick(start)
	_check(first.phase == "fighting" and second.phase == "fighting","simultaneous rounds begin")
	_check(not first.registry.is_round_locked(1) and not second.registry.is_round_locked(3),"countdown unlocks combat")
	var foreign_health := second.registry.get_player(3).current_health
	first.registry.apply_damage(2,10000)
	_check(second.registry.get_player(3).current_health == foreign_health,"damage in room A leaves room B untouched")
	_check(first.settle_round(),"PvP death produces result")
	_check(first.phase == "result" and first.winner_id == 1,"correct PvP winner")
	_check(first.registry.is_round_locked(1),"round ends with actions locked")
	_check(second.phase == "fighting","room B continues after A finishes")
	_check(_command(1,"ready",{"ready":true,"revision":first.revision}).ok,"winner requests rematch")
	_check(_command(2,"ready",{"ready":true,"revision":first.revision}).ok,"opponent accepts rematch")
	_check(first.phase == "countdown" and first.registry.get_player(2).is_alive,"rematch resets dead player")
	_check(first.registry.get_player(1).current_health == first.registry.get_player(1).max_health,"rematch restores resources")
	_check(first.registry.get_player(1).grid_position == ArenaData.get_spawn_points("forest")[0],"rematch resets spawn")
	_check(first.round_id != second.round_id,"round IDs isolated")
	_check(_command(1,"leave").ok,"host leaves during countdown")
	_check(first.members == [2] and first.state().owner_id == 2,"host transfers to remaining member")
	_check(first.phase == "result" and first.winner_id == 0,"disconnect cancels with no win")
	_check(directory.room_for(1) == null,"leaver membership removed")
	_check(directory.room_for(3) == second and second.phase == "fighting","other room unaffected by exit")
	_check(_command(1,"join",{"room_id":first.id}).ok,"return to interrupted room")
	_check(first.phase == "waiting" and first.ready.is_empty(),"join invalidates all readiness")
	_check(first.state().owner_id == 2,"returning player does not steal host")
	first.ready[2] = true
	var result := first.arena.change(2,"lava",first.arena.revision,1,clock+1000)
	_check(result.ok,"host changes own room map")
	first.invalidate_ready()
	_check(first.ready.is_empty() and first.phase == "waiting","map selection clears ready")
	_check(second.registry.get_arena_id() == "desert","map change isolated")
	_check(not first.arena.change(1,"duel_room",first.arena.revision,2,clock+2000).ok,"guest map change rejected")
	_check(bool(first.tick(clock+3000).changed),"map transition expiry is published to clients")
	_check(first.registry.is_round_locked(1) and first.registry.is_round_locked(2),"transition expiry does not unlock waiting lobby")
	first.ready[2] = true
	first.registry.try_select_class(1,8,clock)
	first.invalidate_ready()
	_check(first.ready.is_empty() and first.registry.get_player(1).class_id == 8,"class selection clears ready")
	_check(not second.registry.has_player(1),"class selection remains local to room")
	var nonce := int(requests[1])
	_check(not directory.command(1,"leave",{},nonce,clock+10000).ok,"replayed command rejected")
	_check(directory.room_for(1) == first,"replayed leave does not mutate membership")
	_check(not _command(5,"join",{"room_id":99999}).ok,"nonexistent room rejected")
	_check(not _command(5,"unknown").ok,"unknown command rejected")
	_check(not _command(1,"create",{"arena_id":"forest"}).ok,"member cannot create another room")
	directory.disconnect_peer(2)
	_check(first.state().owner_id == 1,"unexpected disconnect transfers host")
	directory.disconnect_peer(1)
	_check(not directory.rooms.has(first.id),"empty room deleted")
	_check(directory.rooms.size() == 1 and directory.room_for(3) == second,"cleanup leaves other room")
	var round_id := second.bot.round_id
	second.registry.apply_damage(ArenaPracticeBot.BOT_ID,10000)
	_check(second.settle_round() and second.phase == "result","bot death produces room result")
	_check(second.bot.phase == "won" and second.winner_id == 3,"bot win uses existing authoritative reward status")
	_check(_command(5,"join",{"room_id":second.id}).ok,"human can join after solo bot round")
	_check(not second.bot_enabled and not second.registry.has_player(ArenaPracticeBot.BOT_ID),"new human removes bot option and entity")
	_check(second.ready.is_empty() and second.phase == "waiting","new rival clears old round readiness")
	directory.disconnect_peer(5)
	directory.disconnect_peer(3)
	_check(directory.rooms.is_empty() and directory.membership.is_empty(),"empty bot room cleaned up")
	_check(not round_id.is_empty(),"bot had unique round ID")
	directory.dispose()
	print("Lobby isolation checks: %d; failures: %d" % [checks,failed])
	quit(1 if failed > 0 else 0)
