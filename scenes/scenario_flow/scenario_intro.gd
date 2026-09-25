extends Control
## Plays the active scenario's Day introduction dialogue, then hands off to ScenarioFlow
## to enter the first gameplay phase (tutorial first, if not learned yet). The dialogue
## itself comes entirely from ScenarioDatabase via ScenarioFlow -- nothing is hardcoded
## here.

@onready var _dialogue_box = %DialogueBox


func _ready() -> void:
	_dialogue_box.play(ScenarioFlow.get_day_introduction_sequence(), ScenarioFlow.on_scenario_intro_finished)
