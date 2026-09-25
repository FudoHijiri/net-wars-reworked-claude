extends Control
## Reusable "Pattern Matching" repair minigame. A handful of placeholder tiles flash
## briefly, then the player must click that same set of tiles back from memory. There is
## nothing threat- or component-specific about the mechanic itself -- ScenarioDatabase
## decides which components use this type; Recovery hands this scene the component name
## purely so the on-screen text can name what's being repaired.

signal finished(success: bool)

const _TILE_COUNT: int = 6
const _TARGET_COUNT: int = 3
const _PREVIEW_SECONDS: float = 1.0
const _RESULT_PAUSE_SECONDS: float = 0.4

const _COLOR_NORMAL := Color(0.28, 0.31, 0.38)
const _COLOR_HIGHLIGHT := Color(0.95, 0.8, 0.2)
const _COLOR_SELECTED := Color(0.3, 0.55, 0.95)
const _COLOR_CORRECT := Color(0.3, 0.8, 0.4)
const _COLOR_WRONG := Color(0.85, 0.3, 0.3)

var _component_name: String = ""
var _target_indices: Array = []
var _selected_indices: Array = []
var _tile_buttons: Array = []
var _accepting_input: bool = false

var _instruction_label: Label
var _grid: GridContainer
var _confirm_button: Button


func _ready() -> void:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	add_child(rows)

	_instruction_label = Label.new()
	_instruction_label.horizontal_alignment = 1
	_instruction_label.autowrap_mode = 3
	rows.add_child(_instruction_label)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	var grid_center := CenterContainer.new()
	grid_center.add_child(_grid)
	rows.add_child(grid_center)

	for i in range(_TILE_COUNT):
		var tile := Button.new()
		tile.custom_minimum_size = Vector2(64, 64)
		tile.modulate = _COLOR_NORMAL
		tile.pressed.connect(_on_tile_pressed.bind(i))
		_grid.add_child(tile)
		_tile_buttons.append(tile)

	_confirm_button = Button.new()
	_confirm_button.text = "Confirm"
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(_on_confirm_pressed)
	var confirm_center := CenterContainer.new()
	confirm_center.add_child(_confirm_button)
	rows.add_child(confirm_center)


## Recovery calls this once, right after instancing the scene, and again for a retry.
func start(component_name: String) -> void:
	_component_name = component_name
	_instruction_label.text = "Watch which panels light up on the %s, then click the same panels from memory." % component_name.to_lower()
	_selected_indices.clear()
	_accepting_input = false
	_confirm_button.disabled = true

	for tile in _tile_buttons:
		tile.disabled = true
		tile.modulate = _COLOR_NORMAL

	_target_indices = _pick_random_indices(_TARGET_COUNT, _TILE_COUNT)
	for i in _target_indices:
		_tile_buttons[i].modulate = _COLOR_HIGHLIGHT

	await get_tree().create_timer(_PREVIEW_SECONDS).timeout

	for tile in _tile_buttons:
		tile.modulate = _COLOR_NORMAL
		tile.disabled = false

	_accepting_input = true


func retry() -> void:
	start(_component_name)


func _pick_random_indices(count: int, out_of: int) -> Array:
	var pool: Array = range(out_of)
	pool.shuffle()
	return pool.slice(0, count)


func _on_tile_pressed(index: int) -> void:
	if not _accepting_input:
		return

	if _selected_indices.has(index):
		_selected_indices.erase(index)
		_tile_buttons[index].modulate = _COLOR_NORMAL
	else:
		if _selected_indices.size() >= _target_indices.size():
			return
		_selected_indices.append(index)
		_tile_buttons[index].modulate = _COLOR_SELECTED

	_confirm_button.disabled = _selected_indices.size() != _target_indices.size()


func _on_confirm_pressed() -> void:
	_accepting_input = false
	_confirm_button.disabled = true
	for tile in _tile_buttons:
		tile.disabled = true

	var success: bool = _selections_match_target()
	var result_color: Color = _COLOR_CORRECT if success else _COLOR_WRONG
	for i in _target_indices:
		_tile_buttons[i].modulate = result_color

	await get_tree().create_timer(_RESULT_PAUSE_SECONDS).timeout
	finished.emit(success)


func _selections_match_target() -> bool:
	if _selected_indices.size() != _target_indices.size():
		return false
	for i in _selected_indices:
		if not _target_indices.has(i):
			return false
	return true
