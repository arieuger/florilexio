extends MinigameTuning
class_name CuttingMinigameTuning

@export var rotation_speed_degrees: float = 0.0
@export_range(0.0, 1.0, 0.01) var success_alpha_threshold := 0.1

func build_parameters(difficulty: int, base_parameters: Dictionary) -> Dictionary:
	var parameters := base_parameters.duplicate(true)
	var difficulty_settings := CuttingMinigameDifficulty.get_settings(difficulty)

	parameters[&"time_cost_blocks"] = parameters.get(&"time_cost_blocks", difficulty_settings["time_cost_blocks"])
	parameters[&"miss_time_cost_blocks"] = parameters.get(&"miss_time_cost_blocks", difficulty_settings["miss_time_cost_blocks"])
	parameters[&"rotation_speed_degrees"] = (
		rotation_speed_degrees
		if rotation_speed_degrees > 0.0
		else float(difficulty_settings["base_rotation_speed_degrees"])
	)
	parameters[&"success_alpha_threshold"] = success_alpha_threshold
	parameters[&"direction_change_chance"] = difficulty_settings["direction_change_chance"]
	return parameters
