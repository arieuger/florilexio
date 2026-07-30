extends Node

signal conversation_started(conversation_id: StringName)
signal conversation_finished(conversation_id: StringName)
signal conversation_interrupted(conversation_id: StringName, reason: StringName)

signal _active_conversation_resolved

const DEFAULT_CONVERSATION_BALLOON_SCENE: PackedScene = preload("res://ui/dialogue/conversation_balloon.tscn")
const DEFAULT_INFO_BALLOON_SCENE: PackedScene = preload("res://ui/dialogue/generic_info_balloon.tscn")
const GENERAL_INFO_DIALOGUE : DialogueResource = preload("res://dialogues/info.dialogue")

var is_running := false
var active_conversation: ConversationDefinition
var active_speaker_id: StringName = &""
var active_balloon: Node
var _current_info_balloon: GenericInfoBalloon

var _active_dialogue_resource: DialogueResource
var _active_session_resolved := false
var _active_session_finished := false
var _active_interruption_reason: StringName = &""

func _ready() -> void:
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

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

	var initial_speaker := _get_dialogue_speaker(conversation.initial_speaker_id)
	if not is_instance_valid(initial_speaker):
		push_warning("DialogueBalloonCoordinator: initial speaker '%s' in conversation ''%s was not found."
			% [conversation.initial_speaker_id, conversation.conversation_id])
		return false

	is_running = true
	active_conversation = conversation
	active_speaker_id = conversation.initial_speaker_id
	_active_dialogue_resource = conversation.dialogue_resource
	_active_session_resolved = false
	_active_session_finished = false
	_active_interruption_reason = &""

	active_balloon = DialogueManager.show_dialogue_balloon_scene(
		DEFAULT_CONVERSATION_BALLOON_SCENE,
		conversation.dialogue_resource,
		conversation.start_title,
		[self] + extra_game_states
	)

	if not is_instance_valid(active_balloon):
		var failed_conversation_id := conversation.conversation_id
		_clear_active_conversation()
		conversation_interrupted.emit(failed_conversation_id, &"balloon_failed")
		return false

	active_balloon.tree_exited.connect(_on_active_balloon_tree_exited, CONNECT_ONE_SHOT)

	conversation_started.emit(conversation.conversation_id)
	await _prepare_initial_speaker_balloon(active_balloon, conversation.initial_speaker_id)

	if not _active_session_resolved:
		await _active_conversation_resolved

	var resolved_conversation_id := conversation.conversation_id
	var resolved_start_title := StringName(conversation.start_title)
	var finished_normally := _active_session_finished
	var interruption_reason := _active_interruption_reason

	_clear_active_conversation()

	if finished_normally:
		conversation_finished.emit(resolved_conversation_id)
		GameplayEvents.report_dialogue_completed(resolved_conversation_id, resolved_start_title)
	else:
		conversation_interrupted.emit(resolved_conversation_id, interruption_reason)

	return finished_normally

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


func resolve_line_speaker(character: String) -> DialogueSpeaker:
	var requested_speaker_id := StringName(character.strip_edges())

	if not requested_speaker_id.is_empty():
		active_speaker_id = requested_speaker_id

	if active_speaker_id.is_empty() and is_instance_valid(active_conversation):
		active_speaker_id = active_conversation.initial_speaker_id

	if active_speaker_id.is_empty():
		return null

	return _get_dialogue_speaker(active_speaker_id)


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

	if balloon.has_method("set_balloon_color"):
		balloon.set_balloon_color(speaker.balloon_color)

	SoundManager.set_global_parameter("VoiceType", speaker.voice_type)

	return true


func interrupt_active_conversation(reason: StringName = &"cancelled") -> bool:
	if not is_running:
		return false

	var balloon_to_close := active_balloon

	_resolve_active_session(false, reason)

	if is_instance_valid(balloon_to_close):
		balloon_to_close.queue_free()

	return true


func _apply_info_replacements(message: String, replacements: Dictionary) -> String:
	var resolved_message := message
	for key in replacements.keys():
		resolved_message = resolved_message.replace("{" + str(key) + "}", str(replacements[key]))
	return resolved_message



func _prepare_initial_speaker_balloon(balloon: Node, speaker_id: StringName) -> void:
	var speaker := _get_dialogue_speaker(speaker_id)
	if not is_instance_valid(speaker):
		push_warning("DialogueBalloonCoordinator: initial speaker '%s' was not found."% speaker_id)
		SoundManager.set_global_parameter("VoiceType", 0.0)
		await _prepare_world_balloon(balloon, Vector2.ZERO, Color.WHITE)
		return

	SoundManager.set_global_parameter("VoiceType", speaker.voice_type)
	await _prepare_world_balloon(balloon, speaker.global_position, speaker.balloon_color)


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


func _get_dialogue_speaker(speaker_id: StringName) -> DialogueSpeaker:
	if speaker_id.is_empty():
		return null

	for node in get_tree().get_nodes_in_group("dialogue_speaker"):
		var speaker := node as DialogueSpeaker
		if not is_instance_valid(speaker):
			continue

		if speaker.speaker_id == speaker_id:
			return speaker

	return null


func _wait_for_dialogue_to_end(dialogue_resource: DialogueResource) -> void:
	while true:
		var ended_resource: DialogueResource = await DialogueManager.dialogue_ended
		if ended_resource == dialogue_resource:
			return

func _clear_active_conversation() -> void:
	if is_instance_valid(active_balloon):
		if active_balloon.tree_exited.is_connected(_on_active_balloon_tree_exited):
			active_balloon.tree_exited.disconnect(_on_active_balloon_tree_exited)

	active_balloon = null
	active_conversation = null
	active_speaker_id = &""
	_active_dialogue_resource = null
	_active_session_resolved = false
	_active_session_finished = false
	_active_interruption_reason = &""
	is_running = false

func _on_dialogue_ended(dialogue_resource: DialogueResource) -> void:
	if not is_running:
		return

	if dialogue_resource != _active_dialogue_resource:
		return

	_resolve_active_session(true)

func _on_active_balloon_tree_exited() -> void:
	if not is_running:
		return

	_resolve_active_session(false,&"balloon_exited")

func _resolve_active_session(finished: bool, interruption_reason: StringName = &"") -> void:
	if not is_running or _active_session_resolved:
		return

	_active_session_resolved = true
	_active_session_finished = finished
	_active_interruption_reason = interruption_reason
	_active_conversation_resolved.emit()