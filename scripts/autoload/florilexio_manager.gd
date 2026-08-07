extends Node

signal knowledge_changed(plant_id: StringName)

var _unlocked_fragments: Dictionary = {}


func has_any_knowledge(plant_id: StringName) -> bool:
	if plant_id == &"":
		return false

	var plant_knowledge: Dictionary = _unlocked_fragments.get(plant_id, {})
	return not plant_knowledge.is_empty()

func has_knowledge(plant_id: StringName, fragment_id: StringName) -> bool:
	if plant_id == &"" or fragment_id == &"":
		return false

	var plant_knowledge: Dictionary = _unlocked_fragments.get(plant_id, {})
	return plant_knowledge.has(fragment_id)


func unlock_knowledge(plant_id: StringName, fragment_id: StringName) -> void:
	if plant_id == &"":
		push_warning("FlorilexioManager: plant_id cannot be empty.")
		return

	if fragment_id == &"":
		push_warning("FlorilexioManager: fragment_id cannot be empty.")
		return

	var plant_knowledge: Dictionary = _unlocked_fragments.get(plant_id, {})

	if plant_knowledge.has(fragment_id):
		return

	plant_knowledge[fragment_id] = true
	_unlocked_fragments[plant_id] = plant_knowledge
	knowledge_changed.emit(plant_id)


func lock_knowledge(plant_id: StringName, fragment_id: StringName) -> void:
	if not _unlocked_fragments.has(plant_id):
		return

	var plant_knowledge: Dictionary = _unlocked_fragments[plant_id]

	if not plant_knowledge.erase(fragment_id):
		return

	if plant_knowledge.is_empty():
		_unlocked_fragments.erase(plant_id)
	else:
		_unlocked_fragments[plant_id] = plant_knowledge

	knowledge_changed.emit(plant_id)


func can_be_collected(plant_id: StringName, requirements: Array[StringName]) -> bool:

	if requirements.is_empty():
		return true

	if plant_id == &"":
		push_warning("FlorilexioManager: plant_id cannot be empty.")
		return false

	for requirement_id in requirements:
		if not has_knowledge(plant_id, requirement_id):
			return false

	return true


func reset_entry(plant_id: StringName) -> void:
	if not _unlocked_fragments.erase(plant_id):
		return

	knowledge_changed.emit(plant_id)


func debug_reset() -> void:
	if not OS.is_debug_build():
		return

	var affected_plant_ids := _unlocked_fragments.keys()
	_unlocked_fragments.clear()

	for plant_id in affected_plant_ids:
		knowledge_changed.emit(StringName(plant_id))
