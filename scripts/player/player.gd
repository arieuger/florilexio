extends CharacterBody2D

@export var max_speed := 60.0
@export var acceleration := 420.0
@export var deceleration := 520.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _last_facing := "down"

func _physics_process(delta: float):
    var input_direction := Input.get_vector("left", "right", "up", "down")
    var target_velocity := input_direction * max_speed  
    if input_direction != Vector2.ZERO:
        velocity = velocity.move_toward(target_velocity, acceleration * delta)
    else:
        velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)

    move_and_slide()

    if input_direction == Vector2.ZERO:
        animated_sprite.play("idle_" + _last_facing)
    elif input_direction.y < 0:
        _last_facing = "up"
        animated_sprite.play("walk_up")
    else:
        _last_facing = "down"
        animated_sprite.play("walk_down")
