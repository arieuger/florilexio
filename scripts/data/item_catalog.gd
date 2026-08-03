extends Resource
class_name ItemCatalog

@export var items: Array[ItemData] = []

func get_item(item_id: StringName) -> ItemData:
	if item_id == &"":
		return null

	for item in items:
		if item and item.id == item_id:
			return item
	return null

func get_plant(plant_id: StringName) -> PlantData:
	return get_item(plant_id) as PlantData


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var known_ids := {}

	for item in items:
		if item == null:
			errors.append("Item catalog cannot contain null values.")
			continue

		for item_error in item.get_validation_errors():
			errors.append("Item '%s': %s" % [item.resource_path, item_error])

		if item.id == &"":
			continue

		if known_ids.has(item.id):
			errors.append("Duplicated item id '%s': '%s' and '%s'."
				% [item.id, known_ids[item.id], item.resource_path])
			continue

		known_ids[item.id] = item.resource_path

	return errors