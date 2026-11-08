extends Node

enum Level {IMPORTANT, SECONDARY}
enum Category {CATALOG, INVENTORY, QUEST, OBJECTIVE}

signal notification_requested(level: Level, text: String)
signal pending_updates_changed()

var pending_updates := {
	Category.CATALOG: {},
	Category.INVENTORY: {},
	Category.QUEST: {},
	Category.OBJECTIVE: {}
}


func notify_item_aqcuired(item_id: StringName, amount: int) -> void:
	_mark_pending(Category.INVENTORY, item_id)
	notification_requested.emit(Level.SECONDARY, "Novo obxeto: %s x%d" % [item_id, amount])


func notify_knowledge_unlocked(plant_id: StringName, collection_unlocked: bool) -> void:
	_mark_pending(Category.CATALOG, plant_id)
	if collection_unlocked:
		notification_requested.emit(Level.IMPORTANT, "Novo coñecemento: %s" % plant_id)
	else:
		notification_requested.emit(Level.SECONDARY, "Novo fragmento: %s" % plant_id)


func notify_quest_started(mission_id: StringName) -> void:
	_mark_pending(Category.QUEST, mission_id)
	notification_requested.emit(Level.IMPORTANT, "Nova misión: %s" % mission_id)


func notify_quest_completed(mission_id: StringName) -> void:
	_mark_pending(Category.QUEST, mission_id)
	notification_requested.emit(Level.IMPORTANT, "Misión completada: %s" % mission_id)


func _mark_pending(category: Category, id: StringName) -> void:
	pending_updates[category][id] = true
	pending_updates_changed.emit()


func has_pending(category: Category) -> bool:
	return pending_updates[category].size() > 0


func mark_as_read(category: Category, id: StringName) -> void:
	if not pending_updates.has(category):
		return

	pending_updates[category].erase(id)
	pending_updates_changed.emit()