extends CanvasLayer

const CUTTING_MINIGAME_SCENE := preload("res://scenes/minigames/cutting_minigame.tscn")
const DEFAULT_PLANT_ID := &"macela"
const AFTERNOON_BLOCK := 20
const DUSK_BLOCK := 36

@onready var time_status_label: Label = %TimeStatusLabel
@onready var plant_id_input: LineEdit = %PlantIdInput
@onready var inventory_toggle_button: Button = %InventoryToggleButton
@onready var florilexio_status_label: Label = %FlorilexioStatusLabel
@onready var florilexio_buttons: Array[Button] = [
	%MarkObservedButton,
	%UnlockNameButton,
	%UnlockVisualIdButton,
	%MarkIdentifiedButton,
	%ResetKnowledgeButton,
]
@onready var florilexio_section_controls: Array[Control] = [
	%FlorilexioTitle,
	%FlorilexioStatusLabel,
	%FlorilexioButtons1,
	%FlorilexioButtons2,
	%ResetKnowledgeButton,
]

var _florilexio_manager: Node


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return

	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_time_section()
	_setup_inventory_section()
	_setup_florilexio_section()
	_setup_minigame_section()
	_setup_reset_section()
	visible = false


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if event.is_action_pressed(&"toggle_debug_panel"):
		visible = not visible
		if visible:
			_refresh_status()
			plant_id_input.grab_focus()
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		visible = false
		get_viewport().set_input_as_handled()


func _setup_time_section() -> void:
	%AddOneBlockButton.pressed.connect(_on_add_time_pressed.bind(1))
	%AddFourBlocksButton.pressed.connect(_on_add_time_pressed.bind(4))
	%GoMorningButton.pressed.connect(_set_time.bind(0, "mañá"))
	%GoAfternoonButton.pressed.connect(_set_time.bind(AFTERNOON_BLOCK, "tarde"))
	%GoDuskButton.pressed.connect(_set_time.bind(DUSK_BLOCK, "solpor"))
	%GoNightButton.pressed.connect(_set_time.bind(GameState.NIGHT_START_BLOCK, "noite"))
	%GoEndOfDayButton.pressed.connect(_set_time.bind(GameState.TOTAL_BLOCKS, "final de jornada"))
	GameState.consumed_time_added.connect(_on_consumed_time_changed)


func _setup_inventory_section() -> void:
	%AddPlantButton.pressed.connect(_on_add_inventory_item_pressed)
	%ClearInventoryButton.pressed.connect(_on_clear_inventory_pressed)
	inventory_toggle_button.pressed.connect(_on_toggle_inventory_pressed)


func _setup_florilexio_section() -> void:
	_florilexio_manager = get_node_or_null("/root/FlorilexioManager")
	var is_available := is_instance_valid(_florilexio_manager)
	for control in florilexio_section_controls:
		control.visible = is_available
	florilexio_status_label.text = (
		"FlorilexioManager available"
		if is_available
		else "FlorilexioManager not available yet"
	)
	for button in florilexio_buttons:
		button.disabled = not is_available

	if not is_available:
		return

	%MarkObservedButton.pressed.connect(_call_florilexio_method.bind(&"mark_observed"))
	%UnlockNameButton.pressed.connect(_call_florilexio_method.bind(&"unlock_name"))
	%UnlockVisualIdButton.pressed.connect(_call_florilexio_method.bind(&"unlock_visual_id"))
	%MarkIdentifiedButton.pressed.connect(_call_florilexio_method.bind(&"mark_identified"))
	%ResetKnowledgeButton.pressed.connect(_call_florilexio_method.bind(&"reset_entry"))


func _setup_minigame_section() -> void:
	%LaunchCuttingMinigameButton.pressed.connect(_on_launch_cutting_minigame_pressed)


