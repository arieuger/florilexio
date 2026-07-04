extends RefCounted
class_name MinigameContext

var config: MinigameConfig

var target_id: StringName = &""
var display_name := ""

var difficulty_id: StringName = &"medium"
var required_hits: int = 3
var max_misses: int = 3
var parameters: Dictionary = {}
var rewards: Dictionary = {} # Así podemos incluír algún elemento extra máis que a planta
var metadata: Dictionary = {} # Para calquera outra cousa que se queira pasar


func get_minigame_id() -> StringName:
	return config.minigame_id if config else &""


func get_scene() -> PackedScene:
	return config.scene if config else null


func get_parameter(key: StringName, default_value: Variant = null) -> Variant:
	return parameters.get(key, default_value)


func get_reward(key: StringName, default_value: Variant = null) -> Variant:
	return rewards.get(key, default_value)


func get_metadata(key: StringName, default_value: Variant = null) -> Variant:
	return metadata.get(key, default_value)
