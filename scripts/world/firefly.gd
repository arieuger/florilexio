extends "res://scripts/interactables/night_changer.gd"

@export var wander_bounds := Rect2(Vector2(35, 85), Vector2(180, 80))
@export var speed := 10.0
@export var target_reached_distance := 2.0
@export var pause_time_range := Vector2(0.15, 0.65)
@export var min_separation := 18.0
@export var separation_strength := 22.0
@export var light_energy_range := Vector2(0.25, 0.85)
@export var light_pulse_speed := 3.0

var _target_position := Vector2.ZERO
var _pause_timer := 0.0
var _pulse_offset := 0.0
var _time := 0.0

@onready var _light: PointLight2D = $PointLight2D

func _ready() -> void:
	super()
	add_to_group("fireflies")
	_pulse_offset = randf() * TAU
	_pick_new_target()

func _process(delta: float) -> void:
	if not visible:
		return

	_time += delta
	_update_light(delta)

	if _pause_timer > 0.0:
		_pause_timer -= delta
		return

	var to_target := _target_position - position
	if to_target.length() <= target_reached_distance:
		_pause_timer = randf_range(pause_time_range.x, pause_time_range.y)
		_pick_new_target()
		return

	var drift := Vector2(
		sin(_time * 6.0 + _pulse_offset),
		cos(_time * 4.0 + _pulse_offset)
	) * 4.0
	var desired_velocity := (to_target.normalized() * speed) + drift + _get_separation_velocity()
	position += desired_velocity * delta

func _get_separation_velocity() -> Vector2:
	var separation := Vector2.ZERO
	for firefly in get_tree().get_nodes_in_group("fireflies"):
		var other := firefly as Node2D
		if other == null or other == self:
			continue

		var offset := global_position - other.global_position
		var distance := offset.length()
		if distance <= 0.0 or distance >= min_separation:
			continue

		var closeness := 1.0 - (distance / min_separation)
		separation += offset.normalized() * closeness

	return separation * separation_strength

func _pick_new_target() -> void:
	_target_position = Vector2(
		randf_range(wander_bounds.position.x, wander_bounds.end.x),
		randf_range(wander_bounds.position.y, wander_bounds.end.y)
	)

func _update_light(delta: float) -> void:
	if _light == null:
		return

	var pulse := (sin(_time * light_pulse_speed + _pulse_offset) + 1.0) * 0.5
	var target_energy: float = lerp(light_energy_range.x, light_energy_range.y, pulse)
	_light.energy = lerp(_light.energy, target_energy, delta * 6.0)
