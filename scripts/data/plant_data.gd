extends Resource
class_name PlantData

@export var id: StringName
@export var display_name: String

@export  var short_description: String
@export_multiline var discovered_text: String

@export var icon: Texture2D
@export var sprite: Texture2D

@export_group("Knowledge")
@export var knowledge_fragments: Array[PlantKnowledgeFragment] = []

@export_group("Collection")
@export var collection_requirements: Array[StringName] = []

@export_group("")

func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var known_fragment_ids := {}
	var seen_requirements := {}

	if id == &"":
		errors.append("Plant id cannot be empty.")
	if display_name.is_empty():
		errors.append("Plant display name cannot be empty.")

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
