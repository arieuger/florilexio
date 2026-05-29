extends Area2D

@export_file("*.tscn") var target_area_path: String = ""
@export var target_spawn_id: StringName = &"default"
@export var transition_on_body_entered := true
@export_node_path("AnimatedSprite2D") var button_sprite_path: NodePath
@export var button_visibility_distance := 20.0
@export var default_animation: StringName = &"default"
@export var hovered_animation: StringName = &"hovered"
@export var pressed_animation: StringName = &"pressed"

var _is_transitioning := false
var _button_sprite: AnimatedSprite2D
var _is_mouse_over := false


func _ready() -> void:
	input_pickable = true
	_button_sprite = get_node_or_null(button_sprite_path) as AnimatedSprite2D
	_play_button_animation(default_animation)
	_update_button_visibility()
	set_process(is_instance_valid(_button_sprite))
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	body_entered.connect(_on_body_entered)


func _process(_delta: float) -> void:
	_update_button_visibility()


func _on_input_event(viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _button_sprite and not _button_sprite.visible:
			return

		viewport.set_input_as_handled()
		_play_button_animation(pressed_animation)
		_transition(true)


func _on_body_entered(body: Node2D) -> void:
	if transition_on_body_entered and body.is_in_group("player"):
		_transition(false)


func _on_mouse_entered() -> void:
	if _is_transitioning:
		return

	_is_mouse_over = true
	_play_button_animation(hovered_animation)


func _on_mouse_exited() -> void:
	if _is_transitioning:
		return

	_is_mouse_over = false
	_play_button_animation(default_animation)


func _transition(move_player_first: bool) -> void:
	if _is_transitioning or target_area_path.is_empty():
		return

	_is_transitioning = true
	var player := get_tree().get_first_node_in_group("player")
	if move_player_first and player and player.has_method("move_to_point"):
		var reached: bool = await player.move_to_point(global_position)
		if not reached:
			_is_transitioning = false
			_play_button_animation(default_animation)
			return

	var root := get_tree().current_scene
	if root and root.has_method("load_area"):
		var target_area := load(target_area_path) as PackedScene
		if not target_area:
			_is_transitioning = false
			_play_button_animation(default_animation)
			return
		root.call_deferred("load_area", target_area, target_spawn_id)
	else:
		_is_transitioning = false
		_play_button_animation(default_animation)


func _play_button_animation(animation_name: StringName) -> void:
	if not _button_sprite or animation_name == &"":
		return
	if not _button_sprite.sprite_frames or not _button_sprite.sprite_frames.has_animation(animation_name):
		return

	_button_sprite.play(animation_name)


func _update_button_visibility() -> void:
	if not _button_sprite:
		return

	var should_show := _is_player_near_button()
	if _button_sprite.visible == should_show:
		return

	_button_sprite.visible = should_show
	input_pickable = should_show
	if not should_show:
		_is_mouse_over = false
	else:
		_is_mouse_over = _is_mouse_inside_button_area()

	if _is_mouse_over:
		_play_button_animation(hovered_animation)
	else:
		_play_button_animation(default_animation)


func _is_player_near_button() -> bool:
	if button_visibility_distance <= 0.0:
		return true

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return false

	return player.global_position.distance_to(global_position) <= button_visibility_distance


func _is_mouse_inside_button_area() -> bool:
	if not _button_sprite or not _button_sprite.sprite_frames:
		return false

	var frame_texture := _button_sprite.sprite_frames.get_frame_texture(_button_sprite.animation, _button_sprite.frame)
	if not frame_texture:
		return false

	var mouse_position := get_global_mouse_position()
	var sprite_size := frame_texture.get_size()
	var sprite_rect := Rect2(_button_sprite.global_position - sprite_size * 0.5, sprite_size)
	return sprite_rect.has_point(mouse_position)
