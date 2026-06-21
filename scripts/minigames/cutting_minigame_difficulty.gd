extends RefCounted
class_name CuttingMinigameDifficulty

enum Difficulty { EASY, MEDIUM, HARD, TUTORIAL }

const SETTINGS := {
	Difficulty.EASY: {
		"time_cost_blocks": 1.0,
		"miss_time_cost_blocks": 1,
		"base_rotation_speed_degrees": 340.0,
		"direction_change_chance": 0.6,
	},
	Difficulty.MEDIUM: {
		"time_cost_blocks": 1.0,
		"miss_time_cost_blocks": 1,
		"base_rotation_speed_degrees": 400.0,
		"direction_change_chance": 0.8,
	},
	Difficulty.HARD: {
		"time_cost_blocks": 2.0,
		"miss_time_cost_blocks": 1,
		"base_rotation_speed_degrees": 500.0,
		"direction_change_chance": 0.9,
	},
	Difficulty.TUTORIAL: {
		"time_cost_blocks": 1.0,
		"miss_time_cost_blocks": 1,
		"base_rotation_speed_degrees": 300.0,
		"direction_change_chance": 0,
	},
}


static func get_settings(difficulty: int) -> Dictionary:
	return SETTINGS.get(difficulty, SETTINGS[Difficulty.MEDIUM])


static func get_id(difficulty: int) -> StringName:
	match difficulty:
		Difficulty.EASY:
			return &"easy"
		Difficulty.HARD:
			return &"hard"
		Difficulty.TUTORIAL:
			return &"tutorial"
		_:
			return &"medium"
