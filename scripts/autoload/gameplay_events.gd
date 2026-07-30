
extends Node

signal plant_collected(plant_id: StringName, collection_id: StringName, amount: int)
signal dialogue_completed(conversation_id: StringName, start_title: StringName, result_id: StringName)

func report_plant_collected(plant_id: StringName, collection_id: StringName, amount: int) -> bool:
	if plant_id.is_empty():
		push_warning("GameplayEvents: plant_id cannot be empty")
		return false

	if collection_id.is_empty():
		push_warning("GameplayEvents: collection_id cannot be empty")
		return false
		
	if amount <= 0:
		push_warning("GameplayEvents: collected amount must be positive")
		return false

	plant_collected.emit(plant_id, collection_id, amount)
	return true


func report_dialogue_completed(conversation_id: StringName, start_title: StringName, result_id: StringName = &"") -> bool:
	if conversation_id.is_empty():
		push_warning("GameplayEvents: conversation_id cannot be empty.")
		return false

	if start_title.is_empty():
		push_warning("GameplayEvents: start_title cannot be empty.")
		return false

	dialogue_completed.emit(conversation_id, start_title, result_id)
	return true