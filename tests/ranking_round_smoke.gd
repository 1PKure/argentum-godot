extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _run() -> void:
	var path := "user://ranking_round_test_%s.json" % Crypto.new().generate_random_bytes(6).hex_encode()
	var server = load("res://tests/ranking_server_probe.gd").new()
	root.add_child(server)
	server.ranking = ArenaRankingStore.new(path)
	var first := "a".repeat(32)
	var second := "b".repeat(32)
	_check(server.ranking.register(first,"a".repeat(64),"Alpha").ok,"first profile registered")
	_check(server.ranking.register(second,"b".repeat(64),"Beta").ok,"second profile registered")
	server._ranked_peers = {101:{"id":first,"nickname":"Alpha"},102:{"id":second,"nickname":"Beta"}}
	var room := ArenaLobbyRoom.new(1,"Test","forest")
	room.add_member(101)
	room.add_member(102)
	server._apply_ranking_names(room)
	_check(room.registry.get_player(101).display_name == "Alpha","registered nickname applied to actor")
	room.round_id = "pvp-round"
	room.phase = "countdown"
	server._track_ranking_round(room)
	room.phase = "result"
	room.winner_id = 101
	server._track_ranking_round(room)
	_check(server.ranking.get_player(first).points == 100,"authoritative PvP result earns 100")
	server._track_ranking_round(room)
	_check(server.ranking.get_player(first).points == 100,"repeated result never duplicates score")
	room.round_id = "disconnect-round"
	room.phase = "fighting"
	server._track_ranking_round(room)
	room.phase = "result"
	room.winner_id = 0
	server._track_ranking_round(room)
	_check(server.ranking.get_player(first).points == 100,"interrupted round does not score")
	server._ranked_peers[102].id = first
	room.round_id = "same-profile-round"
	room.phase = "fighting"
	server._track_ranking_round(room)
	room.phase = "result"
	room.winner_id = 101
	server._track_ranking_round(room)
	_check(server.ranking.get_player(first).points == 100,"two tabs using same profile cannot score against themselves")
	room.remove_member(102)
	room.bot_enabled = true
	room.round_id = "bot-round"
	room.phase = "fighting"
	server._track_ranking_round(room)
	room.phase = "result"
	room.winner_id = 101
	server._track_ranking_round(room)
	var player: Dictionary = server.ranking.get_player(first)
	_check(player.points == 200 and player.pvp_wins == 1 and player.bot_wins == 1,"bot and PvP wins score equally with separate counters")
	room.round_id = "bot-wins-round"
	room.phase = "fighting"
	server._track_ranking_round(room)
	room.phase = "result"
	room.winner_id = -1
	server._track_ranking_round(room)
	_check(server.ranking.get_player(first).points == 200,"bot defeating player earns no player points")
	var reloaded := ArenaRankingStore.new(path)
	_check(reloaded.get_player(first).points == 200,"points survive server store restart")
	_check(reloaded.snapshot().entries[0].nickname == "milusita" and reloaded.snapshot().entries[0].points == 9999999999,"honorary first place remains above earned points")
	_check(not reloaded.export_public_json().contains("secret"),"web snapshot contains no credentials")
	room.dispose()
	server.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path+".bak"))
	print("Ranking authority checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