func _setup_reset_section() -> void:
	%ResetGameStateButton.pressed.connect(_on_reset_game_state_pressed)
	%ResetInventoryButton.pressed.connect(_on_clear_inventory_pressed)
	%ResetAllButton.pressed.connect(_on_debug_reset_pressed)


func _on_add_time_pressed(blocks: int) -> void:
	GameState.add_consumed_time(blocks)
	print("[DebugPanel] Added %d time block(s)" % blocks)


func _set_time(blocks: int, phase_name: String) -> void:
	GameState.set_consumed_time_blocks(blocks)
	print("[DebugPanel] Set time to %s (block %d)" % [phase_name, blocks])


func _on_consumed_time_changed(_blocks: int) -> void:
	_refresh_time_status()


func _on_add_inventory_item_pressed() -> void:
	var plant_id := _get_plant_id()
	var plant_data := _get_plant_debug_data(plant_id)

	InventoryManager.add_item(
		plant_id,
		1,
		str(plant_data.get("display_name", "")),
		plant_data.get("marks", {})
	)
	print("[DebugPanel] Added plant to inventory: %s" % plant_id)


func _on_clear_inventory_pressed() -> void:
	if InventoryManager.has_method(&"debug_reset"):
		InventoryManager.debug_reset()
	else:
		InventoryManager.clear()
	print("[DebugPanel] Inventory reset")


func _on_toggle_inventory_pressed() -> void:
	var game_hud := _get_game_hud()
	if game_hud and game_hud.has_method(&"_toggle_inventory"):
		game_hud.call(&"_toggle_inventory")
		visible = false
		print("[DebugPanel] Toggled inventory UI")
	else:
		print("[DebugPanel] Inventory UI not available")


func _call_florilexio_method(method_name: StringName) -> void:
	if not is_instance_valid(_florilexio_manager):
		print("[DebugPanel] FlorilexioManager not available")
		return
	if not _florilexio_manager.has_method(method_name):
		print("[DebugPanel] FlorilexioManager.%s is not available" % method_name)
		return

	var plant_id := _get_plant_id()
	_florilexio_manager.call(method_name, plant_id)
	print("[DebugPanel] Called FlorilexioManager.%s for %s" % [method_name, plant_id])


func _on_launch_cutting_minigame_pressed() -> void:
	var coordinator := _get_minigame_coordinator()
	if not coordinator:
		push_warning("[DebugPanel] MinigameCoordinator not available")
		return
	if coordinator.is_minigame_running():
		print("[DebugPanel] A cutting minigame is already running")
		return

	var plant_id := _get_plant_id()
	var plant := _get_plant_debug_source(plant_id)
	var context: MinigameContext
	if plant:
		context = plant.build_collection_minigame_context()
	else:
		context = _build_debug_cutting_minigame_context(plant_id)

	_free_debug_plant_source(plant)
	visible = false
	var result: MinigameResult = await coordinator.play_minigame(context)
	_apply_debug_minigame_result(result)
	print("[DebugPanel] Launched cutting minigame for %s" % plant_id)


func _build_debug_cutting_minigame_context(plant_id: StringName) -> MinigameContext:
	var config := MinigameConfig.new()
	config.minigame_id = &"cutting"
	config.scene = CUTTING_MINIGAME_SCENE

	var context := MinigameContext.new()
	context.config = config
	context.target_id = plant_id
	context.display_name = InventoryManager.get_display_name(plant_id)
	context.difficulty_id = &"medium"
	context.required_hits = 3
	context.max_misses = 3
	context.parameters = {
		&"time_cost_blocks": 1.0,
		&"miss_time_cost_blocks": 1.0,
		&"rotation_speed_degrees": 400.0,
		&"direction_change_chance": 0.8,
		&"success_alpha_threshold": 0.1,
	}
	context.rewards = {
		&"plant_id": plant_id,
		&"amount": 1,
		&"display_name": context.display_name,
		&"marks": {},
	}
	return context


