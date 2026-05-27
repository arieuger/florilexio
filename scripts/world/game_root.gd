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

	_apply_area_camera_config(area)
	_warn_if_player_is_outside_camera_limits(area)
	_snap_camera_to_player()
	call_deferred("_snap_camera_to_player")


func _apply_area_camera_config(area: Node) -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if not camera:
		return

	var camera_config := area.get_node_or_null("CameraConfig")
	if camera_config and camera_config.has_method("apply_to"):
		camera_config.apply_to(camera)


func _warn_if_player_is_outside_camera_limits(area: Node) -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if not camera:
		return

	var limits := Rect2(
		Vector2(camera.limit_left, camera.limit_top),
		Vector2(camera.limit_right - camera.limit_left, camera.limit_bottom - camera.limit_top)
	)
	if not limits.has_point(player.global_position):
		push_warning(
			"Player spawn is outside camera limits in %s. Player: %s, limits: %s" %
			[area.name, player.global_position, limits]
		)


func _snap_camera_to_player() -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if not camera:
		return

	camera.position = Vector2.ZERO
	if camera.has_method("reset_smoothing"):
		camera.reset_smoothing()
	if camera.has_method("align"):
		camera.align()
	if camera.has_method("force_update_scroll"):
		camera.force_update_scroll()


func _find_spawn(area: Node, spawn_id: StringName) -> Node2D:
	for spawn in get_tree().get_nodes_in_group("area_spawn"):
		if not area.is_ancestor_of(spawn):
			continue
		if spawn.get("spawn_id") == spawn_id:
			return spawn as Node2D
	return null
