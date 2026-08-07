@tool
extends Resource
class_name ItemData

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D

func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if id == &"":
		errors.append("Item id cannot be empty.")
	if display_name.is_empty():
		errors.append("Item display name cannot be empty.")

	return errors
