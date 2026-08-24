extends NPC

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var _hover_anim: AnimatedSprite2D

func _ready():
	super()
	_hover_anim = hover_sprite as AnimatedSprite2D
	animated_sprite.play("idle")


func _process(_delta: float) -> void:
	if _hover_anim.animation != animated_sprite.animation:
		_hover_anim.animation = animated_sprite.animation

	_hover_anim.frame = animated_sprite.frame
	_hover_anim.frame_progress = animated_sprite.frame_progress
