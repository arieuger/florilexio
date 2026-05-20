extends Node2D

@export var dialogue_resource: DialogueResource
@export var dialogue_title := "start"
@export var hover_color: Color = Color(1.0, 0.9, 0.35, 0.75)
@export var hover_fade_duration: float = 0.18

@onready var hover_sprite: Sprite2D = $HoverSprite
@onready var click_area: Area2D = $ClickArea
@onready var interaction_point: Node2D = $InteractionPoint
@onready var balloon_marker: Marker2D = $BalloonConfig

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

	await DialogueBalloonCoordinator.run_world_sequence(
		dialogue_resource,
		dialogue_title,
		balloon_marker.global_position,
		_get_balloon_color(),
		[self],
		_get_balloon_scene()
	)

	_is_interacting = false

func _get_balloon_color() -> Color:
	if "balloon_color" in balloon_marker:
		var marker_color: Color = balloon_marker.get("balloon_color")
		return marker_color
	return Color.WHITE

func _get_balloon_scene() -> PackedScene:
	if "balloon_scene" in balloon_marker:
		return balloon_marker.get("balloon_scene") as PackedScene
	return null

func _fade_hover_to(target_alpha: float):
	if _hover_tween:
		_hover_tween.kill()
	
	_hover_tween = create_tween()
	_hover_tween.tween_property(hover_sprite, "modulate:a", target_alpha, hover_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	
