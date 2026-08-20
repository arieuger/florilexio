extends Control

signal close_requested

enum Section { MISSIONS, FLORILEXIO, INVENTORY }

@onready var close_button: TextureButton = %CloseButton
@onready var missions_tab_button: TextureButton = %MissionsTabButton
@onready var florilexio_tab_button: TextureButton = %FlorilexioTabButton
@onready var inventory_tab_button: TextureButton = %InventoryTabButton
@onready var missions_panel: MissionsPanel = %MissionsPanel
@onready var florilexio_panel: FlorilexioPanel = %FlorilexioPanel
@onready var inventory_panel: InventoryPanel = %InventoryPanel

var _active_section := Section.MISSIONS


func _ready() -> void:
	close_button.pressed.connect(func() -> void: close_requested.emit())
	missions_tab_button.pressed.connect(func() -> void: _set_section(Section.MISSIONS))
	florilexio_tab_button.pressed.connect(func() -> void: _set_section(Section.FLORILEXIO))
	inventory_tab_button.pressed.connect(func() -> void: _set_section(Section.INVENTORY))
	_apply_section_visibility()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_requested.emit()


func prepare_to_open() -> void:
	missions_panel.prepare_to_open()
	florilexio_panel.prepare_to_open()
	inventory_panel.prepare_to_open()
	_apply_section_visibility()


func _set_section(section: Section) -> void:
	_active_section = section
	_apply_section_visibility()


func _apply_section_visibility() -> void:
	if not is_node_ready():
		return

	missions_panel.visible = _active_section == Section.MISSIONS
	florilexio_panel.visible = _active_section == Section.FLORILEXIO
	inventory_panel.visible = _active_section == Section.INVENTORY	
	missions_tab_button.button_pressed = missions_panel.visible
	florilexio_tab_button.button_pressed = florilexio_panel.visible
	inventory_tab_button.button_pressed = inventory_panel.visible	

	match _active_section:
		Section.MISSIONS:
			missions_panel.on_selected()
		Section.FLORILEXIO:
			florilexio_panel.on_selected()
		Section.INVENTORY:
			inventory_panel.on_selected()
