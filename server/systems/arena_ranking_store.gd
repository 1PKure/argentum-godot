class_name ArenaRankingStore
extends RefCounted

const DEFAULT_STORAGE_PATH := "user://arena_ranking_v1.json"
const SCHEMA := 1
const POINTS_PER_WIN := 100
const PUBLIC_LIMIT := 50
const REFRESH_AFTER_SECONDS := 30
const HONOR_POINTS := 9_999_999_999
const HONOR_ID := "honor:milusita"
const MAX_WINS := 1_000_000_000
# Full Unicode folds that differ from one-character lowercase.
const CASEFOLD_SPECIAL: Dictionary = {
	"\u00b5": "\u03bc", "\u00df": "ss", "\u0130": "i\u0307", "\u0149": "\u02bcn", "\u017f": "s", "\u01f0": "j\u030c",
	"\u0345": "\u03b9", "\u0390": "\u03b9\u0308\u0301", "\u03b0": "\u03c5\u0308\u0301", "\u03c2": "\u03c3", "\u03d0": "\u03b2", "\u03d1": "\u03b8",
	"\u03d5": "\u03c6", "\u03d6": "\u03c0", "\u03f0": "\u03ba", "\u03f1": "\u03c1", "\u03f5": "\u03b5", "\u0587": "\u0565\u0582",
	"\u13a0": "\u13a0", "\u13a1": "\u13a1", "\u13a2": "\u13a2", "\u13a3": "\u13a3", "\u13a4": "\u13a4", "\u13a5": "\u13a5",
	"\u13a6": "\u13a6", "\u13a7": "\u13a7", "\u13a8": "\u13a8", "\u13a9": "\u13a9", "\u13aa": "\u13aa", "\u13ab": "\u13ab",
	"\u13ac": "\u13ac", "\u13ad": "\u13ad", "\u13ae": "\u13ae", "\u13af": "\u13af", "\u13b0": "\u13b0", "\u13b1": "\u13b1",
	"\u13b2": "\u13b2", "\u13b3": "\u13b3", "\u13b4": "\u13b4", "\u13b5": "\u13b5", "\u13b6": "\u13b6", "\u13b7": "\u13b7",
	"\u13b8": "\u13b8", "\u13b9": "\u13b9", "\u13ba": "\u13ba", "\u13bb": "\u13bb", "\u13bc": "\u13bc", "\u13bd": "\u13bd",
	"\u13be": "\u13be", "\u13bf": "\u13bf", "\u13c0": "\u13c0", "\u13c1": "\u13c1", "\u13c2": "\u13c2", "\u13c3": "\u13c3",
	"\u13c4": "\u13c4", "\u13c5": "\u13c5", "\u13c6": "\u13c6", "\u13c7": "\u13c7", "\u13c8": "\u13c8", "\u13c9": "\u13c9",
	"\u13ca": "\u13ca", "\u13cb": "\u13cb", "\u13cc": "\u13cc", "\u13cd": "\u13cd", "\u13ce": "\u13ce", "\u13cf": "\u13cf",
	"\u13d0": "\u13d0", "\u13d1": "\u13d1", "\u13d2": "\u13d2", "\u13d3": "\u13d3", "\u13d4": "\u13d4", "\u13d5": "\u13d5",
	"\u13d6": "\u13d6", "\u13d7": "\u13d7", "\u13d8": "\u13d8", "\u13d9": "\u13d9", "\u13da": "\u13da", "\u13db": "\u13db",
	"\u13dc": "\u13dc", "\u13dd": "\u13dd", "\u13de": "\u13de", "\u13df": "\u13df", "\u13e0": "\u13e0", "\u13e1": "\u13e1",
	"\u13e2": "\u13e2", "\u13e3": "\u13e3", "\u13e4": "\u13e4", "\u13e5": "\u13e5", "\u13e6": "\u13e6", "\u13e7": "\u13e7",
	"\u13e8": "\u13e8", "\u13e9": "\u13e9", "\u13ea": "\u13ea", "\u13eb": "\u13eb", "\u13ec": "\u13ec", "\u13ed": "\u13ed",
	"\u13ee": "\u13ee", "\u13ef": "\u13ef", "\u13f0": "\u13f0", "\u13f1": "\u13f1", "\u13f2": "\u13f2", "\u13f3": "\u13f3",
	"\u13f4": "\u13f4", "\u13f5": "\u13f5", "\u13f8": "\u13f0", "\u13f9": "\u13f1", "\u13fa": "\u13f2", "\u13fb": "\u13f3",
	"\u13fc": "\u13f4", "\u13fd": "\u13f5", "\u1c80": "\u0432", "\u1c81": "\u0434", "\u1c82": "\u043e", "\u1c83": "\u0441",
	"\u1c84": "\u0442", "\u1c85": "\u0442", "\u1c86": "\u044a", "\u1c87": "\u0463", "\u1c88": "\ua64b", "\u1e96": "h\u0331",
	"\u1e97": "t\u0308", "\u1e98": "w\u030a", "\u1e99": "y\u030a", "\u1e9a": "a\u02be", "\u1e9b": "\u1e61", "\u1e9e": "ss",
	"\u1f50": "\u03c5\u0313", "\u1f52": "\u03c5\u0313\u0300", "\u1f54": "\u03c5\u0313\u0301", "\u1f56": "\u03c5\u0313\u0342", "\u1f80": "\u1f00\u03b9", "\u1f81": "\u1f01\u03b9",
	"\u1f82": "\u1f02\u03b9", "\u1f83": "\u1f03\u03b9", "\u1f84": "\u1f04\u03b9", "\u1f85": "\u1f05\u03b9", "\u1f86": "\u1f06\u03b9", "\u1f87": "\u1f07\u03b9",
	"\u1f88": "\u1f00\u03b9", "\u1f89": "\u1f01\u03b9", "\u1f8a": "\u1f02\u03b9", "\u1f8b": "\u1f03\u03b9", "\u1f8c": "\u1f04\u03b9", "\u1f8d": "\u1f05\u03b9",
	"\u1f8e": "\u1f06\u03b9", "\u1f8f": "\u1f07\u03b9", "\u1f90": "\u1f20\u03b9", "\u1f91": "\u1f21\u03b9", "\u1f92": "\u1f22\u03b9", "\u1f93": "\u1f23\u03b9",
	"\u1f94": "\u1f24\u03b9", "\u1f95": "\u1f25\u03b9", "\u1f96": "\u1f26\u03b9", "\u1f97": "\u1f27\u03b9", "\u1f98": "\u1f20\u03b9", "\u1f99": "\u1f21\u03b9",
	"\u1f9a": "\u1f22\u03b9", "\u1f9b": "\u1f23\u03b9", "\u1f9c": "\u1f24\u03b9", "\u1f9d": "\u1f25\u03b9", "\u1f9e": "\u1f26\u03b9", "\u1f9f": "\u1f27\u03b9",
	"\u1fa0": "\u1f60\u03b9", "\u1fa1": "\u1f61\u03b9", "\u1fa2": "\u1f62\u03b9", "\u1fa3": "\u1f63\u03b9", "\u1fa4": "\u1f64\u03b9", "\u1fa5": "\u1f65\u03b9",
	"\u1fa6": "\u1f66\u03b9", "\u1fa7": "\u1f67\u03b9", "\u1fa8": "\u1f60\u03b9", "\u1fa9": "\u1f61\u03b9", "\u1faa": "\u1f62\u03b9", "\u1fab": "\u1f63\u03b9",
	"\u1fac": "\u1f64\u03b9", "\u1fad": "\u1f65\u03b9", "\u1fae": "\u1f66\u03b9", "\u1faf": "\u1f67\u03b9", "\u1fb2": "\u1f70\u03b9", "\u1fb3": "\u03b1\u03b9",
	"\u1fb4": "\u03ac\u03b9", "\u1fb6": "\u03b1\u0342", "\u1fb7": "\u03b1\u0342\u03b9", "\u1fbc": "\u03b1\u03b9", "\u1fbe": "\u03b9", "\u1fc2": "\u1f74\u03b9",
	"\u1fc3": "\u03b7\u03b9", "\u1fc4": "\u03ae\u03b9", "\u1fc6": "\u03b7\u0342", "\u1fc7": "\u03b7\u0342\u03b9", "\u1fcc": "\u03b7\u03b9", "\u1fd2": "\u03b9\u0308\u0300",
	"\u1fd3": "\u03b9\u0308\u0301", "\u1fd6": "\u03b9\u0342", "\u1fd7": "\u03b9\u0308\u0342", "\u1fe2": "\u03c5\u0308\u0300", "\u1fe3": "\u03c5\u0308\u0301", "\u1fe4": "\u03c1\u0313",
	"\u1fe6": "\u03c5\u0342", "\u1fe7": "\u03c5\u0308\u0342", "\u1ff2": "\u1f7c\u03b9", "\u1ff3": "\u03c9\u03b9", "\u1ff4": "\u03ce\u03b9", "\u1ff6": "\u03c9\u0342",
	"\u1ff7": "\u03c9\u0342\u03b9", "\u1ffc": "\u03c9\u03b9", "\uab70": "\u13a0", "\uab71": "\u13a1", "\uab72": "\u13a2", "\uab73": "\u13a3",
	"\uab74": "\u13a4", "\uab75": "\u13a5", "\uab76": "\u13a6", "\uab77": "\u13a7", "\uab78": "\u13a8", "\uab79": "\u13a9",
	"\uab7a": "\u13aa", "\uab7b": "\u13ab", "\uab7c": "\u13ac", "\uab7d": "\u13ad", "\uab7e": "\u13ae", "\uab7f": "\u13af",
	"\uab80": "\u13b0", "\uab81": "\u13b1", "\uab82": "\u13b2", "\uab83": "\u13b3", "\uab84": "\u13b4", "\uab85": "\u13b5",
	"\uab86": "\u13b6", "\uab87": "\u13b7", "\uab88": "\u13b8", "\uab89": "\u13b9", "\uab8a": "\u13ba", "\uab8b": "\u13bb",
	"\uab8c": "\u13bc", "\uab8d": "\u13bd", "\uab8e": "\u13be", "\uab8f": "\u13bf", "\uab90": "\u13c0", "\uab91": "\u13c1",
	"\uab92": "\u13c2", "\uab93": "\u13c3", "\uab94": "\u13c4", "\uab95": "\u13c5", "\uab96": "\u13c6", "\uab97": "\u13c7",
	"\uab98": "\u13c8", "\uab99": "\u13c9", "\uab9a": "\u13ca", "\uab9b": "\u13cb", "\uab9c": "\u13cc", "\uab9d": "\u13cd",
	"\uab9e": "\u13ce", "\uab9f": "\u13cf", "\uaba0": "\u13d0", "\uaba1": "\u13d1", "\uaba2": "\u13d2", "\uaba3": "\u13d3",
	"\uaba4": "\u13d4", "\uaba5": "\u13d5", "\uaba6": "\u13d6", "\uaba7": "\u13d7", "\uaba8": "\u13d8", "\uaba9": "\u13d9",
	"\uabaa": "\u13da", "\uabab": "\u13db", "\uabac": "\u13dc", "\uabad": "\u13dd", "\uabae": "\u13de", "\uabaf": "\u13df",
	"\uabb0": "\u13e0", "\uabb1": "\u13e1", "\uabb2": "\u13e2", "\uabb3": "\u13e3", "\uabb4": "\u13e4", "\uabb5": "\u13e5",
	"\uabb6": "\u13e6", "\uabb7": "\u13e7", "\uabb8": "\u13e8", "\uabb9": "\u13e9", "\uabba": "\u13ea", "\uabbb": "\u13eb",
	"\uabbc": "\u13ec", "\uabbd": "\u13ed", "\uabbe": "\u13ee", "\uabbf": "\u13ef", "\ufb00": "ff", "\ufb01": "fi",
	"\ufb02": "fl", "\ufb03": "ffi", "\ufb04": "ffl", "\ufb05": "st", "\ufb06": "st", "\ufb13": "\u0574\u0576",
	"\ufb14": "\u0574\u0565", "\ufb15": "\u0574\u056b", "\ufb16": "\u057e\u0576", "\ufb17": "\u0574\u056d"
}

