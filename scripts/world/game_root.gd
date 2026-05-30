extends Node2D

@export var initial_area: PackedScene
@export var initial_spawn_id: StringName = &"default"
@export var transition_color := Color(0, 0, 0, 1)
@export var play_intro_on_start := true
@export var intro_dialogue: DialogueResource = preload("res://dialogues/intro.dialogue")
@export var intro_dialogue_title := "start"
@export var intro_info_balloon_scene: PackedScene = preload("res://ui/dialogue/generic_info_balloon.tscn")

@onready var current_area_container: Node2D = $CurrentArea
@onready var player: CharacterBody2D = $Player

var _current_area: Node
var _area_transition_tween: Tween


func _ready() -> void:
	_set_player_movement_enabled(false)
	if initial_area:
		load_area(initial_area, initial_spawn_id)
	if play_intro_on_start:
		_run_intro_sequence.call_deferred()
	else:
		_set_player_movement_enabled(true)
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


func transition_to_area(area_scene: PackedScene, spawn_id: StringName = &"default", fade_duration: float = 0.45) -> void:
	if not area_scene:
		return

	if _area_transition_tween:
		_area_transition_tween.kill()

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)

	var fade_rect := ColorRect.new()
	fade_rect.color = Color(transition_color.r, transition_color.g, transition_color.b, 0.0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(fade_rect)

	_area_transition_tween = create_tween()
	_area_transition_tween.tween_property(fade_rect, "color:a", transition_color.a, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _area_transition_tween.finished

	load_area(area_scene, spawn_id)
	await get_tree().process_frame

	_area_transition_tween = create_tween()
	_area_transition_tween.tween_property(fade_rect, "color:a", 0.0, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_area_transition_tween.tween_callback(fade_layer.queue_free)
	await _area_transition_tween.finished


func move_player_to_spawn(spawn_id: StringName) -> void:
	if not is_instance_valid(_current_area) or not is_instance_valid(player):
		return

	var spawn := _find_spawn(_current_area, spawn_id)
	if not spawn:
		push_warning("GameRoot: could not find spawn: %s" % spawn_id)
		return

	player.global_position = spawn.global_position
	if player.has_method("resync_sound_listener"):
		player.resync_sound_listener()
	_snap_camera_to_player()
	call_deferred("_snap_camera_to_player")


func set_player_movement_enabled(enabled: bool) -> void:
	_set_player_movement_enabled(enabled)


func get_current_area_marker(marker_id: StringName) -> Node2D:
	if marker_id == &"" or not is_instance_valid(_current_area):
		return null

	var spawn := _find_spawn(_current_area, marker_id)
	if spawn:
		return spawn

	var node_by_name := _current_area.find_child(String(marker_id), true, false) as Node2D
	if node_by_name:
		return node_by_name

	for node in _current_area.find_children("*", "Node2D", true, false):
		var node_2d := node as Node2D
		if not node_2d:
			continue
		if _node_matches_marker_id(node_2d, marker_id):
			return node_2d

	return null


func _run_intro_sequence() -> void:
	await get_tree().process_frame

	if not is_instance_valid(intro_dialogue) or not is_instance_valid(intro_info_balloon_scene):
		_set_player_movement_enabled(true)
		return

	DialogueManager.show_dialogue_balloon_scene(
		intro_info_balloon_scene,
		intro_dialogue,
		intro_dialogue_title,
		[self]
	)
	await _wait_for_dialogue_to_end(intro_dialogue)
	_set_player_movement_enabled(true)


func _wait_for_dialogue_to_end(dialogue_resource: DialogueResource) -> void:
	while true:
		var ended_resource: DialogueResource = await DialogueManager.dialogue_ended
		if ended_resource == dialogue_resource:
			return


func _set_player_movement_enabled(enabled: bool) -> void:
	if not is_instance_valid(player):
		return

	if player.has_method("set_movement_enabled"):
		player.set_movement_enabled(enabled)
	else:
		player.set("movement_enabled", enabled)


func _detach_player() -> void:
	if not is_instance_valid(player):
		return
	if player.get_parent() == self:
		return

	player.reparent(self)
	if player.has_method("resync_sound_listener"):
		player.resync_sound_listener()


func _attach_player_to_area(area: Node, spawn_id: StringName) -> void:
	if not is_instance_valid(player):
		return

	var y_sortables := area.get_node_or_null("YSortables")
	if y_sortables:
		player.reparent(y_sortables)

	var spawn := _find_spawn(area, spawn_id)
	if spawn:
		player.global_position = spawn.global_position

	if player.has_method("resync_sound_listener"):
		player.resync_sound_listener()
	_resync_area_sound_emitters(area)

	_apply_area_camera_config(area)
	_warn_if_player_is_outside_camera_limits(area)
	_snap_camera_to_player()
	call_deferred("_snap_camera_to_player")
	call_deferred("_resync_area_sound_emitters", area)


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


func _node_matches_marker_id(node: Node2D, marker_id: StringName) -> bool:
	if StringName(node.name) == marker_id:
		return true
	if _node_property_matches(node, &"marker_id", marker_id):
		return true
	if _node_property_matches(node, &"spawn_id", marker_id):
		return true
	return false


func _node_property_matches(node: Node, property_name: StringName, expected_value: Variant) -> bool:
	for property in node.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return node.get(property_name) == expected_value
	return false


# Funcións necesarias para que o SoundListener do Player siga funcionando cando se introduce na escea

func _resync_area_sound_emitters(area: Node) -> void:
	if not is_instance_valid(area):
		return

	for node in area.find_children("*", "", true, false):
		if not node.has_method("set_2d_attributes"):
			continue
		node.force_update_transform()
		node.set_2d_attributes(node.global_transform)
