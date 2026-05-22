extends CanvasLayer

@onready var inventory_button: TextureButton = $InventoryButton
@onready var inventory_panel: Control = $InventoryPanel


func _ready() -> void:
	inventory_panel.visible = false
	inventory_button.pressed.connect(_toggle_inventory)
	if inventory_panel.has_signal(&"close_requested"):
		inventory_panel.connect(&"close_requested", _hide_inventory)


func _toggle_inventory() -> void:
	inventory_panel.visible = not inventory_panel.visible


func _hide_inventory() -> void:
	inventory_panel.visible = false
