extends Node2D

@export var visible_at_night := true

func _ready() -> void:
	GameState.reached_night.connect(_on_reached_night)
	_apply_night_state(GameState.consumed_time >= GameState.NIGHT_START_BLOCK)

func _on_reached_night() -> void:
	_apply_night_state(true)

func _apply_night_state(is_night: bool) -> void:
	var should_be_visible := visible_at_night == is_night
	var was_visible := visible

	visible = should_be_visible
	if "enabled" in self:
		set("enabled", should_be_visible)
	else:
		process_mode = Node.PROCESS_MODE_INHERIT if should_be_visible else Node.PROCESS_MODE_DISABLED

	if not was_visible and is_night and visible_at_night and has_node("NightSound"):
		get_node("NightSound").play()
