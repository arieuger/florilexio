@tool
extends RefCounted
class_name ItemDatabase

const CATALOG : ItemCatalog = preload("res://resources/items/item_catalog.tres")

static func get_item(item_id: StringName) -> ItemData:
	return CATALOG.get_item(item_id)


static func get_plant(plant_id: StringName) -> PlantData:
	return CATALOG.get_plant(plant_id)


static func has_item(item_id: StringName) -> bool:
	return get_item(item_id) != null


static func get_validation_errors() -> PackedStringArray:
	return CATALOG.get_validation_errors()
