extends CharacterBody2D

signal auto_move_finished(reached: bool)

@export var max_speed := 60.0
@export var acceleration := 420.0
@export var deceleration := 520.0
@export var auto_move_stop_distance := 2.0
@export var auto_move_timeout := 5.0
@export var auto_move_stuck_distance := 0.1
@export var auto_move_stuck_time := 0.25

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _last_facing := "down"
var _auto_move_target := Vector2.ZERO
var _auto_move_elapsed := 0.0
var _auto_move_stuck_elapsed := 0.0
var _auto_move_previous_distance := INF
var _is_auto_moving := false

func _ready():
	add_to_group("player")

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		start_auto_move(get_global_mouse_position())

func _physics_process(delta: float):
	var input_direction := Input.get_vector("left", "right", "up", "down")

	if _is_auto_moving and input_direction != Vector2.ZERO:
		_finish_auto_move(false)

	if _is_auto_moving:
		_process_auto_move(delta)
	else:
		_process_player_input(delta, input_direction)

	move_and_slide()

	if _is_auto_moving:
		_check_auto_move_stuck(delta)

func move_to_point(global_target: Vector2) -> bool:
	if global_position.distance_to(global_target) <= auto_move_stop_distance:
		return true

	start_auto_move(global_target)
	return await auto_move_finished

func start_auto_move(global_target: Vector2):
	if _is_auto_moving:
		_finish_auto_move(false)		

	_auto_move_target = global_target
	_auto_move_elapsed = 0.0
	_auto_move_stuck_elapsed = 0.0
	_auto_move_previous_distance = global_position.distance_to(_auto_move_target)
	_is_auto_moving = true

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

	var target_offset := _auto_move_target - global_position
	if target_offset.length() <= auto_move_stop_distance:
		_finish_auto_move(true)
		return

	if _auto_move_elapsed >= auto_move_timeout:
		_finish_auto_move(false)
		return

	var move_direction := target_offset.normalized()
	velocity = velocity.move_toward(move_direction * max_speed, acceleration * delta)
	play_footstep(delta)
	_update_animation(move_direction)

func _finish_auto_move(reached: bool):
	_is_auto_moving = false
	velocity = Vector2.ZERO
	_update_animation(Vector2.ZERO)
	auto_move_finished.emit(reached)

func _check_auto_move_stuck(delta: float):
	var current_distance := global_position.distance_to(_auto_move_target)
	var progress := _auto_move_previous_distance - current_distance

	if progress <= auto_move_stuck_distance:
		_auto_move_stuck_elapsed += delta
	else:
		_auto_move_stuck_elapsed = 0.0

	_auto_move_previous_distance = current_distance

	if _auto_move_stuck_elapsed >= auto_move_stuck_time:
		_finish_auto_move(false)

func _update_animation(direction: Vector2):
	if direction == Vector2.ZERO:
		animated_sprite.play("idle_" + _last_facing)
	elif direction.y < 0:
		_last_facing = "up"
		animated_sprite.play("walk_up")
	else:
		_last_facing = "down"
		animated_sprite.play("walk_down")

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

	SoundManager.set_global_parameter("GroundType", 0.0)
	SoundManager.play_simple_sound("Player/Steps")
