extends MinigameTuning
class_name BushMinigameTuning

@export var rotation_speed_degrees: float = 0.0
@export_range(0.0, 1.0, 0.01) var zone_alpha_threshold := 0.1
@export var required_charge: float = 0.0
@export var charge_rate: float = 0.0
@export var charge_grace_seconds: float = -1.0
@export var cut_zone_margin_pixels := 1


func build_parameters(difficulty: int, base_parameters: Dictionary) -> Dictionary:
	var parameters := base_parameters.duplicate(true)
	var difficulty_settings := BushMinigameDifficulty.get_settings(difficulty)

	parameters[&"time_cost_blocks"] = parameters.get(&"time_cost_blocks", difficulty_settings["time_cost_blocks"])
	parameters[&"miss_time_cost_blocks"] = parameters.get(&"miss_time_cost_blocks", difficulty_settings["miss_time_cost_blocks"])
	parameters[&"rotation_speed_degrees"] = (
		rotation_speed_degrees
		if rotation_speed_degrees > 0.0
		else float(difficulty_settings["base_rotation_speed_degrees"])
	)
	parameters[&"required_charge"] = (
		required_charge
		if required_charge > 0.0
		else float(difficulty_settings["required_charge"])
	)
	parameters[&"charge_rate"] = (
		charge_rate
		if charge_rate > 0.0
		else float(difficulty_settings["charge_rate"])
	)
	parameters[&"charge_grace_seconds"] = (
		charge_grace_seconds
		if charge_grace_seconds >= 0.0
		else float(difficulty_settings["charge_grace_seconds"])
	)
	parameters[&"cut_zone_margin_pixels"] = cut_zone_margin_pixels
	parameters[&"zone_alpha_threshold"] = zone_alpha_threshold
	return parameters
