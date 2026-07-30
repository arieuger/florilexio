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