var storage_path: String
var revision := 0
var updated_at := 0
var last_error := ""
var last_backup_error := ""
var available := false

var _players: Dictionary = {}
var _awards: Dictionary = {}
var _id_pattern := RegEx.create_from_string("^[0-9a-fA-F]{32}$")
var _secret_pattern := RegEx.create_from_string("^[0-9a-fA-F]{64}$")
var _nickname_pattern := RegEx.create_from_string("^[\\p{L}\\p{N}_ -]{2,20}$")
var _round_pattern := RegEx.create_from_string("^[A-Za-z0-9:_.-]{1,160}$")


func _init(path: String = DEFAULT_STORAGE_PATH) -> void:
	storage_path = path
	load_store()


func load_store() -> Dictionary:
	last_error = ""
	last_backup_error = ""
	var primary_exists := FileAccess.file_exists(storage_path)
	var backup_exists := FileAccess.file_exists(storage_path + ".bak")
	if not primary_exists and not backup_exists:
		_players = {}
		_awards = {}
		revision = 0
		updated_at = int(Time.get_unix_time_from_system())
		available = true
		return {"ok": true, "message": "Ranking nuevo listo.", "recovered": false}
	var loaded := _read_payload(storage_path) if primary_exists else {}
	var recovered := false
	if loaded.is_empty() and backup_exists:
		loaded = _read_payload(storage_path + ".bak")
		recovered = not loaded.is_empty()
	if loaded.is_empty():
		available = false
		return _error("No se pudo recuperar el ranking. Se conservaron los archivos existentes.")
	_apply_payload(loaded)
	available = true
	if recovered:
		var result := _restore_primary(loaded)
		if result != OK:
			available = false
			return _error("Ranking recuperado del respaldo; no se pudo reparar el archivo principal.")
	return {"ok": true, "message": "Ranking recuperado." if recovered else "Ranking cargado.", "recovered": recovered}


