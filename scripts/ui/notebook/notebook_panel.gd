extends Control

signal close_requested

enum Section {MISSIONS, FLORILEXIO, INVENTORY}

@onready var close_button: TextureButton = %CloseButton
@onready var missions_tab_button: TextureButton = %MissionsTabButton
@onready var florilexio_tab_button: TextureButton = %FlorilexioTabButton
@onready var inventory_tab_button: TextureButton = %InventoryTabButton
@onready var missions_panel: MissionsPanel = %MissionsPanel
@onready var florilexio_panel: FlorilexioPanel = %FlorilexioPanel
@onready var inventory_panel: InventoryPanel = %InventoryPanel

@onready var left_hover: TextureRect = %NotebookLeftHover
@onready var right_hover: TextureRect = %NotebookRightHover
@onready var left_hover_area: Control = %NotebookLeftHoverArea
@onready var right_hover_area: Control = %NotebookRightHoverArea

var _active_section := Section.MISSIONS

var _paginated_sections := [Section.FLORILEXIO]


func _ready() -> void:
	close_button.pressed.connect(func() -> void: close_requested.emit())
	missions_tab_button.pressed.connect(func() -> void: _set_section(Section.MISSIONS))
	florilexio_tab_button.pressed.connect(func() -> void: _set_section(Section.FLORILEXIO))
	inventory_tab_button.pressed.connect(func() -> void: _set_section(Section.INVENTORY))

	for area in [left_hover_area, right_hover_area]:
		area.mouse_entered.connect(_update_pagination)
		area.mouse_exited.connect(_update_pagination)

	florilexio_panel.pagination_changed.connect(_update_pagination)

	left_hover_area.gui_input.connect(_on_pagination_input.bind(false))
	right_hover_area.gui_input.connect(_on_pagination_input.bind(true))

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

	_update_pagination()


func _update_pagination() -> void:
	var panel := _get_active_pagination_panel()
	var can_previous := false
	var can_next := false

	if panel != null:
		can_previous = panel.call(&"can_go_previous")
		can_next = panel.call(&"can_go_next")

	_set_pagination_area(left_hover_area, left_hover, can_previous)
	_set_pagination_area(right_hover_area, right_hover, can_next)


func _set_pagination_area(area: Control, hover_texture: TextureRect, enabled: bool) -> void:
	area.visible = enabled
	area.mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if enabled
		else Control.MOUSE_FILTER_IGNORE
	)

	hover_texture.visible = (
		enabled and area.is_visible_in_tree()
        and Rect2(Vector2.ZERO, area.size).has_point(area.get_local_mouse_position())
    )


func _on_pagination_input(event: InputEvent, forward: bool) -> void:
	if not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		# TODO: En algún momento haberá que implementar mando/teclado
		return

	var panel := _get_active_pagination_panel()
	if panel == null:
		return

	accept_event()
	panel.call(&"next_spread" if forward else &"previous_spread")


func _get_active_pagination_panel() -> Control:
	# Por si engadimos paxinación a outros paneis como o de misións/inventario
	if _active_section not in _paginated_sections:
		return null

	match _active_section:
		Section.FLORILEXIO:
			return florilexio_panel
		_:
			return null
