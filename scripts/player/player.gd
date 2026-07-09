extends CharacterBody2D

signal auto_move_finished(reached: bool)

@export var max_speed := 60.0
@export var acceleration := 420.0
@export var deceleration := 520.0
@export var auto_move_stop_distance := 2.0
@export var interaction_stop_distance := 6.0
@export var auto_move_timeout := 5.0
@export var auto_move_stuck_distance := 0.1
@export var auto_move_stuck_time := 0.8
@export var auto_move_stuck_speed := 3.0
@export var movement_enabled := true
@export var navigation_path_desired_distance := 3.0
@export var navigation_target_desired_distance := 2.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sound_listener: Node2D = $SoundListener
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

var _last_facing := "down"
var _auto_move_target := Vector2.ZERO
var _auto_move_arrival_distance := 2.0
var _auto_move_elapsed := 0.0
var _auto_move_current_timeout := 0.0
var _auto_move_stuck_elapsed := 0.0
var _auto_move_previous_distance := INF
var _auto_move_previous_position := Vector2.ZERO
var _is_auto_moving := false
var _auto_move_target_area: Area2D
var _last_sound_listener_transform := Transform2D()
var _has_synced_sound_listener := false

func _ready():
	add_to_group("player")
	navigation_agent.path_desired_distance = navigation_path_desired_distance
	navigation_agent.target_desired_distance = navigation_target_desired_distance
	resync_sound_listener()

func _unhandled_input(event):
	if not movement_enabled:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		start_auto_move(get_global_mouse_position())

func _physics_process(delta: float):
	if not movement_enabled:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
		_update_animation(Vector2.ZERO)
		move_and_slide()
		_sync_sound_listener_to_fmod()
		return

	var input_direction := Input.get_vector("left", "right", "up", "down")

	if _is_auto_moving and input_direction != Vector2.ZERO:
		_finish_auto_move(false)

	if _is_auto_moving:
		_process_auto_move(delta)
	else:
		_process_player_input(delta, input_direction)

	move_and_slide()
	_sync_sound_listener_to_fmod()

	if _is_auto_moving:
		_check_auto_move_stuck(delta)

func move_to_point(global_target: Vector2, stop_distance := -1.0) -> bool:
	if not movement_enabled:
		return false

	var arrival_distance := auto_move_stop_distance if stop_distance < 0.0 else stop_distance
	if global_position.distance_to(global_target) <= arrival_distance:
		return true

	if not start_auto_move(global_target, arrival_distance):
		return false

	return await auto_move_finished

func move_to_area(area: Area2D) -> bool:
	if not movement_enabled or not is_instance_valid(area):
		return false

	if _is_global_point_inside_area(area, global_position):
		return true

	if _is_auto_moving:
		_finish_auto_move(false)

	_start_auto_move(_get_area_navigation_target(area), auto_move_stop_distance, area)
	_is_auto_moving = true

	return await auto_move_finished

func start_auto_move(global_target: Vector2, stop_distance := -1.0) -> bool:
	if not movement_enabled:
		return false

	if _is_auto_moving:
		_finish_auto_move(false)

	var arrival_distance := auto_move_stop_distance if stop_distance < 0.0 else stop_distance
	_start_auto_move(global_target, arrival_distance)
	_is_auto_moving = true
	return true

func set_movement_enabled(enabled: bool) -> void:
	movement_enabled = enabled
	if not movement_enabled and _is_auto_moving:
		_finish_auto_move(false)

func _process_player_input(delta: float, input_direction: Vector2):
	var target_velocity := input_direction * max_speed

	if input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)	

	play_footstep(delta)
	_update_animation(input_direction)

func _process_auto_move(delta: float):
	_auto_move_elapsed += delta

	if is_instance_valid(_auto_move_target_area) and _is_global_point_inside_area(_auto_move_target_area, global_position):
		_finish_auto_move(true)
		return

	var current_target := navigation_agent.get_next_path_position()
	var target_offset := current_target - global_position
	var final_distance := global_position.distance_to(_auto_move_target)

	if final_distance <= _auto_move_arrival_distance:
		_finish_auto_move(true)
		return

	if _auto_move_elapsed >= _auto_move_current_timeout:
		_finish_auto_move(false)
		return

	if navigation_agent.is_navigation_finished():
		_finish_auto_move(final_distance <= _auto_move_arrival_distance + navigation_target_desired_distance)
		return

	if target_offset.length_squared() <= 0.0001:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
		_update_animation(Vector2.ZERO)
		return

	var move_direction := target_offset.normalized()
	velocity = velocity.move_toward(move_direction * max_speed, acceleration * delta)
	play_footstep(delta)
	_update_animation(move_direction)

func _finish_auto_move(reached: bool):
	_is_auto_moving = false
	_auto_move_arrival_distance = auto_move_stop_distance
	_auto_move_target_area = null
	navigation_agent.target_position = global_position
	velocity = Vector2.ZERO
	_update_animation(Vector2.ZERO)
	auto_move_finished.emit(reached)

func _start_auto_move(global_target: Vector2, arrival_distance: float, target_area: Area2D = null) -> void:
	_auto_move_target = global_target
	_auto_move_arrival_distance = arrival_distance
	_auto_move_elapsed = 0.0
	_auto_move_current_timeout = maxf(auto_move_timeout, global_position.distance_to(global_target) / max_speed + 1.0)
	_auto_move_stuck_elapsed = 0.0
	_auto_move_previous_distance = global_position.distance_to(global_target)
	_auto_move_previous_position = global_position
	_auto_move_target_area = target_area
	navigation_agent.target_position = global_target

