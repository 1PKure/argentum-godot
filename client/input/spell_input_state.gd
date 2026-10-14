class_name SpellInputState
extends RefCounted

var selected_spell_id := SpellCatalog.DAMAGE
var combat_mode := false
var manual_armed := false
var pending_request := 0
var cooldown_until_msec := 0
var _serial := 0


func is_targeting() -> bool:
	return combat_mode or manual_armed


func begin_request(now_msec: int) -> int:
	if not is_targeting() or pending_request != 0 or now_msec < cooldown_until_msec:
		return 0
	_serial += 1
	pending_request = _serial
	return pending_request


func finish_request(request_id: int, success: bool, retry_after_msec: int, now_msec: int) -> bool:
	if request_id != pending_request or pending_request == 0:
		return false
	pending_request = 0
	cooldown_until_msec = now_msec + maxi(0, retry_after_msec)
	if success:
		manual_armed = false
	return true


func cancel_targeting() -> void:
	combat_mode = false
	manual_armed = false


func reset_session() -> void:
	cancel_targeting()
	pending_request = 0
	cooldown_until_msec = 0

