extends Control

signal close_requested

enum Section { MISSIONS, FLORILEXIO }

@onready var close_button: TextureButton = %CloseButton
@onready var missions_tab_button: TextureButton = %MissionsTabButton
@onready var florilexio_tab_button: TextureButton = %FlorilexioTabButton
@onready var missions_panel: MissionsPanel = %MissionsPanel
@onready var florilexio_panel: FlorilexioPanel = %FlorilexioPanel

var _active_section := Section.MISSIONS


func _ready() -> void:
	close_button.pressed.connect(func() -> void: close_requested.emit())
	missions_tab_button.pressed.connect(func() -> void: _set_section(Section.MISSIONS))
	florilexio_tab_button.pressed.connect(func() -> void: _set_section(Section.FLORILEXIO))
	_apply_section_visibility()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_requested.emit()


func prepare_to_open() -> void:
	missions_panel.prepare_to_open()
	florilexio_panel.prepare_to_open()
	_apply_section_visibility()


func _set_section(section: Section) -> void:
	_active_section = section
	_apply_section_visibility()


func _apply_section_visibility() -> void:
	if not is_node_ready():
		return
	var showing_missions := _active_section == Section.MISSIONS
	missions_panel.visible = showing_missions
	florilexio_panel.visible = not showing_missions
	missions_tab_button.button_pressed = showing_missions
	florilexio_tab_button.button_pressed = not showing_missions
	if showing_missions:
		missions_panel.on_selected()
	else:
		florilexio_panel.on_selected()