func _check_auto_move_stuck(delta: float):
	var current_distance := global_position.distance_to(_auto_move_target)
	var progress := _auto_move_previous_distance - current_distance
	var moved_distance := global_position.distance_to(_auto_move_previous_position)
	var is_moving := moved_distance > auto_move_stuck_speed * delta

	if progress <= auto_move_stuck_distance and not is_moving:
		_auto_move_stuck_elapsed += delta
	else:
		_auto_move_stuck_elapsed = 0.0

	_auto_move_previous_distance = current_distance
	_auto_move_previous_position = global_position

	if _auto_move_stuck_elapsed >= auto_move_stuck_time:
		_finish_auto_move(false)

func _get_area_collision_shapes(area: Area2D) -> Array[CollisionShape2D]:
	var collision_shapes: Array[CollisionShape2D] = []
	for child in area.find_children("*", "CollisionShape2D", true, false):
		var collision_shape := child as CollisionShape2D
		if collision_shape and not collision_shape.disabled and collision_shape.shape:
			collision_shapes.append(collision_shape)

	return collision_shapes

func _get_area_navigation_target(area: Area2D) -> Vector2:
	var collision_shapes := _get_area_collision_shapes(area)
	if collision_shapes.is_empty():
		return area.global_position

	var closest_shape: CollisionShape2D = collision_shapes[0]
	var closest_distance := global_position.distance_squared_to(closest_shape.global_position)
	for collision_shape in collision_shapes:
		var distance := global_position.distance_squared_to(collision_shape.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_shape = collision_shape

	return closest_shape.global_position

func _is_global_point_inside_area(area: Area2D, global_point: Vector2) -> bool:
	for collision_shape in _get_area_collision_shapes(area):
		var local_point := collision_shape.global_transform.affine_inverse() * global_point
		if _is_local_point_inside_shape(collision_shape.shape, local_point):
			return true

	return false

func _is_local_point_inside_shape(shape: Shape2D, local_point: Vector2) -> bool:
	if shape is CircleShape2D:
		var circle := shape as CircleShape2D
		return local_point.length_squared() <= circle.radius * circle.radius
	if shape is RectangleShape2D:
		var rectangle := shape as RectangleShape2D
		var half_size := rectangle.size * 0.5
		return absf(local_point.x) <= half_size.x and absf(local_point.y) <= half_size.y
	if shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		var half_segment_height := maxf(0.0, capsule.height * 0.5 - capsule.radius)
		var closest_point := Vector2(0.0, clampf(local_point.y, -half_segment_height, half_segment_height))
		return local_point.distance_squared_to(closest_point) <= capsule.radius * capsule.radius

	return local_point == Vector2.ZERO

func _update_animation(direction: Vector2):
	if direction == Vector2.ZERO:
		_play_animation_if_needed("idle_" + _last_facing)
	elif direction.y < 0:
		_last_facing = "up"
		_play_animation_if_needed("walk_up")
	else:
		_last_facing = "down"
		_play_animation_if_needed("walk_down")

func _play_animation_if_needed(animation_name: String) -> void:
	if animated_sprite.animation == animation_name and animated_sprite.is_playing():
		return

	animated_sprite.play(animation_name)

# Sounds
const MIN_STEP_GAP := 0.25  # segundos mínimos entre pasos
const STEP_INTERVAL := 1.5
var last_step_time := 0.0
var step_distance := 0.0

func play_footstep(delta):
	if velocity.length() > 10.0:
		step_distance += velocity.length() * delta
		if step_distance >= STEP_INTERVAL:
			step_distance = fmod(step_distance, STEP_INTERVAL)
			play_footstep_sound()
	else:
		step_distance = 0.0  # reset ao parar

func play_footstep_sound():
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_step_time < MIN_STEP_GAP:
		return
	last_step_time = now

	SoundManager.play_simple_sound("Player/Steps")

# Funcións necesarias para que o SoundListener do Player siga funcionando cando se introduce na escea

func resync_sound_listener() -> void:
	force_update_transform()
	if is_instance_valid(sound_listener):
		sound_listener.force_update_transform()
	_sync_sound_listener_to_fmod(true)
	call_deferred("_deferred_resync_sound_listener")

func _deferred_resync_sound_listener() -> void:
	force_update_transform()
	if is_instance_valid(sound_listener):
		sound_listener.force_update_transform()
	_sync_sound_listener_to_fmod(true)

func _sync_sound_listener_to_fmod(force: bool = false) -> void:
	if not is_instance_valid(sound_listener):
		return
	if not FmodServer.has_method("set_listener_transform2d"):
		return

	var listener_transform := sound_listener.global_transform
	if not force and _has_synced_sound_listener and listener_transform == _last_sound_listener_transform:
		return

	FmodServer.set_listener_transform2d(_get_sound_listener_index(), listener_transform)
	_last_sound_listener_transform = listener_transform
	_has_synced_sound_listener = true

func _get_sound_listener_index() -> int:
	if not is_instance_valid(sound_listener):
		return 0

	for property in sound_listener.get_property_list():
		var property_name := StringName(property.get("name", ""))
		if property_name == &"listener_index" or property_name == &"listener_number":
			return int(sound_listener.get(property_name))

	return 0
