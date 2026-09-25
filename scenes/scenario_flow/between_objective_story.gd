extends Control
## Plays whichever between-objective story is currently pending (determined by
## GameState.current_phase via ScenarioFlow), then hands off to ScenarioFlow to advance
## to the next phase. Reused for all four between-objective transitions
## (investigation_to_monitoring, monitoring_to_hardening, hardening_to_response,
## response_to_recovery) -- the dialogue itself always comes from ScenarioDatabase.

@onready var _dialogue_box = %DialogueBox


func _ready() -> void:
	_dialogue_box.play(ScenarioFlow.get_pending_between_objective_story(), ScenarioFlow.on_between_objective_story_finished)
