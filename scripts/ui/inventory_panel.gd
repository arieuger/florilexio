extends Control

signal close_requested
signal compose_bouquet_requested

@export var item_row_scene: PackedScene = preload("res://ui/inventory/inventory_item_row.tscn")
@export_range(1, 20, 1) var items_per_page := 10

@onready var items_container: VBoxContainer = %ItemsContainer
@onready var empty_label: Label = %EmptyLabel
@onready var close_button: TextureButton = %CloseButton
@onready var paginator: HBoxContainer = %Paginator
@onready var previous_page_button: TextureButton = %PreviousPageButton
@onready var page_label: Label = %PageLabel
@onready var next_page_button: TextureButton = %NextPageButton
@onready var compose_bouquet_button: PanelContainer = %ComposeBouquetButton

var _current_page := 0


func _ready() -> void:
	InventoryManager.inventory_changed.connect(_refresh)
	GameState.invasive_plants_acknowledgement_changed.connect(_on_some_acknowledgement_changed)
	GameState.mortal_plants_acknowledgement_changed.connect(_on_some_acknowledgement_changed)
	GameState.magic_plants_acknowledgement_changed.connect(_on_some_acknowledgement_changed)
	close_button.pressed.connect(_on_close_button_pressed)
	close_button.mouse_entered.connect(_on_close_button_mouse_entered)
	previous_page_button.pressed.connect(_on_previous_page_pressed)
	next_page_button.pressed.connect(_on_next_page_pressed)
	compose_bouquet_button.gui_input.connect(_on_compose_bouquet_button_gui_input)
	compose_bouquet_button.mouse_entered.connect(_on_compose_bouquet_button_mouse_entered)
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


func _refresh() -> void:
	for child in items_container.get_children():
		items_container.remove_child(child)
		child.queue_free()

	var inventory_items := InventoryManager.get_items()
	empty_label.visible = inventory_items.is_empty()
	items_container.visible = not inventory_items.is_empty()

	var plant_ids := inventory_items.keys()
	plant_ids.sort()
	var page_count := _get_page_count(plant_ids.size())
	paginator.visible = page_count > 1
	_current_page = clampi(_current_page, 0, page_count - 1)
	var start_index := _current_page * items_per_page
	var end_index = mini(start_index + items_per_page, plant_ids.size())

	for index in range(start_index, end_index):
		var plant_id: StringName = plant_ids[index]
		var row := item_row_scene.instantiate()
		items_container.add_child(row)
		row.setup(plant_id, InventoryManager.get_display_name(plant_id), int(inventory_items[plant_id]))
		row.discard_requested.connect(_on_item_row_discard_requested)

	_update_paginator(page_count)


func _on_close_button_pressed() -> void:
	SoundManager.play_simple_sound("Inventory/Open Inventory")
	close_requested.emit()


func _on_close_button_mouse_entered() -> void:
	SoundManager.play_simple_sound("Actions/Hover")


func _on_previous_page_pressed() -> void:
	_current_page = maxi(_current_page - 1, 0)
	SoundManager.play_simple_sound("Inventory/Open Inventory")
	_refresh()


func _on_next_page_pressed() -> void:
	_current_page += 1
	SoundManager.play_simple_sound("Inventory/Open Inventory")
	_refresh()


func _on_item_row_discard_requested(plant_id: StringName) -> void:
	if InventoryManager.discard_item(plant_id):
		SoundManager.play_simple_sound("Actions/Click")


func _on_compose_bouquet_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		SoundManager.play_simple_sound("Actions/Click")
		compose_bouquet_requested.emit()


func _on_compose_bouquet_button_mouse_entered() -> void:
	SoundManager.play_simple_sound("Actions/Hover")


func _on_some_acknowledgement_changed(_is_acknowledged: bool) -> void:
	_refresh()


func _get_page_count(item_count: int) -> int:
	if item_count <= 0:
		return 1

	return ceili(float(item_count) / float(items_per_page))


func _update_paginator(page_count: int) -> void:
	page_label.text = str(_current_page + 1) + "/" + str(page_count)
	previous_page_button.disabled = _current_page <= 0
	next_page_button.disabled = _current_page >= page_count - 1
