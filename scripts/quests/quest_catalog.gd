@tool
class_name QuestCatalog
extends Resource

@export var catalog_id: StringName
@export var quests: Array[QuestDefinition] = []

func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if catalog_id.is_empty():
		errors.append("catalog_id is empty")

	if quests.is_empty():
		errors.append("catalog has no quests")

	var known_quest_ids := {}

	for index in range(quests.size()):
		var quest := quests[index]

		if quest == null:
			errors.append("quest at index %d is null" % index)
			continue

		if quest.quest_id.is_empty():
			continue

		if known_quest_ids.has(quest.quest_id):
			errors.append("duplicated quest_id '%s' in catalog"% quest.quest_id)
		else:
			known_quest_ids[quest.quest_id] = true

	return errors