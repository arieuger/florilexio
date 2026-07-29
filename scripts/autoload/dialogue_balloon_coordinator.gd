extends Node

const DEFAULT_CONVERSATION_BALLOON_SCENE: PackedScene = preload("res://ui/dialogue/conversation_balloon.tscn")
const DEFAULT_INFO_BALLOON_SCENE: PackedScene = preload("res://ui/dialogue/generic_info_balloon.tscn")
const GENERAL_INFO_DIALOGUE : DialogueResource = preload("res://dialogues/info.dialogue")

var is_running := false
var active_conversation: ConversationDefinition
var active_speaker_id: StringName = &""
var _current_info_balloon: GenericInfoBalloon


func play(conversation: ConversationDefinition, extra_game_states: Array = []) -> bool:
	if is_running:
		return false

	if not is_instance_valid(conversation):
		push_warning("DialogueBalloonCoordinator: missing conversation_definition.")
		return false
	
	if conversation.conversation_id.is_empty():
		push_warning("DialogueBalloonCoordinator: conversation_definition must have a valid conversation_id.")
		return false

	if not is_instance_valid(conversation.dialogue_resource):
		push_warning("DialogueBalloonCoordinator: missing dialogue_resource in conversation_definition.")
		return false

	if conversation.initial_speaker_id.is_empty():
		push_warning("DialogueBalloonCoordinator: conversation_definition must have a valid initial_speaker_id.")
		return false

	is_running = true
	active_conversation = conversation
	active_speaker_id = conversation.initial_speaker_id

	var balloon := DialogueManager.show_dialogue_balloon_scene(
		DEFAULT_CONVERSATION_BALLOON_SCENE,
		conversation.dialogue_resource,
		conversation.start_title,
		[self] + extra_game_states
	)

	await _prepare_initial_speaker_balloon(balloon, conversation.initial_speaker_id)
	await _wait_for_dialogue_to_end(conversation.dialogue_resource)

	
	active_conversation = null
	active_speaker_id = &""
	is_running = false
	return true

func show_info_dialogue(
	dialogue_title: String,
	replacements: Dictionary = {},
	duration: float = -1.0,
	extra_game_states: Array = []
) -> bool:
	if not is_instance_valid(GENERAL_INFO_DIALOGUE):
		push_warning("DialogueBalloonCoordinator: missing info dialogue_resource.")
		return false

	var dialogue_states := [self] + extra_game_states
	var line: DialogueLine = await GENERAL_INFO_DIALOGUE.get_next_dialogue_line(dialogue_title, dialogue_states)
	if not is_instance_valid(line):
		return false

	var message := _apply_info_replacements(line.text, replacements)
	if is_instance_valid(_current_info_balloon):
		_current_info_balloon.queue_free()

	var balloon := DEFAULT_INFO_BALLOON_SCENE.instantiate() as GenericInfoBalloon
	if not balloon:
		push_warning("DialogueBalloonCoordinator: DEFAULT_INFO_BALLOON_SCENE must instantiate a GenericInfoBalloon.")
		return false

	_current_info_balloon = balloon
	get_tree().current_scene.add_child(balloon)
	balloon.show_message(message, duration)
	return true


func show_info_dialogue_and_wait(
	dialogue_title: String,
	replacements: Dictionary = {},
	extra_game_states: Array = []
) -> bool:
	if not is_instance_valid(GENERAL_INFO_DIALOGUE):
		push_warning("DialogueBalloonCoordinator: missing info dialogue_resource.")
		return false

	if is_instance_valid(_current_info_balloon):
		_current_info_balloon.queue_free()

	var balloon := DialogueManager.show_dialogue_balloon_scene(
		DEFAULT_INFO_BALLOON_SCENE,
		GENERAL_INFO_DIALOGUE,
		dialogue_title,
		[self] + extra_game_states
	) as GenericInfoBalloon
	if is_instance_valid(balloon):
		_current_info_balloon = balloon
		balloon.replacements = replacements

	await _wait_for_dialogue_to_end(GENERAL_INFO_DIALOGUE)
	return true


