extends Node2D

@export var visible_at_night := true

func _ready():
	GameState.reached_night.connect(_on_reached_night)
	if GameState.consumed_time >= GameState.NIGHT_START_BLOCK:
		_on_reached_night()

func _on_reached_night():
	visible = visible_at_night
	process_mode = Node.PROCESS_MODE_INHERIT if visible_at_night \
		else Node.PROCESS_MODE_DISABLED
