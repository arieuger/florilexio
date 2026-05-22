extends CanvasLayer

@onready var inventory_button: TextureButton = $InventoryButton
@onready var inventory_panel: Control = $InventoryPanel


func _ready() -> void:
	_set_inventory_open(false)
	inventory_button.pressed.connect(_toggle_inventory)
	if inventory_panel.has_signal(&"close_requested"):
		inventory_panel.connect(&"close_requested", _hide_inventory)


func _toggle_inventory() -> void:
	_set_inventory_open(not inventory_panel.visible)


func _hide_inventory() -> void:
	_set_inventory_open(false)


func _set_inventory_open(is_open: bool) -> void:
	inventory_panel.visible = is_open
	inventory_button.visible = not is_open
