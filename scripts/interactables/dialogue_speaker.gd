extends Marker2D

@export var speaker_id: StringName
@export var balloon_color: Color = Color.WHITE
@export var balloon_scene: PackedScene
@export var voice_type: float


func _ready() -> void:
	add_to_group("dialogue_speaker")
