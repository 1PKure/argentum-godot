class_name ArenaInventoryLayout
extends RefCounted

# Client-only arrangement of unlimited arena supplies. Resource gains are
# still decided by RecoveryNetwork/server; this is not an ownership inventory.
const SLOT_COUNT := 42
const ACTIONS := ["health_potion", "mana_potion"]
var storage_path := "user://arena_inventory.cfg"
var actions: Array[String] = []


func _init() -> void:
	actions.resize(SLOT_COUNT)
	actions.fill("")
	actions[0] = ACTIONS[0]
	actions[1] = ACTIONS[1]


func can_move(source: int, destination: int, expected_action: String) -> bool:
	return source >= 0 and source < SLOT_COUNT and destination >= 0 and destination < SLOT_COUNT and source != destination and expected_action in ACTIONS and actions[source] == expected_action


func move_item(source: int, destination: int, expected_action: String) -> bool:
	if not can_move(source, destination, expected_action):
		return false
	var previous := actions[destination]
	actions[destination] = actions[source]
	actions[source] = previous
	return true


func restore() -> void:
	var config := ConfigFile.new()
	if storage_path.is_empty() or config.load(storage_path) != OK:
		return
	var saved: Variant = config.get_value("arena", "slots", [])
	if not saved is Array or saved.size() != SLOT_COUNT:
		return
	var candidate: Array[String] = []
	for action: Variant in saved:
		if not action is String or (action != "" and not action in ACTIONS):
			return
		candidate.append(action)
	for action: String in ACTIONS:
		if candidate.count(action) != 1:
			return
	actions = candidate


func save() -> Error:
	if storage_path.is_empty():
		return OK
	var config := ConfigFile.new()
	config.set_value("arena", "slots", actions)
	return config.save(storage_path)
