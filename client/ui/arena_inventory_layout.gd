class_name ArenaInventoryLayout
extends RefCounted

# View of the last confirmed server inventory. Legacy local layout helpers
# remain for isolated UI fixtures; live changes are sent through InventoryNetwork.
const SLOT_COUNT := 42
const ACTIONS := ["health_potion", "mana_potion"]
var storage_path := "user://arena_inventory.cfg"
var actions: Array[String] = []
var revision := 0
var equipped_ids: Array[int] = []
var authoritative := false


func _init() -> void:
	actions.resize(SLOT_COUNT)
	actions.fill("")
	actions[0] = ACTIONS[0]
	actions[1] = ACTIONS[1]


func can_move(source: int, destination: int, expected_action: String) -> bool:
	return source >= 0 and source < SLOT_COUNT and destination >= 0 and destination < SLOT_COUNT and source != destination and not expected_action.is_empty() and actions[source] == expected_action


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


func apply_state(state: PlayerState) -> void:
	authoritative = true
	revision = state.inventory_revision
	actions.clear()
	for item_id: int in state.inventory:
		actions.append("health_potion" if item_id == 38 else ("mana_potion" if item_id == 37 else ("item:%d" % item_id if item_id > 0 else "")))
	equipped_ids.clear()
	for item_id in state.equipped_items.values():
		equipped_ids.append(int(item_id))


func item_id(index: int) -> int:
	var token := actions[index]
	return 38 if token == "health_potion" else (37 if token == "mana_potion" else int(token.trim_prefix("item:")))
