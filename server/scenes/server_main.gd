extends Node

@onready var player_registry: PlayerRegistry = (
	$PlayerRegistry
)

var practice_bot: ArenaPracticeBot


func _ready() -> void:
	print("Starting Argentum server...")
	practice_bot = ArenaPracticeBot.new(player_registry)
	practice_bot.reset_world.connect(_on_practice_reset)
	practice_bot.removed.connect(_on_bot_removed)
	practice_bot.status_changed.connect(_broadcast_bot_status)
	BotNetwork.command_requested.connect(_on_bot_command)
	BotNetwork.status_requested.connect(func(peer_id: int) -> void: BotNetwork.send_status(peer_id, practice_bot.status()))
	player_registry.basic_attack_resolved.connect(PlayerNetwork.send_basic_attack_result)

	NetworkManager.peer_connected.connect(
		_on_peer_connected
	)

	NetworkManager.peer_disconnected.connect(
		_on_peer_disconnected
	)

	PlayerNetwork.move_requested.connect(
		_on_move_requested
	)

	PlayerNetwork.basic_attack_requested.connect(
		_on_basic_attack_requested
	)

	PlayerNetwork.debug_damage_requested.connect(
		_on_debug_damage_requested
	)

	PlayerNetwork.debug_mana_spend_requested.connect(
		_on_debug_mana_spend_requested
	)
	SpellNetwork.cast_requested.connect(_on_spell_cast_requested)
	SpellNetwork.shot_requested.connect(_on_shot_requested)
	InventoryNetwork.move_requested.connect(_on_inventory_move)
	InventoryNetwork.use_requested.connect(_on_inventory_use)
	RecoveryNetwork.action_requested.connect(_on_recovery_action_requested)

	var error: Error = (
		NetworkManager.start_server()
	)

	if error != OK:
		push_error(
			"Server startup failed."
		)

		get_tree().quit(1)
		return

	print("Argentum server ready.")


func _process(_delta: float) -> void:
	for player: PlayerState in player_registry.advance_runtime():
		PlayerNetwork.broadcast_player_stats_updated(player.to_dictionary())
	for action: Dictionary in practice_bot.tick():
		_publish_bot_action(action)


func _on_recovery_action_requested(peer_id: int, action: String, request_id: int, source: String) -> void:
	var result := player_registry.try_recovery_action(peer_id, action, request_id, -1, source)
	if not result.ok:
		RecoveryNetwork.send_rejection(peer_id, request_id, str(result.message), int(result.get("remaining_msec", 0)))
		return
	PlayerNetwork.broadcast_player_stats_updated(result.state)
	if action == "respawn":
		PlayerNetwork.broadcast_player_moved(result.state)
	result.event.request_id = request_id
	RecoveryNetwork.broadcast_result(result.event)


func _on_peer_connected(
	peer_id: int
) -> void:
	print(
		"Registering peer: %d"
		% peer_id
	)

	practice_bot.peer_joining()
	var player: PlayerState = (
		player_registry.add_player(
			peer_id
		)
	)

	_send_new_player_to_existing_clients(
		peer_id,
		player
	)

	PlayerNetwork.send_snapshot_to(
		peer_id,
		player_registry.get_snapshot()
	)
	_broadcast_bot_status(practice_bot.status())


func _on_peer_disconnected(
	peer_id: int
) -> void:
	if not player_registry.has_player(
		peer_id
	):
		return

	practice_bot.peer_left(peer_id)
	player_registry.remove_player(
		peer_id
	)

	for existing_peer_id in (
		multiplayer.get_peers()
	):
		PlayerNetwork.send_player_despawned_to(
			existing_peer_id,
			peer_id
		)

	_broadcast_bot_status(practice_bot.status())

func _on_move_requested(
	peer_id: int,
	direction: int
) -> void:
	var player: PlayerState = (
		player_registry.try_move_player(
			peer_id,
			direction
		)
	)

	if player == null:
		return

	PlayerNetwork.broadcast_player_moved(
		player.to_dictionary()
	)


func _on_basic_attack_requested(
	peer_id: int
) -> void:
	var attacker := player_registry.get_player(peer_id)
	var was_meditating := attacker != null and attacker.is_meditating
	var target: PlayerState = (
		player_registry.try_basic_attack(
			peer_id
		)
	)
	if was_meditating and not attacker.is_meditating:
		PlayerNetwork.broadcast_player_stats_updated(attacker.to_dictionary())

	if target == null:
		return

	print(
		"SERVER STATE -> HP: %d | Alive: %s | Ghost: %s"
		% [
			target.current_health,
			target.is_alive,
			target.is_ghost
		]
	)

	PlayerNetwork.broadcast_player_stats_updated(
		target.to_dictionary()
	)


