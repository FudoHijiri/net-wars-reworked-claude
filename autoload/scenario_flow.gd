extends Node
## Connects the Scenario Book, GameState, ScenarioDatabase, and the story/dialogue
## system into one continuous Day:
##
##   Day Introduction Story
##   -> [Investigation Tutorial, once per save] -> Investigation
##   -> Between-Objective Story ("investigation_to_monitoring")
##   -> [Monitoring Tutorial] -> Monitoring
##   -> Between-Objective Story ("monitoring_to_hardening")
##   -> [Hardening Tutorial] -> Hardening
##   -> Between-Objective Story ("hardening_to_response")
##   -> [Response Tutorial] -> Response
##   -> Between-Objective Story ("response_to_recovery")
##   -> [Recovery Tutorial] -> Recovery
##   -> Day Conclusion Story -> mark completed -> unlock next Day
##
## All five phases now have real implementations. Every story/tutorial beat is
## presented by the same reusable DialogueBox-driven scenes. This controller only manages story,
## tutorials, objective transitions, Day completion, and unlocking -- it contains no
## gameplay of its own. All persistent state (scenario identity, current_phase,
## tutorial completion) lives in GameState; the small amount of state here is purely
## which story/tutorial/phase scene is currently on screen, always derived from
## GameState rather than tracked independently.

## Fixed phase order plus what each phase needs: the between-objective story that leads
## INTO it (empty for Investigation -- the Day introduction covers that), and whether
## its tutorial is considered "done" as soon as the tutorial dialogue plays (true for
## phases with no real gameplay yet) or only once the phase's own scene finishes
## teaching it interactively (false -- that scene calls GameState.complete_tutorial()
## itself once the player has actually performed the taught actions).
const _PHASE_SEQUENCE: Array[Dictionary] = [
	{"phase_name": "investigation", "story_key": "", "tutorial_completes_on_dialogue": false},
	{"phase_name": "monitoring", "story_key": "investigation_to_monitoring", "tutorial_completes_on_dialogue": false},
	{"phase_name": "hardening", "story_key": "monitoring_to_hardening", "tutorial_completes_on_dialogue": false},
	{"phase_name": "response", "story_key": "hardening_to_response", "tutorial_completes_on_dialogue": false},
	{"phase_name": "recovery", "story_key": "response_to_recovery", "tutorial_completes_on_dialogue": false},
]

## The single swap point per phase: change a path here when a phase gets a real scene,
## nothing else in this controller needs to change.
const _PHASE_SCENES := {
	"investigation": "res://scenes/investigation/investigation.tscn",
	"monitoring": "res://scenes/monitoring/monitoring.tscn",
	"hardening": "res://scenes/hardening/hardening.tscn",
	"response": "res://scenes/response/response.tscn",
	"recovery": "res://scenes/recovery/recovery.tscn",
}

const SCENARIO_INTRO_SCENE := "res://scenes/scenario_flow/scenario_intro.tscn"
const BETWEEN_OBJECTIVE_STORY_SCENE := "res://scenes/scenario_flow/between_objective_story.tscn"
const TUTORIAL_BEAT_SCENE := "res://scenes/scenario_flow/tutorial_beat.tscn"
const SCENARIO_CONCLUSION_SCENE := "res://scenes/scenario_flow/scenario_conclusion.tscn"
const SCENARIO_BOOK_SCENE := "res://scenes/menus/scenario_book.tscn"


## Called when the player selects a Day in the Scenario Book. Starts the scenario in
## GameState and plays its Day introduction.
func begin_scenario(day: int) -> void:
	var scenario: Dictionary = ScenarioDatabase.get_scenario_for_day(day)
	if scenario.is_empty():
		return
	GameState.start_scenario(scenario.get("id", ""), day, scenario.get("threat_name", ""))
	get_tree().change_scene_to_file(SCENARIO_INTRO_SCENE)


## Returns the Day introduction sequence for the active scenario.
func get_day_introduction_sequence() -> Dictionary:
	return _build_sequence(_get_story_lines("day_introduction"))


