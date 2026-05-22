extends Control

signal close_requested

@export var item_row_scene: PackedScene = preload("res://ui/inventory/inventory_item_row.tscn")

@onready var items_container: VBoxContainer = %ItemsContainer
@onready var empty_label: Label = %EmptyLabel
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	InventoryManager.inventory_changed.connect(_refresh)
	close_button.pressed.connect(_on_close_button_pressed)
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

	for plant_id in plant_ids:
		var row := item_row_scene.instantiate()
		items_container.add_child(row)
		row.setup(InventoryManager.get_display_name(plant_id), int(inventory_items[plant_id]))


func _on_close_button_pressed() -> void:
	close_requested.emit()
