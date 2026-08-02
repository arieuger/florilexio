extends RefCounted
class_name PlantKnowledgeType

enum Type {
	NAME,
	DESCRIPTION,
	VISUAL_REFERENCE,
	USES,
	LOCATION,
	WARNING
}

static func is_valid(value: int) -> bool:
	return value in Type.values()
