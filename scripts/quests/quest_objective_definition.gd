@tool
class_name QuestObjectiveDefinition
extends Resource

enum EventType {
	NONE,
	PLANT_COLLECTED,
	DIALOGUE_COMPLETED,
	INTERACTABLE_USED,
	LOCATION_REACHED,
	INVENTORY_SUBMITTED,
	ITEM_COLLECTED,
	INVENTORY_OWNED,
}

enum TargetType {
	NONE,
	PLANT_SPECIES,
	PLANT_INSTANCE,
	CONVERSATION,
	INTERACTABLE,
	LOCATION,
	ITEM_ID,
}

enum ItemSubmissionMode {
	GIVE,
	SHOW,
}

@export var objective_id: StringName
@export_multiline var description: String
@export var event_type: EventType = EventType.NONE
@export var target_type: TargetType = TargetType.NONE
@export var target_id: StringName
@export var show_in_notebook := true
@export_range(1, 999, 1) var required_amount := 1
@export var item_submission_mode: ItemSubmissionMode = ItemSubmissionMode.GIVE


static func get_allowed_target_types(for_event_type: EventType) -> Array[TargetType]:
	match for_event_type:
		EventType.PLANT_COLLECTED:
			return [
				TargetType.PLANT_SPECIES,
				TargetType.PLANT_INSTANCE,
			]

		EventType.DIALOGUE_COMPLETED:
			return [
				TargetType.CONVERSATION,
			]

		EventType.INTERACTABLE_USED:
			return [
				TargetType.INTERACTABLE,
			]

		EventType.LOCATION_REACHED:
			return [
				TargetType.LOCATION,
			]

		EventType.INVENTORY_SUBMITTED:
			return [
				TargetType.PLANT_SPECIES,
				TargetType.ITEM_ID
			]

		EventType.ITEM_COLLECTED:
			return [
				TargetType.ITEM_ID
			]
		EventType.INVENTORY_OWNED:
			return [
				TargetType.ITEM_ID,
				TargetType.PLANT_SPECIES,
			]
		_:
			return []


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if objective_id.is_empty():
		errors.append("objective_id is empty")

	if event_type == EventType.NONE:
		errors.append("event_type is NONE")

	if target_type == TargetType.NONE:
		errors.append("target_type is NONE")

	if target_id.is_empty():
		errors.append("target_id is empty")

	if required_amount < 1:
		errors.append("required_amount must be at least 1")

	if target_type != TargetType.NONE and not _is_target_type_valid():
		errors.append("event_type %s is incompatible with target_type %s" % [EventType.keys()[event_type], TargetType.keys()[target_type], ])

	return errors


func _is_target_type_valid() -> bool:
	return target_type in get_allowed_target_types(event_type)


func consumes_submitted_item() -> bool:
	return (
		event_type == EventType.INVENTORY_SUBMITTED
		and item_submission_mode == ItemSubmissionMode.GIVE
	)