## Called when the Day introduction dialogue finishes. GameState.start_scenario already
## left current_phase at INVESTIGATION -- enter it (tutorial first, if not learned yet).
func on_scenario_intro_finished() -> void:
	_enter_current_phase()


## Called when a phase finishes (a placeholder's Continue button, or a real phase scene
## reporting completion). If Recovery just finished, play the Day conclusion; otherwise
## play the between-objective story leading into the next phase.
func on_phase_complete() -> void:
	if _current_phase_index() >= _PHASE_SEQUENCE.size() - 1:
		get_tree().change_scene_to_file(SCENARIO_CONCLUSION_SCENE)
	else:
		get_tree().change_scene_to_file(BETWEEN_OBJECTIVE_STORY_SCENE)


## Returns the story data for whichever between-objective story is currently pending --
## the one that leads from GameState.current_phase into the next phase.
func get_pending_between_objective_story() -> Dictionary:
	var next_entry: Dictionary = _PHASE_SEQUENCE[_current_phase_index() + 1]
	return _build_sequence(_get_story_lines(next_entry["story_key"]))


## Called when the between-objective story finishes. Advances GameState to the next
## phase, then enters it (tutorial first, if not learned yet).
func on_between_objective_story_finished() -> void:
	GameState.advance_phase()
	_enter_current_phase()


## Returns the tutorial data for GameState.current_phase.
func get_pending_tutorial() -> Dictionary:
	var phase_name: String = _PHASE_SEQUENCE[_current_phase_index()]["phase_name"]
	return _build_sequence(_get_tutorial_lines(phase_name))


## Called when a tutorial beat's dialogue finishes. For phases with no real gameplay
## yet, that dialogue IS the whole tutorial, so it's marked completed here. Phases with
## a real scene (Investigation) mark their own tutorial completed once the player has
## actually performed the taught actions -- see that scene.
func on_tutorial_finished() -> void:
	var entry: Dictionary = _PHASE_SEQUENCE[_current_phase_index()]
	if entry.get("tutorial_completes_on_dialogue", true):
		GameState.complete_tutorial(entry["phase_name"])
	get_tree().change_scene_to_file(_PHASE_SCENES[entry["phase_name"]])


## Returns the Day conclusion sequence for the active scenario.
func get_day_conclusion_sequence() -> Dictionary:
	return _build_sequence(_get_story_lines("day_conclusion"))


## Called when the Day conclusion dialogue finishes. Marks the scenario completed
## (unlocking the next Day) and returns to the Scenario Book.
func on_scenario_conclusion_finished() -> void:
	GameState.complete_scenario()
	get_tree().change_scene_to_file(SCENARIO_BOOK_SCENE)


## Shows the tutorial for the current phase if it hasn't been completed yet on this
## save, otherwise skips straight to that phase's scene.
func _enter_current_phase() -> void:
	var phase_name: String = _PHASE_SEQUENCE[_current_phase_index()]["phase_name"]
	if GameState.is_tutorial_completed(phase_name):
		get_tree().change_scene_to_file(_PHASE_SCENES[phase_name])
	else:
		get_tree().change_scene_to_file(TUTORIAL_BEAT_SCENE)


func _current_phase_index() -> int:
	var phase_name: String = GameState.get_phase_name().to_lower()
	for i in range(_PHASE_SEQUENCE.size()):
		if _PHASE_SEQUENCE[i]["phase_name"] == phase_name:
			return i
	return 0


func _get_story_lines(story_key: String) -> Array:
	var scenario: Dictionary = ScenarioDatabase.get_scenario_by_id(GameState.scenario_id)
	var story: Dictionary = scenario.get("story", {})
	return story.get(story_key, [{"speaker": "Analyst", "text": "...", "position": "left"}])


func _get_tutorial_lines(phase_name: String) -> Array:
	var scenario: Dictionary = ScenarioDatabase.get_scenario_by_id(GameState.scenario_id)
	var tutorials: Dictionary = scenario.get("tutorials", {})
	return tutorials.get(phase_name, [{"speaker": "Analyst", "text": "(Tutorial placeholder)", "position": "left"}])


func _build_sequence(lines: Array) -> Dictionary:
	return {"background": null, "lines": lines}
