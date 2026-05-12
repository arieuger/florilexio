extends Node

var discovered_plants: Dictionary = {}
var collected_plants: Dictionary = {}

func discover_plant(plant_id: String) -> void:
    if not discovered_plants.has(plant_id):
        discovered_plants[plant_id] = true

func collect_plant(plant_id: String) -> bool:
    if discovered_plants.has(plant_id):
        collected_plants[plant_id] = true
        return true
    else:
        print("Cannot collect plant that has not been discovered: " + plant_id)
        return false