func register(identity_id: String, secret: String, nickname: String) -> Dictionary:
	if not available:
		return _error("El ranking no está disponible para guardar cambios.")
	if not _valid_identity(identity_id) or secret.length() != 64 or _secret_pattern.search(secret) == null:
		return _error("La identidad local no es válida.")
	var name := nickname.strip_edges()
	if not _valid_nickname(name):
		return _error("Usá entre 2 y 20 letras, números, espacios, guion o guion bajo.")
	var key := _nickname_key(name)
	if key == "milusita":
		return _error("Ese apodo está reservado.")
	var id := identity_id.to_lower()
	var secret_hash := secret.to_lower().sha256_text()
	if _players.has(id) and str(_players[id].secret_hash) != secret_hash:
		return _error("No se pudo verificar la identidad local.")
	for existing_id: String in _players:
		if existing_id != id and _nickname_key(str(_players[existing_id].nickname)) == key:
			return _error("Ese apodo ya está en uso.")
	if _players.has(id) and str(_players[id].nickname) == name:
		return {"ok": true, "message": "Identidad verificada.", "player": _public_player(id, _players[id])}
	var next_players := _players.duplicate(true)
	if not next_players.has(id):
		next_players[id] = {"nickname": name, "secret_hash": secret_hash, "pvp_wins": 0, "bot_wins": 0}
	else:
		next_players[id].nickname = name
	if not _commit(next_players, _awards):
		return _error("No se pudo guardar el ranking. No se aplicaron cambios.")
	return {"ok": true, "message": "Apodo guardado.", "player": _public_player(id, _players[id])}


