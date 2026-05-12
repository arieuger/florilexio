extends CharacterBody2D

var speed = 400.0

func _physics_process(delta: float) -> void:
    var input_direction = Input.get_vector("left", "right", "up", "down")
    velocity = input_direction.normalized() * speed
    move_and_slide()


