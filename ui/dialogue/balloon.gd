extends CanvasLayer
## A basic dialogue balloon for use with Dialogue Manager.


## The dialogue resource
@export var dialogue_resource: DialogueResource

## Start from a given title when using balloon as a [Node] in a scene.
@export var start_from_title: String = ""

## If running as a [Node] in a scene then auto start the dialogue.
@export var auto_start: bool = false

## If all other input is blocked as long as dialogue is shown.
@export var will_block_other_input: bool = true

## The action to use for advancing the dialogue
@export var next_action: StringName = &"ui_accept"

## The action to use to skip typing the dialogue
@export var skip_action: StringName = &"ui_cancel"

## Visual mode settings for reusable balloon scenes.
@export var show_character_label := false
@export var show_dialogue_label := true
@export var show_progress_indicator := true
@export var auto_hide_dialogue_label_when_empty := true

## A sound player for voice lines (if they exist).
@onready var audio_stream_player: AudioStreamPlayer = get_node_or_null("%AudioStreamPlayer") as AudioStreamPlayer

@onready var panel_container: PanelContainer = get_node_or_null("Balloon/MarginContainer/PanelContainer") as PanelContainer

## Temporary game states
var temporary_game_states: Array = []

## See if we are waiting for the player
var is_waiting_for_input: bool = false

## See if we are running a long mutation and should hide the balloon
var will_hide_balloon: bool = false

var has_next_line: bool = false

var _current_speaker_id: StringName = &""

## A dictionary to store any ephemeral variables
var locals: Dictionary = {}

var _locale: String = TranslationServer.get_locale()

var _balloon_world_position: Vector2
var _follows_world_position := false

var _letter_count := 0

## The current line
var dialogue_line: DialogueLine:
	set(value):
		if value:
			dialogue_line = value
			apply_dialogue_line()
		else:
			# The dialogue has finished so close the balloon
			if owner == null:
				queue_free()
			else:
				hide()
	get:
		return dialogue_line

## A cooldown timer for delaying the balloon hide when encountering a mutation.
var mutation_cooldown: Timer = Timer.new()

## The base balloon anchor
@onready var balloon: Control = get_node_or_null("%Balloon") as Control

## The label showing the name of the currently speaking character
@onready var character_label: RichTextLabel = get_node_or_null("%CharacterLabel") as RichTextLabel

## The label showing the currently spoken dialogue
@onready var dialogue_label: DialogueLabel = get_node_or_null("%DialogueLabel") as DialogueLabel

## The menu of responses
@onready var responses_menu: DialogueResponsesMenu = get_node_or_null("%ResponsesMenu") as DialogueResponsesMenu

## Indicator to show that player can progress dialogue.
@onready var progress: TextureRect = get_node_or_null("%Progress") as TextureRect


func _ready() -> void:
	balloon.hide()
	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutated)

	# If the responses menu doesn't have a next action set, use this one
	if is_instance_valid(responses_menu) and responses_menu.next_action.is_empty():
		responses_menu.next_action = next_action

	if is_instance_valid(dialogue_label):
		dialogue_label.spoke.connect(_on_dialogue_label_spoke)

	mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(mutation_cooldown)

	if auto_start:
		if not is_instance_valid(dialogue_resource):
			assert(false, DMConstants.get_error_message(DMConstants.ERR_MISSING_RESOURCE_FOR_AUTOSTART))
		start()


func _process(_delta: float) -> void:
	if is_instance_valid(progress):
		progress.visible = show_progress_indicator \
			and is_instance_valid(dialogue_line) \
			and is_instance_valid(dialogue_label) \
			and not dialogue_label.is_typing \
			and dialogue_line.responses.size() == 0 \
			and not dialogue_line.has_tag("voice") \
			and has_next_line

	if _follows_world_position:
		_update_balloon_position()


