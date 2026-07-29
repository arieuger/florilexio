class_name DialogueSpeaker
extends Marker2D

@export var speaker_id: StringName
@export var balloon_color: Color = Color.WHITE
@export var voice_type: float


func _ready() -> void:
	_validate_speaker_id()
	add_to_group("dialogue_speaker")

func _validate_speaker_id() -> void:
	if speaker_id.is_empty():
		push_warning("DialogueSpeaker ''%s has no speaker_id set. This may cause issues with dialogue."% get_path())
		return

	for node in get_tree().get_nodes_in_group(&"dialogue_speaker"):
		var other := node as DialogueSpeaker
		if not is_instance_valid(other) or other == self:
			continue

		if other.speaker_id == speaker_id:
			push_warning("Duplicate DialogueSpeaker ID '%s': '%s' and '%s'."
				% [speaker_id, other.get_path(), get_path()])
