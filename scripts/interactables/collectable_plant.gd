extends Node2D
class_name CollectablePlant

signal plant_selected(plant: CollectablePlant)
signal cutting_minigame_requested(plant_id: StringName, plant: CollectablePlant)

## Identifies the plant type/species. Multiple CollectablePlant instances can share it.
@export var plant_id: StringName
@export var plant_display_name: String
@export var hover_color: Color = Color(1.0, 1.0, 1.0, 0.75)
@export var hover_fade_duration: float = 0.18
@export var time_cost_blocks: int = 1

@onready var hover_sprite: Sprite2D = $HoverSprite
@onready var click_area: Area2D = $ClickArea
@onready var interaction_point: Marker2D = get_node_or_null("InteractionPoint")

var _hover_tween: Tween
var _is_interacting := false


func _ready() -> void:
	hover_sprite.modulate = Color(hover_color.r, hover_color.g, hover_color.b, 0.0)
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)
	click_area.input_event.connect(_on_input_event)


func _on_mouse_entered() -> void:
	_fade_hover_to(hover_color.a)


func _on_mouse_exited() -> void:
	_fade_hover_to(0.0)


func _on_input_event(viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		viewport.set_input_as_handled()
		_interact()


func _interact() -> void:
	if _is_interacting:
		return

	_is_interacting = true

	if interaction_point:
		var player := get_tree().get_first_node_in_group("player")
		if player and player.has_method("move_to_point"):
			var reached: bool = await player.move_to_point(interaction_point.global_position)
			if not reached:
				_is_interacting = false
				return

	start_cutting_minigame()
	_is_interacting = false


func start_cutting_minigame() -> void:
	plant_selected.emit(self)
	cutting_minigame_requested.emit(plant_id, self)
	print("Cutting minigame requested for: ", plant_id)


func _fade_hover_to(target_alpha: float) -> void:
	if _hover_tween:
		_hover_tween.kill()

	_hover_tween = create_tween()
	_hover_tween.tween_property(hover_sprite, "modulate:a", target_alpha, hover_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
