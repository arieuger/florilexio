@tool
class_name NotebookRevealCondition
extends Resource


func is_met(_quest_id: StringName) -> bool:
	return false


func get_validation_errors() -> PackedStringArray:
	return PackedStringArray()
