@tool
class_name ConversationCondition
extends Resource

func is_met(_context: ConversationContext) -> bool:
	return true


func get_validation_errors() -> PackedStringArray:
	return PackedStringArray()


func get_debug_description() -> String:
	if not resource_path.is_empty():
		return resource_path.get_file()

	return get_class()
