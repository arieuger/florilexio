class_name NPC
extends Node2D

@export var dialogue_profile: DialogueProfile
@export var hover_color: Color = Color(1.0, 0.9, 0.35, 0.75)
@export var hover_fade_duration: float = 0.18
@export var required_finished_conversation_id: StringName

@onready var hover_sprite: CanvasItem = $HoverSprite
@onready var click_area: Area2D = $ClickArea
@onready var interaction_point: Node2D = $InteractionPoint
@onready var time_warn_sprite: Sprite2D = $TimeWarn

var _time_warn_base_y: float
var _hover_tween: Tween
var _time_warn_tween: Tween
var _is_interacting := false

func _ready():
	_time_warn_base_y = time_warn_sprite.position.y
	_make_hover_ignore_world_tint()
	hover_sprite.modulate = Color(hover_color.r, hover_color.g, hover_color.b, 0.0)
	_update_availability()
	if not required_finished_conversation_id.is_empty():
		ConversationHistory.history_changed.connect(_on_conversation_history_changed)
		ConversationHistory.history_reloaded.connect(_on_conversation_history_reloaded)
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)
	click_area.input_event.connect(_on_input_event)

func _on_mouse_entered():
	if _is_interacting or not _is_available():
		return false

	var entries := _resolve_entries()
	if entries.is_empty():
		return

	var has_time_cost := entries.any(func(entry: ConversationEntry) -> bool:
		return entry.conversation.time_cost_blocks > 0.0
	)

	SoundManager.play_simple_sound("Actions/Hover")
	_fade_tweens_to(hover_color.a, has_time_cost)

func _on_mouse_exited():
	_fade_tweens_to(0.0)

func _on_input_event(viewport, event, _shape_idx):
	if not _can_interact():
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		viewport.set_input_as_handled()
		_interact()

func _interact() -> void:
	if not _can_interact():
		return

	_is_interacting = true
	_fade_tweens_to(0.0)
	SoundManager.play_simple_sound("Actions/Click")

	if interaction_point:
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("move_to_point"):
			var stop_distance: float = (
				player.interaction_stop_distance
				if "interaction_stop_distance" in player
				else 6.0
			)
			var reached: bool = await player.move_to_point(interaction_point.global_position, stop_distance)
			if not reached:
				_finish_interaction()
				return

	var entries := _resolve_entries()
	if entries.is_empty():
		push_warning("NPC '%s' has no available conversation entries." % name)
		_finish_interaction()
		return

	var selected_entry := await _select_entry(entries)
	if selected_entry == null:
		_finish_interaction()
		return

	var finished := await DialogueBalloonCoordinator.play(selected_entry.conversation, [self])

	if finished:
		_on_conversation_finished(selected_entry.conversation.conversation_id)

	_finish_interaction()


func _finish_interaction() -> void:
	_is_interacting = false
	_fade_tweens_to(0.0)

## Para clases herdadas, según necesidade específica
func _on_conversation_finished(_conversation_id: StringName) -> void:
	pass


func _is_available() -> bool:
	return required_finished_conversation_id.is_empty() or ConversationHistory.has_finished(required_finished_conversation_id)

func _update_availability() -> void:
	var available := _is_available()

	visible = available
	click_area.input_pickable = available
	click_area.monitoring = available
	click_area.monitorable = available

	if not available:
		_fade_tweens_to(0.0)


func _can_interact() -> bool:
	if _is_interacting or not _is_available():
		return false

	return not _resolve_entries().is_empty()
		

func _fade_tweens_to(target_alpha: float, show_time_warning := false) -> void:
	if _hover_tween:
		_hover_tween.kill()

	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(hover_sprite, "modulate:a", target_alpha, hover_fade_duration)
	
	if _time_warn_tween:
		_time_warn_tween.kill()

	if show_time_warning and target_alpha > 0.0:
		_time_warn_tween = UITweens.pop_tween(time_warn_sprite, _time_warn_base_y)
	else:
		_time_warn_tween = UITweens.hide_tween(time_warn_sprite)


func _make_hover_ignore_world_tint() -> void:
	var hover_material := CanvasItemMaterial.new()
	hover_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	hover_sprite.material = hover_material
	time_warn_sprite.material = hover_material


func _resolve_entries() -> Array[ConversationEntry]:
	if dialogue_profile == null:
		return []

	var context := ConversationContext.create(self, get_tree().current_scene)
	return ConversationResolver.resolve_entries(dialogue_profile, context)


func _resolve_conversation() -> ConversationDefinition:
	if dialogue_profile == null:
		return null

	var context := ConversationContext.create(self, get_tree().current_scene)
	return ConversationResolver.resolve(dialogue_profile, context)

func _on_conversation_history_changed(
	conversation_id: StringName
) -> void:
	if conversation_id == required_finished_conversation_id:
		_update_availability()


func _on_conversation_history_reloaded() -> void:
	_update_availability()


func _select_entry(entries: Array[ConversationEntry]) -> ConversationEntry:
	if entries.is_empty():
		return null

	if entries.size() == 1:
		return entries[0]

	var first_mode := entries[0].interaction_mode

	for entry in entries:
		if entry.interaction_mode != first_mode:
			push_warning("NPC '%s' has conversation entries with mixed interaction modes. " % name)
			return entries[0]

	if first_mode == ConversationEntry.InteractionMode.DIRECT:
		push_warning("NPC '%s' Multiple DIRECT conversations share priority. " % name)
		return entries[0]
	
	var options := PackedStringArray()
	for entry in entries:
		options.append(entry.selection_text)
	
	var selected_index: int = await DialogueBalloonCoordinator.choose_player_option(options)
	if selected_index < 0 or selected_index >= entries.size():
		return null

	return entries[selected_index]