func record_victory(round_id: String, identity_id: String, mode: String) -> Dictionary:
	if not available:
		return _error("El ranking no está disponible para guardar resultados.")
	var id := identity_id.to_lower()
	if not _valid_round(round_id) or not _players.has(id) or mode not in ["pvp", "bot"]:
		return _error("El resultado no tiene una ronda, identidad o modo válido.")
	if _awards.has(round_id):
		var prior: Dictionary = _awards[round_id]
		if str(prior.identity_id) != id or str(prior.mode) != mode:
			return _error("La ronda ya tiene un resultado registrado.")
		return {"ok": true, "message": "La victoria ya estaba registrada.", "awarded": false, "player": _public_player(id, _players[id])}
	var next_players := _players.duplicate(true)
	var win_key := "pvp_wins" if mode == "pvp" else "bot_wins"
	if int(next_players[id].pvp_wins) + int(next_players[id].bot_wins) >= MAX_WINS:
		return _error("Se alcanzó el límite de resultados de esta versión.")
	next_players[id][win_key] = int(next_players[id][win_key]) + 1
	var next_awards := _awards.duplicate(true)
	next_awards[round_id] = {"identity_id": id, "mode": mode}
	if not _commit(next_players, next_awards):
		return _error("No se pudo guardar la victoria. No se sumaron puntos.")
	return {"ok": true, "message": "Victoria registrada: +100 puntos.", "awarded": true, "player": _public_player(id, _players[id])}


