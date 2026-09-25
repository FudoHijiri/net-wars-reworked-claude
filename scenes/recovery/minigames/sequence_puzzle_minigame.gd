extends Control
## Reusable "Sequence Puzzle" repair minigame -- a short Simon-Says-style memory
## challenge. A few placeholder panels flash in order, then the player repeats that
## order by pressing the same panels back. Nothing about the mechanic is threat- or
## component-specific; ScenarioDatabase decides which components use this type, and
## Recovery hands this scene the component name purely so the on-screen text can name
## what's being repaired.

signal finished(success: bool)

const _PAD_COUNT: int = 4
const _SEQUENCE_LENGTH: int = 3
const _FLASH_SECONDS: float = 0.4
const _GAP_SECONDS: float = 0.2
const _RESULT_PAUSE_SECONDS: float = 0.4
const _DIM_FACTOR: float = 0.35

const _PAD_COLORS := [
	Color(0.85, 0.3, 0.3),
	Color(0.3, 0.55, 0.95),
	Color(0.3, 0.8, 0.4),
	Color(0.95, 0.8, 0.2),
]
const _COLOR_WRONG := Color(0.85, 0.3, 0.3)
const _COLOR_CORRECT_STEP := Color(0.3, 0.8, 0.4)

var _component_name: String = ""
var _sequence: Array = []
var _player_step: int = 0
var _accepting_input: bool = false
var _pad_buttons: Array = []

var _instruction_label: Label


func _ready() -> void:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	add_child(rows)

	_instruction_label = Label.new()
	_instruction_label.horizontal_alignment = 1
	_instruction_label.autowrap_mode = 3
	rows.add_child(_instruction_label)

	var pad_row := HBoxContainer.new()
	pad_row.alignment = 1
	pad_row.add_theme_constant_override("separation", 10)
	var pad_center := CenterContainer.new()
	pad_center.add_child(pad_row)
	rows.add_child(pad_center)

	for i in range(_PAD_COUNT):
		var pad := Button.new()
		pad.custom_minimum_size = Vector2(56, 56)
		pad.modulate = _dim(_PAD_COLORS[i])
		pad.pressed.connect(_on_pad_pressed.bind(i))
		pad_row.add_child(pad)
		_pad_buttons.append(pad)


## Recovery calls this once, right after instancing the scene, and again for a retry.
func start(component_name: String) -> void:
	_component_name = component_name
	_instruction_label.text = "Watch the order the panels flash on the %s, then press them back in the same order." % component_name.to_lower()
	_player_step = 0
	_accepting_input = false

	for pad in _pad_buttons:
		pad.disabled = true

	_sequence.clear()
	for i in range(_SEQUENCE_LENGTH):
		_sequence.append(randi() % _PAD_COUNT)

	for step in _sequence:
		_pad_buttons[step].modulate = _PAD_COLORS[step]
		await get_tree().create_timer(_FLASH_SECONDS).timeout
		_pad_buttons[step].modulate = _dim(_PAD_COLORS[step])
		await get_tree().create_timer(_GAP_SECONDS).timeout

	for pad in _pad_buttons:
		pad.disabled = false
	_accepting_input = true


func retry() -> void:
	start(_component_name)


func _on_pad_pressed(index: int) -> void:
	if not _accepting_input:
		return

	if index != _sequence[_player_step]:
		_accepting_input = false
		for pad in _pad_buttons:
			pad.disabled = true
		_pad_buttons[index].modulate = _COLOR_WRONG
		await get_tree().create_timer(_RESULT_PAUSE_SECONDS).timeout
		finished.emit(false)
		return

	_pad_buttons[index].modulate = _COLOR_CORRECT_STEP
	await get_tree().create_timer(_GAP_SECONDS).timeout
	_pad_buttons[index].modulate = _dim(_PAD_COLORS[index])

	_player_step += 1
	if _player_step >= _sequence.size():
		_accepting_input = false
		for pad in _pad_buttons:
			pad.disabled = true
		await get_tree().create_timer(_RESULT_PAUSE_SECONDS).timeout
		finished.emit(true)


func _dim(color: Color) -> Color:
	return Color(color.r * _DIM_FACTOR, color.g * _DIM_FACTOR, color.b * _DIM_FACTOR, 1.0)
