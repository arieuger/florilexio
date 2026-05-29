# surface_zone.gd
extends Area2D

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		print("Dentro da herba")
		SoundManager.set_global_parameter("GroundType", 1.0)

func _on_body_exited(body):
	if body.is_in_group("player"):
		print("Fora da herba")
		SoundManager.set_global_parameter("GroundType", 0.0)