func get_player(identity_id: String) -> Dictionary:
	var id := identity_id.to_lower()
	return _public_player(id, _players[id]) if _players.has(id) else {}


func snapshot() -> Dictionary:
	var ranked: Array[Dictionary] = []
	for id: String in _players:
		ranked.append(_public_player(id, _players[id]))
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.points) != int(b.points): return int(a.points) > int(b.points)
		var left := _nickname_key(str(a.nickname))
		var right := _nickname_key(str(b.nickname))
		return str(a.id) < str(b.id) if left == right else left < right)
	var entries: Array[Dictionary] = [{"id": HONOR_ID, "nickname": "milusita", "points": HONOR_POINTS,
		"wins": 0, "pvp_wins": 0, "bot_wins": 0, "honorary": true}]
	for index in range(mini(PUBLIC_LIMIT, ranked.size())):
		entries.append(ranked[index])
	for index in range(entries.size()):
		entries[index].rank = index + 1
	return {"schema": SCHEMA, "revision": revision, "updated_at": updated_at,
		"refresh_after_seconds": REFRESH_AFTER_SECONDS, "total_players": _players.size(), "entries": entries}


func export_public_json() -> String:
	return JSON.stringify(snapshot())


func _public_player(id: String, player: Dictionary) -> Dictionary:
	var pvp := int(player.pvp_wins)
	var bot := int(player.bot_wins)
	return {"id": id, "nickname": str(player.nickname), "wins": pvp + bot,
		"pvp_wins": pvp, "bot_wins": bot, "points": (pvp + bot) * POINTS_PER_WIN, "honorary": false}


func _commit(next_players: Dictionary, next_awards: Dictionary) -> bool:
	var payload := {"schema": SCHEMA, "revision": revision + 1,
		"updated_at": maxi(updated_at, int(Time.get_unix_time_from_system())),
		"players": next_players, "awards": next_awards}
	var result := _persist_payload(payload)
	if result != OK:
		last_error = "Ranking save error: %d" % result
		return false
	_apply_payload(payload)
	last_error = ""
	return true


func _persist_payload(payload: Dictionary) -> Error:
	var directory := ProjectSettings.globalize_path(storage_path).get_base_dir()
	var result := DirAccess.make_dir_recursive_absolute(directory)
	if result != OK:
		return result
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(storage_path)) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(storage_path + ".bak")):
		return ERR_FILE_CANT_WRITE
	var serialized := JSON.stringify(payload)
	var temporary := storage_path + ".tmp"
	var backup_temporary := storage_path + ".bak.tmp"
	result = _write_verified(temporary, serialized)
	if result == OK:
		result = _write_verified(backup_temporary, serialized)
	if result == OK:
		result = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(storage_path))
	if result != OK:
		_remove_file(temporary)
		_remove_file(backup_temporary)
		return result
	# Replacing the principal file is the commit point. Never return a rejected
	# victory after this durable replacement; a backup-refresh error is separate.
	last_backup_error = ""
	var backup_result := DirAccess.rename_absolute(ProjectSettings.globalize_path(backup_temporary), ProjectSettings.globalize_path(storage_path + ".bak"))
	if backup_result != OK:
		last_backup_error = "Ranking backup refresh error: %d" % backup_result
		_remove_file(backup_temporary)
	return OK


