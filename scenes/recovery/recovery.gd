extends Control
## Recovery phase: a short repair/restoration minigame. The player inspects the network,
## selects a component Response damaged, and plays a brief placeholder repair challenge
## to restore it. All scenario-specific content -- which minigame "type" flavors a given
## component -- comes from ScenarioDatabase.get_scenario_by_id(GameState.scenario_id)
## .recovery. Each type is a small, reusable, non-technical minigame (see
## scenes/recovery/minigames/); a component whose configured type has no matching entry
## in _MINIGAME_SCRIPTS falls back to a generic "pick the correct option" placeholder, so
## new types can be added later without ever touching this controller. Nothing about a
## specific threat is hardcoded here.
##
## Required input (read from GameState, set by Response): damaged_components,
## system_integrity. Required output: repaired_components, growing until
## GameState.all_damaged_components_repaired() is true.

## Registry of real minigame types -> the reusable script that implements them. Every
## script here exposes the same small contract: start(component_name), retry(), and a
## finished(success) signal. A component whose scenario data names a type not listed
## here (e.g. still-placeholder "connection_path"/"timing_rhythm") uses the generic
## fallback further down instead.
const _MINIGAME_SCRIPTS := {
	"pattern_matching": preload("res://scenes/recovery/minigames/pattern_matching_minigame.gd"),
	"sequence_puzzle": preload("res://scenes/recovery/minigames/sequence_puzzle_minigame.gd"),
}

const _OPTION_COUNT: int = 3

const _TUTORIAL_HINTS := [
	"These are the components damaged during the incident. Select one to start repairing it.",
	"Pick the option that correctly fixes the problem. Guess wrong and you can just retry.",
	"A successful repair restores the component -- keep going until everything is fixed.",
]

@onready var _hint_banner: Control = %HintBanner
@onready var _hint_label: Label = %HintLabel

@onready var _network_view: Control = %NetworkView
@onready var _component_list: VBoxContainer = %ComponentList
@onready var _progress_label: Label = %ProgressLabel

@onready var _minigame_panel: Control = %MinigamePanel
@onready var _minigame_title_label: Label = %MinigameTitleLabel
@onready var _instruction_label: Label = %InstructionLabel
@onready var _minigame_content: VBoxContainer = %MinigameContent
@onready var _options_row: HBoxContainer = %OptionsRow
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _retry_button: Button = %RetryButton
@onready var _close_minigame_button: Button = %CloseMinigameButton

@onready var _complete_panel: Control = %CompletePanel
@onready var _summary_label: Label = %SummaryLabel
@onready var _continue_button: Button = %ContinueButton

var _recovery_data: Dictionary = {}
var _current_component: String = ""
var _correct_option_index: int = -1

## Non-null while a real minigame (see _MINIGAME_SCRIPTS) is running in
## _minigame_content; null while the generic fallback (_options_row) is in use.
var _active_minigame: Control = null

var _tutorial_active: bool = false
var _tutorial_step: int = 0


func _ready() -> void:
	var scenario: Dictionary = ScenarioDatabase.get_scenario_by_id(GameState.scenario_id)
	_recovery_data = scenario.get("recovery", {})

	_retry_button.pressed.connect(_on_retry_pressed)
	_close_minigame_button.pressed.connect(_show_network_view)
	_continue_button.pressed.connect(_on_continue_pressed)

	_tutorial_active = not GameState.recovery_tutorial_completed
	_update_hint_banner()

	_minigame_panel.visible = false
	_complete_panel.visible = false

	_show_network_view()
	_check_recovery_complete()


func _minigame_data_for(component_name: String) -> Dictionary:
	var default_data := {"type": "generic", "label": "Generic Repair"}
	return _recovery_data.get("minigame_types", {}).get(component_name, default_data)


func _component_state(component_name: String) -> String:
	if GameState.is_component_repaired(component_name):
		return "RESTORED"
	if GameState.is_component_damaged(component_name):
		return "DAMAGED"
	return "SAFE"


func _show_network_view() -> void:
	_clear_active_minigame()
	_populate_component_list()
	_update_progress_label()
	_network_view.visible = true
	_minigame_panel.visible = false


func _populate_component_list() -> void:
	for child in _component_list.get_children():
		child.free()

	for component_name in GameState.NETWORK_COMPONENTS:
		var state: String = _component_state(component_name)
		var button := Button.new()
		button.text = "%s -- %s" % [component_name, state]
		button.disabled = state != "DAMAGED"
		if state == "DAMAGED":
			button.pressed.connect(_on_component_selected.bind(component_name))
		_component_list.add_child(button)


