extends "res://client/input/local_input_controller.gd"

var request_directions: Array[int] = []


func _send_move_request(direction: int) -> void:
	request_directions.append(direction)
