extends Node

signal item_acquired(item_id: StringName, collection_id: StringName, amount: int)
signal dialogue_completed(conversation_id: StringName, start_title: StringName, result_id: StringName)


func report_item_acquired(item_id: StringName, collection_id: StringName, amount: int) -> bool:
	if item_id.is_empty():
		push_warning("GameplayEvents: item_id cannot be empty")
		return false

	if amount <= 0:
		push_warning("GameplayEvents: acquired amount must be positive")
		return false
	
	item_acquired.emit(item_id, collection_id, amount)
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