func resolve_line_speaker(character: String) -> Node2D:
	var requested_speaker_id := StringName(character.strip_edges())

	if not requested_speaker_id.is_empty():
		active_speaker_id = requested_speaker_id

	if active_speaker_id.is_empty() and is_instance_valid(active_conversation):
		active_speaker_id = active_conversation.initial_speaker_id

	if active_speaker_id.is_empty():
		return null

	return _get_dialogue_speaker(str(active_speaker_id))


func apply_line_speaker(balloon: Node, character: String) -> bool:
	var requested_speaker_id := StringName(character.strip_edges())

	if requested_speaker_id == &"player":
		active_speaker_id = &"player"

		if balloon.has_method("set_player_presentation"):
			balloon.set_player_presentation()

		if balloon.has_method("set_balloon_color"):
			balloon.set_balloon_color(Color.WHITE)

		SoundManager.set_global_parameter("VoiceType", 0.0)
		
		return true

	if balloon.has_method("set_world_presentation"):
		balloon.set_world_presentation()

	var speaker := resolve_line_speaker(character)
	if not is_instance_valid(speaker):
		push_warning("DialogueBalloonCoordinator: could not find a valid dialogue speaker for character: " + character)
		return false

	if balloon.has_method("set_balloon_world_position"):
		balloon.set_balloon_world_position(speaker.global_position)

	if balloon.has_method("set_balloon_color") and "balloon_color" in speaker:
		var speaker_color: Color = speaker.get("balloon_color")
		balloon.set_balloon_color(speaker_color)

	if "voice_type" in speaker:
		var voice_type_value: float = speaker.get("voice_type")
		SoundManager.set_global_parameter("VoiceType", voice_type_value)

	return true


func _apply_info_replacements(message: String, replacements: Dictionary) -> String:
	var resolved_message := message
	for key in replacements.keys():
		resolved_message = resolved_message.replace("{" + str(key) + "}", str(replacements[key]))
	return resolved_message



func _prepare_initial_speaker_balloon(balloon: Node, speaker_id: StringName) -> void:
	var speaker := _get_dialogue_speaker(str(speaker_id))
	if not is_instance_valid(speaker):
		push_warning("DialogueBalloonCoordinator: initial speaker '%s' was not found."% speaker_id)
		SoundManager.set_global_parameter("VoiceType", 0.0)
		await _prepare_world_balloon(balloon, Vector2.ZERO, Color.WHITE)
		return

	var speaker_color: Color = speaker.get("balloon_color")
	var voice_type_value = speaker.get("voice_type")

	if voice_type_value is float:
		SoundManager.set_global_parameter("VoiceType", voice_type_value)

	await _prepare_world_balloon(balloon, speaker.global_position, speaker_color)


func _prepare_world_balloon(balloon: Node, world_position: Vector2, balloon_color: Color) -> void:
	if is_instance_valid(balloon) and "visible" in balloon:
		balloon.visible = false
	if is_instance_valid(balloon) and balloon.has_method("set_balloon_world_position"):
		balloon.set_balloon_world_position(world_position)

	await get_tree().process_frame

	if not is_instance_valid(balloon):
		return

	if balloon.has_method("set_world_presentation"):
		balloon.set_world_presentation()

	if balloon.has_method("set_balloon_color"):
		balloon.set_balloon_color(balloon_color)

	if balloon.has_method("set_balloon_world_position"):
		balloon.set_balloon_world_position(world_position)

	if "visible" in balloon:
		balloon.visible = true


func _get_dialogue_speaker(speaker_id: String) -> Node2D:
	if speaker_id.is_empty():
		return null
	for speaker in get_tree().get_nodes_in_group("dialogue_speaker"):
		if str(speaker.get("speaker_id")) == speaker_id:
			return speaker as Node2D
	return null


func _wait_for_dialogue_to_end(dialogue_resource: DialogueResource) -> void:
	while true:
		var ended_resource: DialogueResource = await DialogueManager.dialogue_ended
		if ended_resource == dialogue_resource:
			return