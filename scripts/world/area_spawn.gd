extends Marker2D

@export var spawn_id: StringName = &"default"


func _enter_tree() -> void:
	add_to_group("area_spawn")
