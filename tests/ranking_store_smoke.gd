extends SceneTree

const ID_ONE := "11111111111111111111111111111111"
const ID_TWO := "abcdef0123456789abcdef0123456789"
const ID_THREE := "33333333333333333333333333333333"
const ID_FOUR := "44444444444444444444444444444444"
const SECRET_ONE := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const SECRET_TWO := "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

var checks := 0
var failures := 0
var paths: Array[String] = []
var prefix := "user://ranking-qa-%d" % Time.get_ticks_usec()
var store_script: GDScript


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	store_script = load("res://server/systems/arena_ranking_store.gd")
	_test_identity_and_aliases()
	_test_scores_and_restore()
	_test_corruption()
	_test_failed_save()
	_test_public_limit()
	for path in paths:
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
			var full := ProjectSettings.globalize_path(path + suffix)
			if FileAccess.file_exists(full):
				DirAccess.remove_absolute(full)
			elif DirAccess.dir_exists_absolute(full):
				DirAccess.remove_absolute(full)
	print("Ranking store checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)


func _path(label: String) -> String:
	var path := prefix + "-" + label + ".json"
	paths.append(path)
	return path


func _test_identity_and_aliases() -> void:
	var path := _path("aliases")
	var store = store_script.new(path)
	var view: Dictionary = store.snapshot()
	_check(store.available and view.schema == 1 and view.revision == 0 and view.refresh_after_seconds == 30, "Fresh ranking exposes its schema, revision and refresh cadence")
	_check(view.entries.size() == 1 and view.entries[0].nickname == "milusita" and int(view.entries[0].points) == 9999999999 and view.entries[0].honorary and view.entries[0].wins == 0, "The first row is an explicit honorary tribute with no fabricated victories")
	_check(not store.register("short", SECRET_ONE, "Mati").ok, "Short identity tokens are rejected")
	_check(not store.register(ID_ONE + "\n", SECRET_ONE, "Mati").ok, "A trailing newline cannot bypass exact identity length")
	_check(not store.register(ID_ONE, "bad", "Mati").ok, "Invalid secret length is rejected")
	_check(not store.register(ID_ONE, SECRET_ONE + "\n", "Mati").ok, "A trailing newline cannot bypass exact secret length")
	for nickname: String in ["A", "ABCDEFGHIJKLMNOPQRSTU", "<script>", "Bad@Name", "😀😀"]:
		_check(not store.register(ID_ONE, SECRET_ONE, nickname).ok, "Invalid nickname is rejected: " + nickname)
	for nickname: String in ["milusita", "MILUSITA", "MiLuSiTa"]:
		_check(not store.register(ID_ONE, SECRET_ONE, nickname).ok, "The honorary nickname is reserved in every capitalization")
	var result: Dictionary = store.register(ID_ONE, SECRET_ONE, "  Mati  ")
	_check(result.ok and result.player.nickname == "Mati" and result.player.points == 0 and not result.player.has("secret_hash"), "Registration trims edges and returns only public player fields")
	var revision: int = store.revision
	_check(store.register(ID_ONE, SECRET_ONE.to_upper(), "Mati").ok and store.revision == revision, "A verified unchanged registration does not rewrite or advance revision")
	_check(not store.register(ID_ONE, SECRET_TWO, "Renamed").ok and store.get_player(ID_ONE).nickname == "Mati" and store.revision == revision, "Another secret cannot rename a known identity")
	_check(not store.register(ID_TWO, SECRET_TWO, "mAtI").ok, "Nickname uniqueness is case-insensitive")
	_check(store.register(ID_TWO.to_upper(), SECRET_TWO, "Éowyn_9").ok and store.get_player(ID_TWO).nickname == "Éowyn_9", "Unicode letters and uppercase hexadecimal identity representation work")
	_check(not store.register(ID_THREE, SECRET_ONE, "éOWYN_9").ok, "Unicode uppercase aliases cannot duplicate an existing name")
	_check(store.register(ID_THREE, SECRET_ONE, "Straße").ok and not store.register(ID_FOUR, SECRET_TWO, "STRASSE").ok, "Full Unicode casefold treats sharp-s and SS as one nickname")
	_check(store.register(ID_ONE, SECRET_ONE, "MATI").ok and store.get_player(ID_ONE).nickname == "MATI", "An authenticated player can change display capitalization")
	_check(not store.register(ID_ONE, SECRET_ONE, "Éowyn_9").ok and store.get_player(ID_ONE).nickname == "MATI", "An authenticated rename cannot steal another player's alias")
	var raw := FileAccess.get_file_as_string(path)
	_check(raw.contains(SECRET_ONE.sha256_text()) and not raw.contains(SECRET_ONE), "The private server file stores a SHA256 digest rather than the raw secret")
	var public_json: String = store.export_public_json()
	_check(not public_json.contains("secret_hash") and not public_json.contains(SECRET_ONE) and not public_json.contains("awards"), "Public JSON contains neither identity proofs nor the private round ledger")
	var rebuilt = store_script.new(path)
	_check(rebuilt.available and rebuilt.register(ID_ONE, SECRET_ONE, "MATI").ok and not rebuilt.register(ID_ONE, SECRET_TWO, "MATI").ok, "Identity authentication survives a server-store restart")


func _test_scores_and_restore() -> void:
	var path := _path("scores")
	var store = store_script.new(path)
	store.register(ID_ONE, SECRET_ONE, "Primero")
	store.register(ID_TWO, SECRET_TWO, "Segundo")
	var first: Dictionary = store.record_victory("run1:room1:round1", ID_ONE, "pvp")
	_check(first.ok and first.awarded and first.player.points == 100 and first.player.pvp_wins == 1 and first.player.bot_wins == 0, "A confirmed PvP victory grants exactly100 points")
	var second: Dictionary = store.record_victory("run1:room1:round2", ID_ONE, "bot")
	_check(second.ok and second.player.points == 200 and second.player.wins == 2 and second.player.pvp_wins == 1 and second.player.bot_wins == 1, "A bot victory grants the same100 points while retaining separate counters")
	store.record_victory("run1:room2:round1", ID_TWO, "bot")
	var view: Dictionary = store.snapshot()
	_check(view.entries[0].honorary and view.entries[1].id == ID_ONE and view.entries[2].id == ID_TWO and view.entries[1].rank == 2, "The tribute stays first while actual players are sorted by real points")
	var revision: int = store.revision
	var duplicate: Dictionary = store.record_victory("run1:room1:round1", ID_ONE, "pvp")
	_check(duplicate.ok and not duplicate.awarded and store.revision == revision and store.get_player(ID_ONE).points == 200, "Repeated delivery is an accepted no-op rather than a second award")
	_check(not store.record_victory("run1:room1:round1", ID_TWO, "pvp").ok and store.get_player(ID_TWO).points == 100, "One round cannot grant points to a different winner")
	_check(not store.record_victory("run1:room1:round1", ID_ONE, "bot").ok, "Changing mode cannot replay an already credited round")
	_check(not store.record_victory("new-round", ID_ONE, "forfeit").ok and not store.record_victory("new-round", ID_THREE, "pvp").ok, "Unknown modes and unregistered winners cannot receive points")
	_check(not store.record_victory("bad\n", ID_ONE, "pvp").ok and not store.record_victory("", ID_ONE, "pvp").ok, "Malformed or absent round identifiers are rejected")
	var rebuilt = store_script.new(path)
	_check(rebuilt.available and rebuilt.revision == revision and rebuilt.get_player(ID_ONE).points == 200 and rebuilt.get_player(ID_TWO).points == 100, "Both players' real counters and revision survive a restart")
	duplicate = rebuilt.record_victory("run1:room1:round1", ID_ONE, "pvp")
	_check(duplicate.ok and not duplicate.awarded and rebuilt.get_player(ID_ONE).points == 200, "The round ledger prevents double awards across restarts")
	_check(rebuilt.register(ID_ONE, SECRET_ONE, "Nuevo nombre").ok and rebuilt.get_player(ID_ONE).points == 200, "Renaming an identity preserves its accumulated results")
	_check(store_script.new(path).get_player(ID_ONE).nickname == "Nuevo nombre", "An authenticated nickname change is durable")
	var parsed: Variant = JSON.parse_string(rebuilt.export_public_json())
	_check(parsed is Dictionary and parsed.schema == 1 and parsed.entries.size() == 3 and not str(parsed).contains("secret_hash"), "Public export is standalone valid JSON for a future website")


func _test_corruption() -> void:
	var path := _path("corrupt")
	var store = store_script.new(path)
	store.register(ID_ONE, SECRET_ONE, "Superviviente")
	store.record_victory("durable:round1", ID_ONE, "pvp")
	var revision: int = store.revision
	_write(path, "{not valid JSON")
	var rebuilt = store_script.new(path)
	_check(rebuilt.available and rebuilt.revision == revision and rebuilt.get_player(ID_ONE).points == 100, "A corrupt principal file recovers the latest confirmed version from backup")
	_check(not rebuilt.record_victory("durable:round1", ID_ONE, "pvp").awarded, "Backup recovery preserves the idempotency ledger")
	_check(JSON.parse_string(FileAccess.get_file_as_string(path)) is Dictionary, "Backup recovery repairs the principal file")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	rebuilt = store_script.new(path)
	_check(rebuilt.available and rebuilt.get_player(ID_ONE).points == 100, "A missing principal file can also recover a committed backup")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	payload.awards = {}
	_write(path, JSON.stringify(payload))
	rebuilt = store_script.new(path)
	_check(rebuilt.available and rebuilt.get_player(ID_ONE).points == 100 and not rebuilt.record_victory("durable:round1", ID_ONE, "pvp").awarded, "A structurally inconsistent ledger is rejected and recovered from backup")
	_write(path, "broken primary")
	_write(path + ".bak", "broken backup")
	rebuilt = store_script.new(path)
	_check(not rebuilt.available and not rebuilt.register(ID_TWO, SECRET_TWO, "No borrado").ok and not rebuilt.record_victory("new:round", ID_ONE, "bot").ok, "If both files are corrupt, the store refuses writes instead of resetting results")
	_check(FileAccess.get_file_as_string(path) == "broken primary" and FileAccess.get_file_as_string(path + ".bak") == "broken backup", "Failed recovery preserves both files for inspection")


func _test_failed_save() -> void:
	var path := _path("failed-save")
	var store = load("res://tests/ranking_fault_store.gd").new(path)
	store.register(ID_ONE, SECRET_ONE, "Sin regalo")
	var before := FileAccess.get_file_as_string(path)
	var revision: int = store.revision
	store.fail_writes = true
	var result: Dictionary = store.record_victory("retry:round1", ID_ONE, "pvp")
	_check(not result.ok and store.revision == revision and store.get_player(ID_ONE).points == 0, "A save failure rolls back the in-memory score and revision")
	_check(FileAccess.get_file_as_string(path) == before and store_script.new(path).get_player(ID_ONE).points == 0, "A failed award leaves the durable score unchanged")
	_check(not store.register(ID_ONE, SECRET_ONE, "Renombre perdido").ok and store.get_player(ID_ONE).nickname == "Sin regalo", "Failed nickname persistence also rolls back the rename")
	store.fail_writes = false
	result = store.record_victory("retry:round1", ID_ONE, "pvp")
	_check(result.ok and result.awarded and result.player.points == 100, "A failed round can be retried once storage is available")
	_check(not store.record_victory("retry:round1", ID_ONE, "pvp").awarded, "The successful retry cannot be awarded twice")
	var blocked_path := _path("directory-collision")
	var blocked = store_script.new(blocked_path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked_path))
	_check(not blocked.register(ID_ONE, SECRET_ONE, "Directorio").ok and blocked.snapshot().total_players == 0 and blocked.revision == 0, "A real destination-directory collision cannot mutate registration state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked_path))
	_check(blocked.register(ID_ONE, SECRET_ONE, "Directorio").ok, "Removing the real filesystem obstruction permits a clean retry")


func _test_public_limit() -> void:
	var store = store_script.new(_path("limit"))
	for index in range(55):
		var id := ("%032x" % (index + 100))
		store.register(id, SECRET_ONE, "Jugador%02d" % index)
	var view: Dictionary = store.snapshot()
	_check(view.total_players == 55 and view.entries.size() == 51 and view.entries[0].honorary, "Public ranking returns top50 real players plus the honorary first row")
	_check(view.entries[1].nickname == "Jugador00" and view.entries[50].nickname == "Jugador49", "Equal scores have deterministic casefolded nickname ordering")
	var public_copy: Dictionary = store.snapshot()
	public_copy.entries[1].nickname = "Mutado"
	_check(store.snapshot().entries[1].nickname == "Jugador00", "Changing a returned snapshot cannot mutate the server's player records")


func _write(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + message)
