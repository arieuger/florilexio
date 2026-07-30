class_name QuestObjectiveDefinition
extends Resource

enum EventType {
	NONE,
	PLANT_COLLECTED,
	DIALOGUE_COMPLETED,
	INTERACTABLE_USED,
	LOCATION_REACHED,
	ITEM_SUBMITTED
	# TODO: Eventualmente haberá que engadir ITEM_COLLECTED e, en TargetType
	# ITEM_INSTANCE e ITEM ou algo así
}

enum TargetType {
	NONE,
	PLANT_SPECIES,
	PLANT_INSTANCE,
	CONVERSATION,
	INTERACTABLE,
	LOCATION
}

@export var objective_id: StringName
@export var event_type: EventType = EventType.NONE
@export var target_type: TargetType = TargetType.NONE
@export var target_id: StringName
@export_range(1, 999, 1) var required_amount := 1


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
		errors.append("event_type %s is incompatible with target_type %s"% [EventType.keys()[event_type], TargetType.keys()[target_type],])

	return errors


func _is_target_type_valid() -> bool:
	match event_type:
		EventType.PLANT_COLLECTED:
			return target_type == TargetType.PLANT_SPECIES or target_type == TargetType.PLANT_INSTANCE

		EventType.DIALOGUE_COMPLETED:
			return target_type == TargetType.CONVERSATION

		EventType.INTERACTABLE_USED:
			return target_type == TargetType.INTERACTABLE

		EventType.LOCATION_REACHED:
			return target_type == TargetType.LOCATION

		EventType.ITEM_SUBMITTED:
			# Por agora solamente entregamos plantas por especie.
			return target_type == TargetType.PLANT_SPECIES

		_:
			return false