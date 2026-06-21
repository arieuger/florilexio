extends Resource
class_name MinigameTuning

func build_parameters(_difficulty: int, base_parameters: Dictionary) -> Dictionary:
    return base_parameters.duplicate(true)