func _on_spell_cast_requested(peer_id: int, spell_id: int, target: Vector2i, request_id: int) -> void:
	var result := player_registry.try_cast_spell(peer_id, spell_id, target, request_id)
	if not result.ok:
		SpellNetwork.send_rejection(peer_id, request_id, result.message, result.remaining_msec)
		return
	PlayerNetwork.broadcast_player_stats_updated(result.caster_state)
	if int(result.target_state.peer_id) != peer_id:
		PlayerNetwork.broadcast_player_stats_updated(result.target_state)
	SpellNetwork.broadcast_result(result.event)


func _on_debug_damage_requested(
	peer_id: int
) -> void:
	var player: PlayerState = (
		player_registry.apply_damage(
			peer_id,
			CombatRules.DEBUG_DAMAGE_AMOUNT
		)
	)

	if player == null:
		return

	PlayerNetwork.broadcast_player_stats_updated(
		player.to_dictionary()
	)


func _on_debug_mana_spend_requested(
	peer_id: int
) -> void:
	var player: PlayerState = (
		player_registry.spend_mana(
			peer_id,
			CombatRules.DEBUG_MANA_COST
		)
	)

	if player == null:
		return

	PlayerNetwork.broadcast_player_stats_updated(
		player.to_dictionary()
	)


func _send_new_player_to_existing_clients(
	new_peer_id: int,
	player: PlayerState
) -> void:
	var player_data: Dictionary = (
		player.to_dictionary()
	)

	for existing_peer_id in (
		multiplayer.get_peers()
	):
		if existing_peer_id == new_peer_id:
			continue

		PlayerNetwork.send_player_spawned_to(
			existing_peer_id,
			player_data
		)


func _on_shot_requested(peer_id: int, target: Vector2i, request_id: int) -> void:
	var result := player_registry.try_ranged_attack(peer_id, target, request_id)
	if not result.ok:
		SpellNetwork.send_rejection(peer_id, request_id, result.message, result.remaining_msec)
		return
	PlayerNetwork.broadcast_player_stats_updated(result.caster_state)
	PlayerNetwork.broadcast_player_stats_updated(result.target_state)
	SpellNetwork.broadcast_result(result.event)


func _on_inventory_move(peer_id: int, source: int, destination: int, item_id: int, revision: int, request_id: int) -> void:
	_broadcast_inventory(peer_id, player_registry.try_inventory_move(peer_id, source, destination, item_id, revision, request_id))


func _on_inventory_use(peer_id: int, slot: int, item_id: int, revision: int, request_id: int) -> void:
	_broadcast_inventory(peer_id, player_registry.try_inventory_use(peer_id, slot, item_id, revision, request_id))


func _broadcast_inventory(peer_id: int, result: Dictionary) -> void:
	if not result.ok:
		InventoryNetwork.send_rejection(peer_id, str(result.message))
		return
	PlayerNetwork.broadcast_player_stats_updated(result.state)


func _on_bot_command(peer_id: int, enabled: bool, class_id: int, request_id: int) -> void:
	var result := practice_bot.request(peer_id, enabled, class_id, request_id)
	BotNetwork.send_result(peer_id, request_id, result)


func _on_practice_reset() -> void:
	for peer_id: int in multiplayer.get_peers():
		PlayerNetwork.send_snapshot_to(peer_id, player_registry.get_snapshot())


func _on_bot_removed(bot_id: int) -> void:
	for peer_id: int in multiplayer.get_peers():
		PlayerNetwork.send_player_despawned_to(peer_id, bot_id)


func _broadcast_bot_status(status: Dictionary) -> void:
	for peer_id: int in multiplayer.get_peers():
		BotNetwork.send_status(peer_id, status)


func _publish_bot_action(action: Dictionary) -> void:
	match str(action.kind):
		"move":
			PlayerNetwork.broadcast_player_moved(action.state)
		"cast":
			PlayerNetwork.broadcast_player_stats_updated(action.result.caster_state)
			if int(action.result.target_state.peer_id) != int(action.result.caster_state.peer_id):
				PlayerNetwork.broadcast_player_stats_updated(action.result.target_state)
			SpellNetwork.broadcast_result(action.result.event)
		"recovery":
			PlayerNetwork.broadcast_player_stats_updated(action.result.state)
		"melee":
			PlayerNetwork.broadcast_player_stats_updated(action.attacker)
			PlayerNetwork.broadcast_player_stats_updated(action.target)
