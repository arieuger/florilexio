@tool
extends ItemData
class_name WaterData

@export var source_font: StringName

func get_validation_errors() -> PackedStringArray:
	var errors := super.get_validation_errors()
	if source_font == null or source_font == &"":
		errors.append("Source font must exist")

	return errors
