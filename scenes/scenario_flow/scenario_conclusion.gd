extends Control
## Plays the active scenario's Day conclusion dialogue, then hands off to ScenarioFlow
## to mark the scenario completed and unlock the next Day. The dialogue itself comes
## entirely from ScenarioDatabase via ScenarioFlow -- nothing is hardcoded here.

@onready var _dialogue_box = %DialogueBox


func _ready() -> void:
	_dialogue_box.play(ScenarioFlow.get_day_conclusion_sequence(), ScenarioFlow.on_scenario_conclusion_finished)
