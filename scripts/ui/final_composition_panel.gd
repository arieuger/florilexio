extends Control
class_name FinalCompositionPanel

signal composition_requested

const FLOWERS_EMPTY_COUNT := 0
const FLOWERS_LOW_COUNT := 1
const FLOWERS_MEDIUM_COUNT := 4
const FLOWERS_HIGH_COUNT := 7

@export var item_row_scene: PackedScene = preload("res://ui/final_composition/final_composition_item_row.tscn")
@export var selected_row_scene: PackedScene = preload("res://ui/final_composition/final_composition_selected_row.tscn")
@export_range(1, 20, 1) var available_items_per_page := 7
@export_range(1, 20, 1) var selected_items_per_page := 7
@export var low_flowers_texture: Texture2D = preload("res://assets/sprites/environment/flowers_composition/low_number_flowers.png")
@export var medium_flowers_texture: Texture2D = preload("res://assets/sprites/environment/flowers_composition/medium_number_flowers.png")
@export var high_flowers_texture: Texture2D = preload("res://assets/sprites/environment/flowers_composition/high_number_flowers.png")

@onready var items_container: VBoxContainer = %ItemsContainer
@onready var selected_container: VBoxContainer = %SelectedContainer
@onready var empty_inventory_label: Label = %EmptyInventoryLabel
@onready var empty_bowl_label: Label = %EmptyBowlLabel
@onready var flowers_texture_rect: TextureRect = %FlowersTextureRect
@onready var bowl_drop_area: Control = %BowlDropArea
@onready var compose_button: PanelContainer = %ComposeButton
@onready var count_label: Label = %CountLabel
@onready var available_paginator: HBoxContainer = %AvailablePaginator
@onready var available_previous_page_button: TextureButton = %AvailablePreviousPageButton
@onready var available_page_label: Label = %AvailablePageLabel
@onready var available_next_page_button: TextureButton = %AvailableNextPageButton
@onready var selected_paginator: HBoxContainer = %SelectedPaginator
@onready var selected_previous_page_button: TextureButton = %SelectedPreviousPageButton
@onready var selected_page_label: Label = %SelectedPageLabel
@onready var selected_next_page_button: TextureButton = %SelectedNextPageButton

var _available_current_page := 0
var _selected_current_page := 0


func _ready() -> void:
	InventoryManager.bouquet_changed.connect(_refresh)
	InventoryManager.inventory_changed.connect(_refresh)
	bowl_drop_area.connect(&"plant_dropped", _on_bowl_plant_dropped)
	available_previous_page_button.pressed.connect(_on_available_previous_page_pressed)
	available_next_page_button.pressed.connect(_on_available_next_page_pressed)
	selected_previous_page_button.pressed.connect(_on_selected_previous_page_pressed)
	selected_next_page_button.pressed.connect(_on_selected_next_page_pressed)
	compose_button.gui_input.connect(_on_compose_button_gui_input)
	_refresh()


func _refresh() -> void:
	_refresh_available_items()
	_refresh_selected_items()
	_refresh_bowl_sprite()


func _refresh_available_items() -> void:
	for child in items_container.get_children():
		items_container.remove_child(child)
		child.queue_free()

	var inventory_items := InventoryManager.get_items()
	empty_inventory_label.visible = inventory_items.is_empty()
	items_container.visible = not inventory_items.is_empty()

	var plant_ids := inventory_items.keys()
	plant_ids.sort()
	var page_count := _get_page_count(plant_ids.size(), available_items_per_page)
	available_paginator.visible = true
	_available_current_page = clampi(_available_current_page, 0, page_count - 1)
	var start_index := _available_current_page * available_items_per_page
	var end_index = mini(start_index + available_items_per_page, plant_ids.size())

	for index in range(start_index, end_index):
		var raw_plant_id = plant_ids[index]
		var plant_id: StringName = raw_plant_id
		var available_amount := int(inventory_items[plant_id]) - _get_selected_amount(plant_id)
		var row := item_row_scene.instantiate()
		items_container.add_child(row)
		row.setup(plant_id, InventoryManager.get_display_name(plant_id), available_amount)

	_update_available_paginator(page_count)


