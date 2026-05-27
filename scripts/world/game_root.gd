extends Node2D

@export var initial_area: PackedScene
@export var initial_spawn_id: StringName = &"default"

@onready var current_area_container: Node2D = $CurrentArea
@onready var player: CharacterBody2D = $Player

var _current_area: Node


func _ready() -> void:
	if initial_area:
		load_area(initial_area, initial_spawn_id)


func load_area(area_scene: PackedScene, spawn_id: StringName = &"default") -> void:
	if not area_scene:
		return

	_detach_player()

	if is_instance_valid(_current_area):
		_current_area.queue_free()
		_current_area = null

	var next_area := area_scene.instantiate()
	current_area_container.add_child(next_area)
	_current_area = next_area

	_attach_player_to_area(next_area, spawn_id)


func _detach_player() -> void:
	if not is_instance_valid(player):
		return
	if player.get_parent() == self:
		return

	player.reparent(self)


func _attach_player_to_area(area: Node, spawn_id: StringName) -> void:
	if not is_instance_valid(player):
		return

	var y_sortables := area.get_node_or_null("YSortables")
	if y_sortables:
		player.reparent(y_sortables)

	var spawn := _find_spawn(area, spawn_id)
	if spawn:
		player.global_position = spawn.global_position


func _find_spawn(area: Node, spawn_id: StringName) -> Node2D:
	for spawn in get_tree().get_nodes_in_group("area_spawn"):
		if not area.is_ancestor_of(spawn):
			continue
		if spawn.get("spawn_id") == spawn_id:
			return spawn as Node2D
	return null