func _apply_debug_minigame_result(result: MinigameResult) -> void:
	if not result or result.is_cancelled():
		return

	GameState.add_consumed_time(result.get_total_time_cost_blocks())
	if not result.is_success():
		return

	InventoryManager.add_item(
		StringName(result.rewards.get(&"plant_id", result.target_id)),
		int(result.rewards.get(&"amount", 1)),
		str(result.rewards.get(&"display_name", "")),
		_get_result_marks(result)
	)


func _get_result_marks(result: MinigameResult) -> Dictionary:
	var marks: Variant = result.rewards.get(&"marks", {})
	return marks if marks is Dictionary else {}

func _on_reset_game_state_pressed() -> void:
	if GameState.has_method(&"debug_reset"):
		GameState.debug_reset()
		print("[DebugPanel] GameState reset")


func _on_debug_reset_pressed() -> void:
	_on_reset_game_state_pressed()
	_on_clear_inventory_pressed()
	print("[DebugPanel] All debug state reset")


func _refresh_status() -> void:
	_refresh_time_status()
	inventory_toggle_button.disabled = false


func _refresh_time_status() -> void:
	if not is_instance_valid(time_status_label):
		return
	time_status_label.text = "Hora: %s | bloque %d/%d" % [
		GameState.get_current_time_text(),
		GameState.consumed_time,
		GameState.TOTAL_BLOCKS,
	]


func _get_plant_id() -> StringName:
	var normalized_id := plant_id_input.text.strip_edges()
	if normalized_id.is_empty():
		plant_id_input.text = String(DEFAULT_PLANT_ID)
		normalized_id = String(DEFAULT_PLANT_ID)
	return StringName(normalized_id)


func _get_plant_debug_data(plant_id: StringName) -> Dictionary:
	var plant := _get_plant_debug_source(plant_id)
	if not plant:
		return {"display_name": "", "marks": {}}

	var data := {
		"display_name": str(plant.get("plant_display_name")),
		"marks": InventoryManager.build_plant_marks(plant),
	}
	_free_debug_plant_source(plant)
	return data


func _get_plant_debug_source(plant_id: StringName) -> CollectablePlant:
	var plant := _find_collectable_plant(plant_id)
	if plant:
		return plant

	var scene_path := "res://scenes/interactables/plants/%s.tscn" % String(plant_id).replace("-", "_")
	if not ResourceLoader.exists(scene_path):
		return null

	var plant_scene := load(scene_path) as PackedScene
	if not plant_scene:
		return null

	plant = plant_scene.instantiate() as CollectablePlant
	if plant:
		plant.set_meta(&"debug_temporary_source", true)
	return plant


func _free_debug_plant_source(plant: CollectablePlant) -> void:
	if plant and plant.has_meta(&"debug_temporary_source"):
		plant.free()


func _find_collectable_plant(plant_id: StringName) -> CollectablePlant:
	var current_scene := get_tree().current_scene
	if current_scene:
		return _find_collectable_plant_recursive(current_scene, plant_id)
	return null


func _get_game_hud() -> Node:
	var game_hud := get_tree().get_first_node_in_group(&"game_hud")
	if game_hud:
		return game_hud

	var current_scene := get_tree().current_scene
	if current_scene:
		return current_scene.get_node_or_null("GameHUD")
	return null


func _get_minigame_coordinator() -> MinigameCoordinator:
	var coordinator := get_tree().get_first_node_in_group(&"minigame_coordinator") as MinigameCoordinator
	if coordinator:
		return coordinator

	var current_scene := get_tree().current_scene
	if current_scene:
		return current_scene.get_node_or_null("MinigameCoordinator") as MinigameCoordinator
	return null


func _find_collectable_plant_recursive(node: Node, plant_id: StringName) -> CollectablePlant:
	if node is CollectablePlant and node.plant_id == plant_id:
		return node
	for child in node.get_children():
		var result := _find_collectable_plant_recursive(child, plant_id)
		if result:
			return result
	return null