func _refresh_selected_items() -> void:
	for child in selected_container.get_children():
		selected_container.remove_child(child)
		child.queue_free()

	var bouquet_items := InventoryManager.get_bouquet_items()
	empty_bowl_label.visible = bouquet_items.is_empty()
	selected_container.visible = not bouquet_items.is_empty()
	count_label.text = str(bouquet_items.size())
	var page_count := _get_page_count(bouquet_items.size(), selected_items_per_page)
	selected_paginator.visible = true
	_selected_current_page = clampi(_selected_current_page, 0, page_count - 1)
	var start_index := _selected_current_page * selected_items_per_page
	var end_index = mini(start_index + selected_items_per_page, bouquet_items.size())

	for index in range(start_index, end_index):
		var plant_id := bouquet_items[index]
		var row := selected_row_scene.instantiate()
		selected_container.add_child(row)
		row.setup(index, InventoryManager.get_display_name(plant_id))
		row.remove_requested.connect(_on_selected_row_remove_requested)

	_update_selected_paginator(page_count)


func _refresh_bowl_sprite() -> void:
	var bouquet_count := InventoryManager.get_bouquet_count()
	if bouquet_count == FLOWERS_EMPTY_COUNT:
		flowers_texture_rect.texture = null
	elif bouquet_count < FLOWERS_MEDIUM_COUNT:
		flowers_texture_rect.texture = low_flowers_texture
	elif bouquet_count < FLOWERS_HIGH_COUNT:
		flowers_texture_rect.texture = medium_flowers_texture
	else:
		flowers_texture_rect.texture = high_flowers_texture


func _get_selected_amount(plant_id: StringName) -> int:
	var selected_count := 0
	for selected_plant_id in InventoryManager.get_bouquet_items():
		if selected_plant_id == plant_id:
			selected_count += 1
	return selected_count


func _get_page_count(item_count: int, page_size: int) -> int:
	if item_count <= 0:
		return 1

	return ceili(float(item_count) / float(page_size))


func _update_available_paginator(page_count: int) -> void:
	available_page_label.text = str(_available_current_page + 1) + "/" + str(page_count)
	available_previous_page_button.disabled = _available_current_page <= 0
	available_next_page_button.disabled = _available_current_page >= page_count - 1
	_set_paginator_alpha(available_paginator, 1.0 if page_count > 1 else 0.0)


func _update_selected_paginator(page_count: int) -> void:
	selected_page_label.text = str(_selected_current_page + 1) + "/" + str(page_count)
	selected_previous_page_button.disabled = _selected_current_page <= 0
	selected_next_page_button.disabled = _selected_current_page >= page_count - 1
	_set_paginator_alpha(selected_paginator, 1.0 if page_count > 1 else 0.0)


func _set_paginator_alpha(paginator: Control, alpha: float) -> void:
	paginator.self_modulate.a = alpha
	paginator.modulate.a = alpha
	for child in paginator.get_children():
		if child is CanvasItem:
			child.self_modulate.a = alpha


func _on_selected_row_remove_requested(index: int) -> void:
	InventoryManager.remove_from_bouquet(index)


func _on_bowl_plant_dropped(plant_id: StringName) -> void:
	InventoryManager.add_to_bouquet(plant_id)


func _on_available_previous_page_pressed() -> void:
	_available_current_page = maxi(_available_current_page - 1, 0)
	_refresh_available_items()


func _on_available_next_page_pressed() -> void:
	_available_current_page += 1
	_refresh_available_items()


func _on_selected_previous_page_pressed() -> void:
	_selected_current_page = maxi(_selected_current_page - 1, 0)
	_refresh_selected_items()


func _on_selected_next_page_pressed() -> void:
	_selected_current_page += 1
	_refresh_selected_items()


func _on_compose_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		composition_requested.emit()
		print("TODO: calcular puntuacións do cacho con ", InventoryManager.get_bouquet_items())
