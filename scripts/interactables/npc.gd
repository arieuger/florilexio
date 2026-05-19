extends Node2D

@export var dialogue_resource: DialogueResource
@export var hover_color: Color = Color(1.0, 0.9, 0.35, 0.75)
@export var hover_fade_duration: float = 0.18

@onready var hover_sprite: Sprite2D = $HoverSprite
@onready var click_area: Area2D = $ClickArea

var _hover_tween: Tween

func _ready():
	hover_sprite.modulate = Color(hover_color.r, hover_color.g, hover_color.b, 0.0)
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)
	click_area.input_event.connect(_on_input_event)

func _on_mouse_entered():
	_fade_hover_to(hover_color.a)

func _on_mouse_exited():
	_fade_hover_to(0.0)

func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		DialogueManager.show_dialogue_balloon(dialogue_resource)

func _fade_hover_to(target_alpha: float):
	if _hover_tween:
		_hover_tween.kill()
	
	_hover_tween = create_tween()
	_hover_tween.tween_property(hover_sprite, "modulate:a", target_alpha, hover_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	
