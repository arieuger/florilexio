extends Node

## Esta clase sirve para comunicar accións de algún sitema (inventario, diálogo, etc.) que poden afectar a outros sistemas (p. exemplo o sistema de misións). 
## A idea é que os sistemas que producen eventos non teñan que coñecer aos sistemas que se poidan ver afectados. 
## En vez de iso, os sistemas que producen eventos emiten sinais, e outros sistemas poden conectarse a eses sinais para recibir notificacións cando se producen eventos. Sirve para desacoplar.

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