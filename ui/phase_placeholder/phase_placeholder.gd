extends Control
## Placeholder for one of the five gameplay phases (Investigation/Monitoring/Hardening/
## Response/Recovery). Shows which phase is active by reading GameState directly, and a
## Continue button that hands off to ScenarioFlow to advance. This is the single swap
## point per phase: building a real phase scene later only means changing which scene
## ScenarioFlow loads for that step, not this file or the flow sequencing.

@onready var _heading_label: Label = %HeadingLabel
@onready var _message_label: Label = %MessageLabel
@onready var _continue_button: Button = %ContinueButton


func _ready() -> void:
	_heading_label.text = GameState.get_phase_name().capitalize()
	_message_label.text = "This phase isn't implemented yet."
	_continue_button.pressed.connect(_on_continue_pressed)


func _on_continue_pressed() -> void:
	ScenarioFlow.on_phase_complete()
