extends "res://server/systems/player_registry.gd"

var forced_outcome := "hit"
var outcome_rolls := 0


func _roll_physical_outcome(_target: PlayerState) -> String:
	outcome_rolls += 1
	return forced_outcome
