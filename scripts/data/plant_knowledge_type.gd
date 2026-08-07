@tool
extends RefCounted
class_name PlantKnowledgeType

enum Type {
	NAME,
	DESCRIPTION,
	VISUAL_REFERENCE,
	USES,
	LOCATION,
	WARNING,
	SCIENTIFIC_NAME,
	OTHER_NAME,
	OTHER,
	MARGINALIA,
}

static func is_valid(value: int) -> bool:
	return value in Type.values()
