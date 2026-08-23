extends Node2D
class_name CollectablePlant

@export_group("Plant data")
@export var plant_data: PlantData

@export_subgroup("Instance overrides")
@export var override_collection_requirements := false
@export var collection_requirements_override: Array[StringName] = []

@export_group("")

## Optional stable id for this exact plant instance. Empty ids are derived from the area scene and node path.
@export var collection_id: StringName
@export var hover_color: Color = Color(1.0, 1.0, 1.0, 0.75)
@export var hover_fade_duration: float = 0.18


@export_group("Collection Minigame")
@export var collection_minigame_config: MinigameConfig = preload("res://resources/minigames/cutting_minigame_config.tres")
## Si queremos parametrizar específicamente unha planta, creamos un "new tuning resource" do tipo de minixogo que sexa dende o inspector. NUNCA MODIFICAR O RESOURCE BASE
@export var collection_minigame_tuning: MinigameTuning = preload("res://resources/minigames/cutting_minigame_tuning.tres")
@export_enum("Easy", "Medium", "Hard", "Tutorial") var collection_difficulty: int = MinigameDifficulty.Level.MEDIUM
## Negative values use the selected minigame/difficulty time cost.
@export var collection_time_cost_blocks: float = -1.0
## Negative values use the selected minigame/difficulty miss time cost.
@export var collection_miss_time_cost_blocks: float = -1.0
@export_group("")

@onready var hover_sprite: Sprite2D = $HoverSprite
@onready var name_label: Label = $NameLabel
@onready var click_area: Area2D = $ClickArea
@onready var interaction_point: Area2D = get_node_or_null("InteractionPoint") as Area2D

var _hover_tween: Tween
var _is_interacting := false
var _collection_id: StringName


