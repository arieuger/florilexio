extends Resource
class_name MinigameTuning

@export var required_hits: int = 3
@export var max_misses: int = 3


func apply_to_context(context: MinigameContext, difficulty: int, base_parameters: Dictionary) -> void:
    context.required_hits = required_hits
    context.max_misses = max_misses
    context.parameters = build_parameters(difficulty, base_parameters)


func build_parameters(_difficulty: int, base_parameters: Dictionary) -> Dictionary:
    return base_parameters.duplicate(true)
