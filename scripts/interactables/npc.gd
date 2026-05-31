extends Node2D

@export var dialogue_resource: DialogueResource
@export var dialogue_title := "start"
@export var hover_color: Color = Color(1.0, 0.9, 0.35, 0.75)
@export var hover_fade_duration: float = 0.18
@export var requires_wind_already_spoke := false

@onready var hover_sprite: Sprite2D = $HoverSprite
@onready var click_area: Area2D = $ClickArea
@onready var interaction_point: Node2D = $InteractionPoint
@onready var balloon_marker: Marker2D = $BalloonConfig

var _hover_tween: Tween
var _is_interacting := false

func _ready():
	_make_hover_ignore_world_tint()
	hover_sprite.modulate = Color(hover_color.r, hover_color.g, hover_color.b, 0.0)
	_update_availability()
	if requires_wind_already_spoke:
		GameState.wind_already_spoke_changed.connect(_on_wind_already_spoke_changed)
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)
	click_area.input_event.connect(_on_input_event)

func _on_mouse_entered():
	if not _is_available():
		return

	SoundManager.play_simple_sound("Actions/Hover")
	_fade_hover_to(hover_color.a)

func _on_mouse_exited():
	_fade_hover_to(0.0)

func _on_input_event(viewport, event, _shape_idx):
	if not _is_available():
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		viewport.set_input_as_handled()
		_interact()

func _interact():
	if _is_interacting or not _is_available():
		return
	
	_is_interacting = true

	SoundManager.play_simple_sound("Actions/Click")
	
	if interaction_point:
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("move_to_point"):
			var stop_distance: float = player.interaction_stop_distance if "interaction_stop_distance" in player else 6.0
			var reached: bool = await player.move_to_point(interaction_point.global_position, stop_distance)
			if not reached:
				_is_interacting = false
				return

	await DialogueBalloonCoordinator.run_world_sequence(
		dialogue_resource,
		dialogue_title,
		balloon_marker.global_position,
		_get_balloon_color(),
		_get_voice_type(),
		[self],
		_get_balloon_scene()
	)

	_is_interacting = false

func _on_wind_already_spoke_changed(_has_spoken: bool) -> void:
	_update_availability()

func _is_available() -> bool:
	return not requires_wind_already_spoke or GameState.wind_already_spoke

func _update_availability() -> void:
	var available := _is_available()
	visible = available
	click_area.input_pickable = available
	click_area.monitoring = available
	click_area.monitorable = available

	if not available:
		_fade_hover_to(0.0)

func _get_balloon_color() -> Color:
	if "balloon_color" in balloon_marker:
		var marker_color: Color = balloon_marker.get("balloon_color")
		return marker_color
	return Color.WHITE
	
func _get_voice_type() -> float:
	if "voice_type" in balloon_marker:
		var voice_type: float = balloon_marker.get("voice_type")
		return voice_type
	return 0.0

func _get_balloon_scene() -> PackedScene:
	if "balloon_scene" in balloon_marker:
		return balloon_marker.get("balloon_scene") as PackedScene
	return null

func _fade_hover_to(target_alpha: float):
	if _hover_tween:
		_hover_tween.kill()
	
	_hover_tween = create_tween()
	_hover_tween.tween_property(hover_sprite, "modulate:a", target_alpha, hover_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	
func _make_hover_ignore_world_tint() -> void:
	var hover_material := CanvasItemMaterial.new()
	hover_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	hover_sprite.material = hover_material