func _ready() -> void:
	if not plant_data:
		push_error("CollectablePlant '%s' requires PlantData." % get_path())
		click_area.input_pickable = false
		return

	_collection_id = _get_collection_id()
	_make_hover_ignore_world_tint()
	hover_sprite.modulate = Color(hover_color.r, hover_color.g, hover_color.b, 0.0)
	name_label.text = _get_localized_plant_display_name()
	name_label.visible = false
	FlorilexioManager.knowledge_changed.connect(_on_knowledge_changed)
	_refresh_collection_availability()
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)
	click_area.input_event.connect(_on_input_event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(name_label):
		name_label.text = _get_localized_plant_display_name()


func _on_mouse_entered() -> void:
	if not _can_interact():
		return

	SoundManager.play_simple_sound('Actions/Hover')
	
	_fade_hover_to(hover_color.a)
	_set_name_label_visible(true)


func _on_mouse_exited() -> void:
	_fade_hover_to(0.0)
	_set_name_label_visible(false)


func _on_input_event(viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _can_interact():
			return

		viewport.set_input_as_handled()
		_interact()


func _interact() -> void:
	if not _can_interact():
		return
		
	_is_interacting = true

	SoundManager.play_simple_sound('Actions/Click')

	if interaction_point:
		var player := get_tree().get_first_node_in_group("player")
		if player and player.has_method("move_to_area"):
			var reached: bool = await player.move_to_area(interaction_point)
			if not reached:
				_is_interacting = false
				return
		elif player and player.has_method("move_to_point"):
			var stop_distance: float = player.interaction_stop_distance if "interaction_stop_distance" in player else 6.0
			var reached: bool = await player.move_to_point(interaction_point.global_position, stop_distance)
			if not reached:
				_is_interacting = false
				return

	start_collection_minigame()


func start_collection_minigame() -> void:
	if not _can_start_collection():
		_on_collection_minigame_closed()
		return

	var context := build_collection_minigame_context()
	var coordinator := _get_minigame_coordinator()
	if not coordinator:
		push_warning("CollectablePlant: MinigameCoordinator not found")
		_on_collection_minigame_closed()
		return

	var result: MinigameResult = await coordinator.play_minigame(context)
	_apply_collection_minigame_result(result)
	_on_collection_minigame_closed()


func build_collection_minigame_context() -> MinigameContext:
	var context := MinigameContext.new()
	context.config = collection_minigame_config
	context.target_id = get_plant_id()
	context.display_name = get_plant_display_name()
	context.difficulty_id = MinigameDifficulty.get_id(collection_difficulty)
	_apply_collection_tuning(context)
	context.rewards = _build_collection_rewards()
	context.metadata = _build_collection_metadata()
	return context


func _apply_collection_tuning(context: MinigameContext) -> void:
	var base_parameters := _build_collection_base_parameters()
	if collection_minigame_tuning:
		collection_minigame_tuning.apply_to_context(context, collection_difficulty, base_parameters)
	else:
		context.parameters = base_parameters


func _build_collection_base_parameters() -> Dictionary:
	var parameters := {}
	if collection_time_cost_blocks >= 0.0:
		parameters[&"time_cost_blocks"] = collection_time_cost_blocks
	if collection_miss_time_cost_blocks >= 0.0:
		parameters[&"miss_time_cost_blocks"] = collection_miss_time_cost_blocks
	return parameters


func _build_collection_rewards() -> Dictionary:
	return {
		&"plant_id": get_plant_id(),
		&"amount": 1,
		&"display_name": get_plant_display_name(),
	}


func _build_collection_metadata() -> Dictionary:
	return {
		&"collection_id": _collection_id,
	}


func _apply_collection_minigame_result(result: MinigameResult) -> void:
	if not result or result.is_cancelled():
		return

	GameState.add_consumed_time(result.get_total_time_cost_blocks())
	if not result.is_success():
		return

	var collected_plant_id := StringName(result.rewards.get(&"plant_id", result.target_id))
	var collected_amount := int(result.rewards.get(&"amount", 1))
	if collected_amount <= 0:
		push_warning("CollectablePlant: collected amount must be positive.")
		return

	if ItemDatabase.get_plant(collected_plant_id) == null:
		push_warning("CollectablePlant: unknown collected plant '%s'." % collected_plant_id)
		return

	GameState.collect_plant(_collection_id)
	InventoryManager.add_item(
		collected_plant_id, collected_amount,
		InventoryManager.AdditionMode.ACQUIRE,
		_collection_id
	)
	_on_collection_minigame_completed()


func _on_collection_minigame_completed() -> void:
	click_area.input_pickable = false
	_fade_hover_to(0.0)
	_set_name_label_visible(false)

	DialogueBalloonCoordinator.show_info_dialogue(
		"plant_collected",
		{"plant_name": _get_localized_plant_display_name()},
		1.5
	)


func _on_collection_minigame_closed() -> void:
	_is_interacting = false
	_refresh_collection_availability()


func get_collection_requirements() -> Array[StringName]:
	if override_collection_requirements:
		return collection_requirements_override

	return plant_data.collection_requirements


func get_plant_id() -> StringName:
	return plant_data.id


func get_plant_display_name() -> String:
	return plant_data.display_name


func _can_interact() -> bool:
	return not _is_interacting and _can_start_collection()


func _can_start_collection() -> bool:
	return not _is_collected() and _meets_collection_requirements()


func _meets_collection_requirements() -> bool:
	return FlorilexioManager.can_be_collected(
		get_plant_id(),
		get_collection_requirements()
	)


func _is_collected() -> bool:
	return GameState.is_plant_collected(_collection_id)


func _get_minigame_coordinator() -> MinigameCoordinator:
	var coordinator := get_tree().get_first_node_in_group(&"minigame_coordinator") as MinigameCoordinator
	if coordinator:
		return coordinator

	var current_scene := get_tree().current_scene
	if current_scene:
		return current_scene.get_node_or_null("MinigameCoordinator") as MinigameCoordinator
	return null


func _fade_hover_to(target_alpha: float) -> void:
	if _hover_tween:
		_hover_tween.kill()

	_hover_tween = create_tween()
	_hover_tween.tween_property(hover_sprite, "modulate:a", target_alpha, hover_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_name_label_visible(should_show: bool) -> void:
	name_label.visible = should_show and not get_plant_display_name().is_empty()


func _get_localized_plant_display_name() -> String:
	var display_name := get_plant_display_name()
	if display_name.is_empty():
		return ""

	return tr(display_name)


func _make_hover_ignore_world_tint() -> void:
	# TODO: Unificar funcións aquí e en  npc.gd
	var hover_material := CanvasItemMaterial.new()
	hover_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	hover_sprite.material = hover_material
	name_label.material = hover_material


func _get_collection_id() -> StringName:
	if collection_id != &"":
		return collection_id

	var area_root := _get_area_root()
	if area_root:
		var area_path := area_root.scene_file_path
		if area_path.is_empty():
			area_path = str(area_root.get_path())

		return StringName("%s:%s" % [area_path, area_root.get_path_to(self)])

	return StringName(str(get_path()))


func _get_area_root() -> Node:
	var current := get_parent()
	while current:
		if not current.scene_file_path.is_empty():
			return current

		current = current.get_parent()

	return null


func _on_knowledge_changed(changed_plant_id: StringName) -> void:
	if changed_plant_id != get_plant_id():
		return

	_refresh_collection_availability()


func _refresh_collection_availability() -> void:
	click_area.input_pickable = _can_start_collection()

	if click_area.input_pickable:
		return

	_fade_hover_to(0.0)
	_set_name_label_visible(false)
