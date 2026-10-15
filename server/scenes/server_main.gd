extends Node

@onready var player_registry: PlayerRegistry = (
	$PlayerRegistry
)


func _ready() -> void:
	print("Starting Argentum server...")

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


func _on_peer_connected(
	peer_id: int
) -> void:
	print(
		"Registering peer: %d"
		% peer_id
	)

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


func _on_peer_disconnected(
	peer_id: int
) -> void:
	if not player_registry.has_player(
		peer_id
	):
		return

	player_registry.remove_player(
		peer_id
	)

	for existing_peer_id in (
		player_registry.get_peer_ids()
	):
		PlayerNetwork.send_player_despawned_to(
			existing_peer_id,
			peer_id
		)


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
	var target: PlayerState = (
		player_registry.try_basic_attack(
			peer_id
		)
	)

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
		player_registry.get_peer_ids()
	):
		if existing_peer_id == new_peer_id:
			continue

		PlayerNetwork.send_player_spawned_to(
			existing_peer_id,
			player_data
		)
