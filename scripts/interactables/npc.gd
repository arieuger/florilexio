extends Node2D

@export var dialogue_resource: DialogueResource
@export var hover_color: Color = Color(1.0, 0.9, 0.35, 0.75)
@export var hover_fade_duration: float = 0.18
@export var balloon_scene: PackedScene
@export var balloon_color: Color = Color.WHITE

@onready var hover_sprite: Sprite2D = $HoverSprite
@onready var click_area: Area2D = $ClickArea
@onready var interaction_point: Node2D = $InteractionPoint
@onready var balloon_marker: Marker2D = $BalloonPosition

var _hover_tween: Tween
var _is_interacting := false

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
		viewport.set_input_as_handled()
		_interact()

func _interact():
	if _is_interacting:
		return

	_is_interacting = true

	if interaction_point:
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("move_to_point"):
			var reached: bool = await player.move_to_point(interaction_point.global_position)
			if not reached:
				_is_interacting = false
				return

	var balloon = DialogueManager.show_dialogue_balloon_scene(balloon_scene, dialogue_resource)
	await get_tree().process_frame
	balloon.set_balloon_color(balloon_color)
	balloon.set_balloon_world_position(balloon_marker.global_position)

	_is_interacting = false

func _fade_hover_to(target_alpha: float):
	if _hover_tween:
		_hover_tween.kill()
	
	_hover_tween = create_tween()
	_hover_tween.tween_property(hover_sprite, "modulate:a", target_alpha, hover_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	
