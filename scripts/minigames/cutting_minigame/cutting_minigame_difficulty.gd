extends MinigameDifficulty
class_name CuttingMinigameDifficulty

const SETTINGS := {
	MinigameDifficulty.Level.EASY: {
		"time_cost_blocks": 1.0,
		"miss_time_cost_blocks": 1,
		"base_rotation_speed_degrees": 340.0,
		"direction_change_chance": 0.6,
	},
	MinigameDifficulty.Level.MEDIUM: {
		"time_cost_blocks": 1.0,
		"miss_time_cost_blocks": 1,
		"base_rotation_speed_degrees": 400.0,
		"direction_change_chance": 0.8,
	},
	MinigameDifficulty.Level.HARD: {
		"time_cost_blocks": 2.0,
		"miss_time_cost_blocks": 1,
		"base_rotation_speed_degrees": 500.0,
		"direction_change_chance": 0.9,
	},
	MinigameDifficulty.Level.TUTORIAL: {
		"time_cost_blocks": 1.0,
		"miss_time_cost_blocks": 1,
		"base_rotation_speed_degrees": 300.0,
		"direction_change_chance": 0,
	},
}


static func get_settings(difficulty: int) -> Dictionary:
	return SETTINGS.get(difficulty, SETTINGS[MinigameDifficulty.Level.MEDIUM])