func _input(event: InputEvent) -> void:
	if not is_instance_valid(balloon) or not balloon.visible:
		return

	if _handle_dialogue_advance_input(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(_event: InputEvent) -> void:
	# Only the balloon is allowed to handle input while it's showing
	if will_block_other_input:
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	## Detect a change of locale and update the current dialogue line to show the new language
	if what == NOTIFICATION_TRANSLATION_CHANGED and _locale != TranslationServer.get_locale() and is_instance_valid(dialogue_label):
		_locale = TranslationServer.get_locale()
		var visible_ratio: float = dialogue_label.visible_ratio
		dialogue_line = await dialogue_resource.get_next_dialogue_line(dialogue_line.id)
		if visible_ratio < 1:
			dialogue_label.skip_typing()


## Start some dialogue
func start(with_dialogue_resource: DialogueResource = null, title: String = "", extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false
	if is_instance_valid(with_dialogue_resource):
		dialogue_resource = with_dialogue_resource
	if not title.is_empty():
		start_from_title = title
	dialogue_line = await dialogue_resource.get_next_dialogue_line(start_from_title, temporary_game_states)
	show()


## Apply any changes to the balloon given a new [DialogueLine].
func apply_dialogue_line() -> void:
	mutation_cooldown.stop()

	if not dialogue_line.character.strip_edges().is_empty():
		DialogueBalloonCoordinator.apply_line_speaker(
			self,
			dialogue_line.character
		)
	_current_speaker_id = DialogueBalloonCoordinator.active_speaker_id
	
	if is_instance_valid(progress):
		progress.hide()
	is_waiting_for_input = false
	if is_instance_valid(balloon):
		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()

	if is_instance_valid(character_label):
		character_label.visible = show_character_label and not dialogue_line.character.is_empty()
		character_label.text = tr(dialogue_line.character, "dialogue")

	if is_instance_valid(dialogue_label):
		dialogue_label.hide()
		if show_dialogue_label and (not dialogue_line.text.is_empty() or not auto_hide_dialogue_label_when_empty):
			dialogue_label.dialogue_line = dialogue_line

	if is_instance_valid(responses_menu):
		responses_menu.hide()
		responses_menu.responses = dialogue_line.responses
		if dialogue_line.responses.size() > 0:
			_preallocate_responses_menu()

	has_next_line = false
	if not dialogue_line.next_id.is_empty():
		has_next_line = await _has_next_line_for_current_balloon(dialogue_line.next_id)

	# Show our balloon
	if is_instance_valid(balloon):
		if _follows_world_position:
			_update_balloon_position()
		balloon.show()
	will_hide_balloon = false

	if is_instance_valid(dialogue_label) and show_dialogue_label and (not dialogue_line.text.is_empty() or not auto_hide_dialogue_label_when_empty):
		dialogue_label.show()

	if is_instance_valid(dialogue_label) and show_dialogue_label and not dialogue_line.text.is_empty():
		dialogue_label.type_out()
		await dialogue_label.finished_typing

	# Wait for next line
	if dialogue_line.has_tag("voice"):
		if is_instance_valid(audio_stream_player):
			audio_stream_player.stream = load(dialogue_line.get_tag_value("voice"))
			audio_stream_player.play()
			await audio_stream_player.finished
		next(dialogue_line.next_id)
	elif dialogue_line.responses.size() > 0:
		if is_instance_valid(balloon):
			balloon.focus_mode = Control.FOCUS_NONE
		if is_instance_valid(responses_menu):
			_show_responses_menu()
	elif dialogue_line.time != "":
		var time: float = dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
		await get_tree().create_timer(time).timeout
		next(dialogue_line.next_id)
	else:
		is_waiting_for_input = true
		if is_instance_valid(balloon):
			balloon.focus_mode = Control.FOCUS_ALL
			balloon.grab_focus()

## Skip internal instructions and only report dialogue assigned to this balloon.
func _has_next_line_for_current_balloon(next_id: String) -> bool:
	var pending_id := next_id
	var visited_ids: Dictionary = {}

	while not pending_id.is_empty() and not visited_ids.has(pending_id):
		visited_ids[pending_id] = true
		var next_line := await DialogueManager.get_line(
			dialogue_resource,
			pending_id,
			temporary_game_states
		) as DialogueLine
		if not is_instance_valid(next_line):
			return false
		if next_line.type == DMConstants.TYPE_DIALOGUE:
			var next_speaker_id := StringName(next_line.character.strip_edges())
			# A missing character inherits the speaker of the preceding line.
			return next_speaker_id.is_empty() or next_speaker_id == _current_speaker_id
		if next_line.type != DMConstants.TYPE_MUTATION:
			return false
		pending_id = next_line.next_id

	return false


## Go to the next line
func next(next_id: String) -> void:
	SoundManager.play_simple_sound("Actions/Next Dialogue")
	dialogue_line = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)


func set_world_presentation() -> void:
	_follows_world_position = true
	show_progress_indicator = true

	if not is_instance_valid(balloon):
		return

	balloon.set_anchors_preset(Control.PRESET_TOP_LEFT)
	balloon.offset_left = 0.0
	balloon.offset_top = 0.0
	balloon.offset_right = 0.0
	balloon.offset_bottom = 0.0

	var margin_container := balloon.get_node_or_null(
		"MarginContainer"
	) as MarginContainer

	if is_instance_valid(margin_container):
		margin_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
		margin_container.offset_left = 0.0
		margin_container.offset_top = 0.0
		margin_container.offset_right = 48.0
		margin_container.offset_bottom = 62.0

	if is_instance_valid(progress):
		var progress_container := progress.get_parent() as Control
		if is_instance_valid(progress_container):
			progress_container.show()


func set_player_presentation() -> void:
	_follows_world_position = false
	show_progress_indicator = false

	if not is_instance_valid(balloon):
		return

	if is_instance_valid(balloon):
		balloon.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		balloon.offset_left = 0.0
		balloon.offset_top = 0.0
		balloon.offset_right = 0.0
		balloon.offset_bottom = 0.0

	var margin_container := balloon.get_node_or_null(
		"MarginContainer"
	) as MarginContainer

	if is_instance_valid(margin_container):
		margin_container.set_anchors_preset(
			Control.PRESET_CENTER_BOTTOM
		)
		margin_container.offset_left = -29.0
		margin_container.offset_top = -32.0
		margin_container.offset_right = 29.0
		margin_container.offset_bottom = 0.0

	if is_instance_valid(progress):
		var progress_container := progress.get_parent() as Control
		if is_instance_valid(progress_container):
			progress_container.hide()

#region Signals


func _on_mutation_cooldown_timeout() -> void:
	if will_hide_balloon:
		will_hide_balloon = false
		if is_instance_valid(balloon):
			balloon.hide()


func _on_mutated(mutation: Dictionary) -> void:
	if not mutation.is_inline:
		is_waiting_for_input = false
		will_hide_balloon = true
		mutation_cooldown.start(0.1)


func _on_balloon_gui_input(event: InputEvent) -> void:
	if _handle_dialogue_advance_input(event):
		get_viewport().set_input_as_handled()


func _on_dialogue_label_spoke(_letter: String, _letter_index: int, _speed: float) -> void:
	_letter_count = _letter_count + 1
	
	if _letter_index <= 0:
		SoundManager.play_simple_sound("NPCs/Voice")
		return

	if _letter.strip_edges().is_empty():
		if (_letter_count > 1):
			SoundManager.play_simple_sound("NPCs/Voice")
		_letter_count = 0
		return

func _handle_dialogue_advance_input(event: InputEvent) -> bool:
	if not is_instance_valid(dialogue_line):
		return false

	var mouse_was_clicked: bool = event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.is_pressed()
	var skip_button_was_pressed: bool = event.is_action_pressed(skip_action)
	var next_button_was_pressed: bool = event.is_action_pressed(next_action)

	if is_instance_valid(dialogue_label) and dialogue_label.is_typing:
		if mouse_was_clicked or skip_button_was_pressed:
			dialogue_label.skip_typing()
			return true
		return false

	if not is_waiting_for_input:
		return false
	if dialogue_line.responses.size() > 0:
		return false

	if mouse_was_clicked or next_button_was_pressed:
		next(dialogue_line.next_id)
		return true

	return false


func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	next(response.next_id)

func _preallocate_responses_menu() -> void:
	responses_menu.show()
	responses_menu.modulate.a = 0.0
	responses_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_response_items_disabled(true)
	if is_instance_valid(balloon):
		balloon.grab_focus()

func _show_responses_menu() -> void:
	responses_menu.show()
	responses_menu.modulate.a = 1.0
	responses_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_response_items_disabled(false)
	_focus_first_response()

func _set_response_items_disabled(disabled: bool) -> void:
	for item: Control in responses_menu.get_menu_items():
		if "disabled" in item:
			item.disabled = disabled
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE if disabled else Control.MOUSE_FILTER_STOP

func _focus_first_response() -> void:
	var items := responses_menu.get_menu_items()
	if items.size() > 0:
		items[0].grab_focus()

func set_balloon_world_position(world_position: Vector2) -> void:
	_balloon_world_position = world_position
	_follows_world_position = true
	_update_balloon_position()

func _update_balloon_position() -> void:
	if not is_instance_valid(balloon):
		return
	var screen_position := get_viewport().get_canvas_transform() * _balloon_world_position
	var margin_container := balloon.get_node_or_null("MarginContainer") as MarginContainer
	if is_instance_valid(margin_container):
		margin_container.position = screen_position

func set_balloon_color(color: Color) -> void:
	if not is_instance_valid(panel_container):
		return
	var stylebox := panel_container.get_theme_stylebox("panel")
	if stylebox is StyleBoxTexture:
		var unique_stylebox := stylebox.duplicate()
		unique_stylebox.modulate_color = color
		panel_container.add_theme_stylebox_override("panel", unique_stylebox)


#endregion
