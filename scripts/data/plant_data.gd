@tool
extends ItemData
class_name PlantData

@export_group("Knowledge")
@export var knowledge_fragments: Array[PlantKnowledgeFragment] = []

@export_group("Collection")
@export var collection_requirements: Array[StringName] = []

@export_group("Plant features")
@export var is_poisonous := false
@export var is_mortal := false
@export var is_on_danger := false
@export var is_magic := false
@export var is_invasive := false

@export_group("")


func get_knowledge_fragment(fragment_id: StringName) -> PlantKnowledgeFragment:
	if fragment_id == &"":
		return null

	for fragment in knowledge_fragments:
		if fragment and fragment.id == fragment_id:
			return fragment

	return null


func get_validation_errors() -> PackedStringArray:
	var errors := super.get_validation_errors()
	var known_fragment_ids := {}
	var seen_requirements := {}

	for fragment in knowledge_fragments:
		if fragment == null:
			errors.append("Knowledge fragments cannot contain null values.")
			continue

		if fragment.id == &"":
			errors.append("Knowledge fragment id cannot be empty.")
			continue

		if not PlantKnowledgeType.is_valid(fragment.knowledge_type):
			errors.append(
				"Knowledge fragment '%s' has an invalid type: %s."
				% [fragment.id, fragment.knowledge_type]
			)

		if known_fragment_ids.has(fragment.id):
			errors.append("Duplicated knowledge fragment id: %s." % fragment.id)
			continue

		known_fragment_ids[fragment.id] = true

	for requirement_id in collection_requirements:
		if requirement_id == &"":
			errors.append("Collection requirement id cannot be empty.")
			continue

		if seen_requirements.has(requirement_id):
			errors.append(
				"Duplicated collection requirement: %s." % requirement_id
			)
			continue

		seen_requirements[requirement_id] = true

		if not known_fragment_ids.has(requirement_id):
			errors.append("Collection requirement references an unknown fragment: %s." % requirement_id)

	return errors
