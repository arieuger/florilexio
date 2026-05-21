extends Node

signal consumed_time_added(total_consumed_time: int)

var discovered_plants: Dictionary = {}
var collected_plants: Dictionary = {}
var old_woman_already_spoke: bool = false

var _consumed_time: int = 0 # Bloques de 15 minutos: en 12 horas, 48 bloques

var consumed_time: int:
    get:
        return _consumed_time

func add_consumed_time(time: int) -> void:
    _consumed_time += time

    consumed_time_added.emit(_consumed_time)
    # TODO: Actualizar UI según o tempo consumido
    print("Consumed time: " + str(_consumed_time) + " seconds")

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