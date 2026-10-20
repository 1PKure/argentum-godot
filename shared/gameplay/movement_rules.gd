class_name MovementRules
extends RefCounted

enum Direction {
	NORTH,
	EAST,
	SOUTH,
	WEST
}

const GRID_COLUMNS: int = 20
const GRID_ROWS: int = 12

const MOVE_INTERVAL_MSEC: int = 140
const PRACTICE_BOT_MOVE_INTERVAL_MSEC: int = 132
const MOVE_TIMING_TOLERANCE_MSEC: int = 20
const MOVE_INTERVAL_SECONDS: float = MOVE_INTERVAL_MSEC / 1000.0


static func is_move_ready(current_time: int, last_move_time: int, interval_msec: int = MOVE_INTERVAL_MSEC) -> bool:
	return (
		current_time + MOVE_TIMING_TOLERANCE_MSEC
		>= last_move_time + interval_msec
	)


static func get_accepted_move_time(current_time: int, last_move_time: int, interval_msec: int = MOVE_INTERVAL_MSEC) -> int:
	# Keep the scheduled cadence when a request arrives a few milliseconds early.
	# The tolerance must not be subtracted again on every accepted movement.
	return maxi(current_time, last_move_time + interval_msec)


static func is_valid_direction(direction: int) -> bool:
	return (
		direction >= Direction.NORTH
		and direction <= Direction.WEST
	)


static func get_offset(direction: int) -> Vector2i:
	match direction:
		Direction.NORTH:
			return Vector2i(0, -1)

		Direction.EAST:
			return Vector2i(1, 0)

		Direction.SOUTH:
			return Vector2i(0, 1)

		Direction.WEST:
			return Vector2i(-1, 0)

	return Vector2i.ZERO


static func is_inside_bounds(position: Vector2i) -> bool:
	return (
		position.x >= 0
		and position.x < GRID_COLUMNS
		and position.y >= 0
		and position.y < GRID_ROWS
	)
