extends MinigameDifficulty
class_name BushMinigameDifficulty

const SETTINGS := {
	MinigameDifficulty.Level.EASY: {
		"time_cost_blocks": 1.0,
		"miss_time_cost_blocks": 1.0,
		"base_rotation_speed_degrees": 300.0,
		"required_charge": 3.0,
		"charge_rate": 8.0,
		"charge_grace_seconds": 0.35,
	},
	MinigameDifficulty.Level.MEDIUM: {
		"time_cost_blocks": 1.0,
		"miss_time_cost_blocks": 1.0,
		"base_rotation_speed_degrees": 340.0,
		"required_charge": 3.5,
		"charge_rate": 7.0,
		"charge_grace_seconds": 0.25,
	},
	MinigameDifficulty.Level.HARD: {
		"time_cost_blocks": 2.0,
		"miss_time_cost_blocks": 1.0,
		"base_rotation_speed_degrees": 400.0,
		"required_charge": 4.0,
		"charge_rate": 6.0,
		"charge_grace_seconds": 0.18,
	},
	MinigameDifficulty.Level.TUTORIAL: {
		"time_cost_blocks": 1.0,
		"miss_time_cost_blocks": 1.0,
		"base_rotation_speed_degrees": 300.0,
		"required_charge": 2.5,
		"charge_rate": 8.0,
		"charge_grace_seconds": 0.45,
	},
}


static func get_settings(difficulty: int) -> Dictionary:
	return SETTINGS.get(difficulty, SETTINGS[MinigameDifficulty.Level.MEDIUM])