func _update_progress_label() -> void:
	var damaged_count: int = GameState.damaged_components.size()
	var repaired_count: int = 0
	for entry in GameState.damaged_components:
		if GameState.is_component_repaired(String(entry.get("name", ""))):
			repaired_count += 1
	_progress_label.text = "Repaired: %d / %d damaged components" % [repaired_count, damaged_count]


func _on_component_selected(component_name: String) -> void:
	_clear_active_minigame()

	_current_component = component_name
	_minigame_title_label.text = "REPAIRING: %s" % component_name.to_upper()
	_feedback_label.text = ""
	_retry_button.visible = false

	_network_view.visible = false
	_minigame_panel.visible = true

	var minigame_data: Dictionary = _minigame_data_for(component_name)
	var minigame_script: GDScript = _MINIGAME_SCRIPTS.get(minigame_data.get("type", "generic"), null)

	if minigame_script != null:
		_instruction_label.visible = false
		_options_row.visible = false
		_start_real_minigame(minigame_script, component_name)
	else:
		_instruction_label.visible = true
		_options_row.visible = true
		_instruction_label.text = "%s -- choose the option that correctly fixes this component." % String(minigame_data.get("label", "Generic Repair"))
		_start_minigame_attempt()

	_advance_tutorial(0)


## Real minigame path (see _MINIGAME_SCRIPTS): instances the reusable minigame script
## into _minigame_content and lets it run its own self-contained challenge.
func _start_real_minigame(minigame_script: GDScript, component_name: String) -> void:
	_active_minigame = minigame_script.new()
	_minigame_content.add_child(_active_minigame)
	_active_minigame.finished.connect(_on_real_minigame_finished)
	_active_minigame.start(component_name)


func _on_real_minigame_finished(success: bool) -> void:
	_advance_tutorial(1)

	if not success:
		_feedback_label.text = "That wasn't the right fix. Try again."
		_retry_button.visible = true
		return

	_feedback_label.text = "Repair successful! %s restored." % _current_component
	_retry_button.visible = false
	GameState.repair_component(_current_component)
	_advance_tutorial(2)

	await get_tree().create_timer(0.6).timeout
	_show_network_view()
	_check_recovery_complete()


func _clear_active_minigame() -> void:
	if _active_minigame != null:
		_active_minigame.queue_free()
		_active_minigame = null


## Generic fallback path, used for any component whose configured minigame type has no
## real implementation yet in _MINIGAME_SCRIPTS: pick the correct option out of three.
func _start_minigame_attempt() -> void:
	for child in _options_row.get_children():
		child.free()

	_correct_option_index = randi() % _OPTION_COUNT
	for i in range(_OPTION_COUNT):
		var button := Button.new()
		button.text = "Option %d" % (i + 1)
		button.pressed.connect(_on_option_selected.bind(i))
		_options_row.add_child(button)


func _on_option_selected(index: int) -> void:
	_advance_tutorial(1)

	if index != _correct_option_index:
		_feedback_label.text = "That wasn't the right fix. Try again."
		for child in _options_row.get_children():
			child.disabled = true
		_retry_button.visible = true
		return

	_feedback_label.text = "Repair successful! %s restored." % _current_component
	for child in _options_row.get_children():
		child.disabled = true
	_retry_button.visible = false
	GameState.repair_component(_current_component)
	_advance_tutorial(2)

	await get_tree().create_timer(0.6).timeout
	_show_network_view()
	_check_recovery_complete()


func _on_retry_pressed() -> void:
	_feedback_label.text = ""
	_retry_button.visible = false
	if _active_minigame != null:
		_active_minigame.retry()
	else:
		_start_minigame_attempt()


func _check_recovery_complete() -> bool:
	if not GameState.all_damaged_components_repaired():
		return false
	_finish_recovery()
	return true


func _finish_recovery() -> void:
	_clear_active_minigame()

	if _tutorial_active:
		_tutorial_active = false
		GameState.complete_tutorial("recovery")
		_update_hint_banner()

	_network_view.visible = false
	_minigame_panel.visible = false
	_complete_panel.visible = true
	_summary_label.text = "All damaged components have been restored.\nSystem Integrity: %d / %d." % [GameState.system_integrity, GameState.max_system_integrity]


func _on_continue_pressed() -> void:
	if _tutorial_active:
		_tutorial_active = false
		GameState.complete_tutorial("recovery")
	ScenarioFlow.on_phase_complete()


func _advance_tutorial(step_just_done: int) -> void:
	if not _tutorial_active or step_just_done != _tutorial_step:
		return
	_tutorial_step += 1
	if _tutorial_step >= _TUTORIAL_HINTS.size():
		_tutorial_active = false
		GameState.complete_tutorial("recovery")
	_update_hint_banner()


func _update_hint_banner() -> void:
	_hint_banner.visible = _tutorial_active
	if _tutorial_active:
		_hint_label.text = _TUTORIAL_HINTS[_tutorial_step]
