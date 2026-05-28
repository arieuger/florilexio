extends PointLight2D

@export var min_energy := 0.8
@export var max_energy := 1.3
@export var flicker_speed := 10.0
@export var min_scale := 0.995
@export var max_scale := 1.005

var _time := 0.0

func _process(delta: float) -> void:
	_time += delta * flicker_speed

	var noise := sin(_time) * 0.5 + sin(_time * 2.7) * 0.25
	var t := clampf(0.5 + noise, 0.0, 1.0)

	energy = lerp(min_energy, max_energy, t)
	scale = Vector2.ONE * lerp(min_scale, max_scale, t)
