extends Area2D

@export_file("*.tscn") var target_area_path: String = ""
@export var target_spawn_id: StringName = &"default"

var _is_transitioning := false


func _ready() -> void:
	input_pickable = true
	input_event.connect(_on_input_event)
	body_entered.connect(_on_body_entered)


func _on_input_event(viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		viewport.set_input_as_handled()
		_transition(true)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_transition(false)


func _transition(move_player_first: bool) -> void:
	if _is_transitioning or target_area_path.is_empty():
		return

	_is_transitioning = true
	var player := get_tree().get_first_node_in_group("player")
	if move_player_first and player and player.has_method("move_to_point"):
		var reached: bool = await player.move_to_point(global_position)
		if not reached:
			_is_transitioning = false
			return

	var root := get_tree().current_scene
	if root and root.has_method("load_area"):
		var target_area := load(target_area_path) as PackedScene
		root.load_area(target_area, target_spawn_id)
