extends Control
## Plays the tutorial for whichever phase GameState.current_phase names (via
## ScenarioFlow), then marks it completed and hands off to the phase's placeholder.
## Reused for all five phase tutorials (Investigation/Monitoring/Hardening/Response/
## Recovery) -- ScenarioFlow only routes here when that phase's tutorial hasn't been
## completed yet, so this scene never needs to check that itself.

@onready var _dialogue_box = %DialogueBox


func _ready() -> void:
	_dialogue_box.play(ScenarioFlow.get_pending_tutorial(), ScenarioFlow.on_tutorial_finished)