func _restore_primary(payload: Dictionary) -> Error:
	var temporary := storage_path + ".tmp"
	var result := _write_verified(temporary, JSON.stringify(payload))
	if result == OK:
		result = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(storage_path))
	if result != OK:
		_remove_file(temporary)
	return result


func _write_verified(path: String, contents: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(contents)
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK:
		return result
	var check := FileAccess.open(path, FileAccess.READ)
	if check == null:
		return FileAccess.get_open_error()
	var actual := check.get_as_text()
	check.close()
	return OK if actual == contents else ERR_FILE_CORRUPT


func _read_payload(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var decoder := JSON.new()
	var parse_error := decoder.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return {}
	var parsed: Variant = decoder.data
	if not parsed is Dictionary:
		return {}
	var payload: Dictionary = parsed
	if not _valid_counter(payload.get("schema", null), SCHEMA) or int(payload.schema) != SCHEMA or not _valid_counter(payload.get("revision", null)) or not _valid_counter(payload.get("updated_at", null), 9_000_000_000_000_000):
		return {}
	if not payload.get("players", null) is Dictionary or not payload.get("awards", null) is Dictionary:
		return {}
	var names: Dictionary = {}
	for id: Variant in payload.players:
		if not id is String or not _valid_identity(id) or str(id) != str(id).to_lower() or not payload.players[id] is Dictionary:
			return {}
		var player: Dictionary = payload.players[id]
		if not player.get("nickname", null) is String or not _valid_nickname(player.nickname) or player.nickname != player.nickname.strip_edges():
			return {}
		var name := _nickname_key(str(player.nickname))
		if name == "milusita" or names.has(name):
			return {}
		names[name] = true
		if not player.get("secret_hash", null) is String or _secret_pattern.search(str(player.secret_hash)) == null:
			return {}
		if not _valid_counter(player.get("pvp_wins", null)) or not _valid_counter(player.get("bot_wins", null)) or int(player.pvp_wins) + int(player.bot_wins) > MAX_WINS:
			return {}
	var totals: Dictionary = {}
	for id: String in payload.players:
		totals[id] = {"pvp": 0, "bot": 0}
	for round_id: Variant in payload.awards:
		if not round_id is String or not _valid_round(round_id) or not payload.awards[round_id] is Dictionary:
			return {}
		var award: Dictionary = payload.awards[round_id]
		if not payload.players.has(str(award.get("identity_id", ""))) or str(award.get("mode", "")) not in ["pvp", "bot"]:
			return {}
		totals[str(award.identity_id)][str(award.mode)] += 1
	for id: String in payload.players:
		if int(payload.players[id].pvp_wins) != int(totals[id].pvp) or int(payload.players[id].bot_wins) != int(totals[id].bot):
			return {}
	return payload


func _apply_payload(payload: Dictionary) -> void:
	_players = Dictionary(payload.players).duplicate(true)
	_awards = Dictionary(payload.awards).duplicate(true)
	revision = int(payload.revision)
	updated_at = int(payload.updated_at)


func _valid_identity(value: String) -> bool:
	return value.length() == 32 and _id_pattern.search(value) != null


func _valid_round(value: String) -> bool:
	var match_value := _round_pattern.search(value)
	return match_value != null and match_value.get_string() == value


func _valid_nickname(value: String) -> bool:
	return value.length() >= 2 and value.length() <= 20 and _nickname_pattern.search(value) != null


func _valid_counter(value: Variant, maximum: int = MAX_WINS) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) <= maximum and float(value) == floorf(float(value))


func _nickname_key(value: String) -> String:
	var result := ""
	for character: String in value:
		result += str(CASEFOLD_SPECIAL.get(character, character.to_lower()))
	return result


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _error(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "message": message}
