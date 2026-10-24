class_name ArenaChatService
extends RefCounted
const MAX_LENGTH := 160
const HISTORY_LIMIT := 30
const INTERVAL_MSEC := 800
var histories: Dictionary = {}
var _last_time: Dictionary = {}
var _last_request: Dictionary = {}
var _sequence := 0

static func clean(value: String) -> String:
	if value.length() > MAX_LENGTH or value.to_utf8_buffer().size() > MAX_LENGTH*4: return ""
	var result := ""
	for index in value.length():
		var code := value.unicode_at(index)
		if code < 32 or code == 127:
			if code in [9,10,13]: result += " "
			continue
		# Direction overrides and invisible line separators are not chat layout.
		if code in [0x2028,0x2029,0x202a,0x202b,0x202c,0x202d,0x202e,0x2066,0x2067,0x2068,0x2069]: continue
		result += value[index]
	return result.strip_edges()

func submit(room_id: int, members: Array, sender: int, nickname: String, text: String, request: int, now: int) -> Dictionary:
	if room_id <= 0 or sender <= 0 or not members.has(sender): return _error("Entrá a una sala para conversar.")
	if request <= int(_last_request.get(sender,0)): return _error("Mensaje repetido.")
	_last_request[sender] = request
	if now-int(_last_time.get(sender,-INTERVAL_MSEC)) < INTERVAL_MSEC: return _error("Esperá un momento antes de enviar otro mensaje.")
	_last_time[sender] = now
	var value := clean(text)
	if value.is_empty(): return _error("Escribí un mensaje de 1 a 160 caracteres.")
	_sequence += 1
	var message := {"id":_sequence,"room_id":room_id,"sender_id":sender,"nickname":nickname,"text":value}
	if not histories.has(room_id): histories[room_id] = []
	histories[room_id].append(message)
	if histories[room_id].size()>HISTORY_LIMIT: histories[room_id].pop_front()
	return {"ok":true,"message":message.duplicate(true)}

func history(room_id: int) -> Array:
	return Array(histories.get(room_id,[])).duplicate(true)
func forget_peer(peer: int) -> void:
	_last_time.erase(peer)
	_last_request.erase(peer)
func prune(room_ids: Array) -> void:
	for room_id in histories.keys():
		if not room_ids.has(room_id): histories.erase(room_id)
func _error(value: String) -> Dictionary:
	return {"ok":false,"error":value}
