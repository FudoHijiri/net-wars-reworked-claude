extends Node
## Automated end-to-end test of the scenario flow controller's full Day 1 tutorial flow:
##
##   Scenario Book -> select Day 1 -> Day Introduction -> Investigation Tutorial ->
##   Investigation (real scene) -> Story -> Monitoring Tutorial -> Monitoring (real
##   scene) -> Story -> Hardening Tutorial -> Hardening Placeholder -> Story -> Response
##   Tutorial -> Response Placeholder -> Story -> Recovery Tutorial -> Recovery
##   Placeholder -> Day Conclusion -> Day 1 Complete -> Day 2 Unlocked
##
## Then verifies that starting Day 2 (all five tutorials now completed) skips every
## tutorial and goes straight from each between-objective story to its phase scene.
## Investigation's and Monitoring's own detailed behavior is covered in depth by
## tests/investigation_watcher.gd and tests/monitoring_watcher.gd -- this test only
## drives them far enough to confirm the overall Day flow still stitches together
## correctly. Not part of the shipped game.

const SCENARIO_INTRO := "res://scenes/scenario_flow/scenario_intro.tscn"
const TUTORIAL_BEAT := "res://scenes/scenario_flow/tutorial_beat.tscn"
const INVESTIGATION := "res://scenes/investigation/investigation.tscn"
const MONITORING := "res://scenes/monitoring/monitoring.tscn"
const HARDENING := "res://scenes/hardening/hardening.tscn"
const RESPONSE := "res://scenes/response/response.tscn"
const RECOVERY := "res://scenes/recovery/recovery.tscn"
const BETWEEN_OBJECTIVE_STORY := "res://scenes/scenario_flow/between_objective_story.tscn"
const SCENARIO_CONCLUSION := "res://scenes/scenario_flow/scenario_conclusion.tscn"
const SCENARIO_BOOK := "res://scenes/menus/scenario_book.tscn"


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var book = get_tree().current_scene
	_check("Scenario Book launched", book != null and book.scene_file_path == SCENARIO_BOOK)

	var day_list = book.get_node("%DayList")
	var day1: Button = day_list.get_child(0)
	day1.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	var scene := get_tree().current_scene
	_check("selecting Day 1 opens the Day Introduction", scene != null and scene.scene_file_path == SCENARIO_INTRO)
	_check("GameState started the scenario", GameState.scenario_id == "credential_abuse" and GameState.current_day == 1)

	await _finish_dialogue(scene)

	# --- Investigation: real scene, driven just far enough to complete it ---
	scene = get_tree().current_scene
	_check("Investigation: tutorial not yet completed -> Tutorial Beat shown", scene != null and scene.scene_file_path == TUTORIAL_BEAT)
	_check("Investigation tutorial not marked completed yet", not GameState.is_tutorial_completed("investigation"))

	await _finish_dialogue(scene)
	scene = get_tree().current_scene
	_check("Investigation Tutorial leads to the real Investigation scene", scene != null and scene.scene_file_path == INVESTIGATION)

	await _complete_investigation(scene, "Credential Abuse")
	_check("Investigation tutorial marked completed after playing it", GameState.is_tutorial_completed("investigation"))

	scene = get_tree().current_scene
	_check("Investigation leads to a between-objective Story", scene != null and scene.scene_file_path == BETWEEN_OBJECTIVE_STORY)
	await _finish_dialogue(scene)

	# --- Monitoring: real scene, driven just far enough to complete it ---
	scene = get_tree().current_scene
	_check("Monitoring: tutorial not yet completed -> Tutorial Beat shown", scene != null and scene.scene_file_path == TUTORIAL_BEAT)
	_check("Monitoring tutorial not marked completed yet", not GameState.is_tutorial_completed("monitoring"))

	await _finish_dialogue(scene)
	scene = get_tree().current_scene
	_check("Monitoring Tutorial leads to the real Monitoring scene", scene != null and scene.scene_file_path == MONITORING)

	_complete_monitoring(scene)
	_check("Monitoring tutorial marked completed after ending the session", GameState.is_tutorial_completed("monitoring"))
	scene.get_node("%ContinueButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	_check("Monitoring leads to a between-objective Story", scene != null and scene.scene_file_path == BETWEEN_OBJECTIVE_STORY)
	await _finish_dialogue(scene)

	# --- Hardening: real scene, driven just far enough to complete it ---
	scene = get_tree().current_scene
	_check("Hardening: tutorial not yet completed -> Tutorial Beat shown", scene != null and scene.scene_file_path == TUTORIAL_BEAT)
	_check("Hardening tutorial not marked completed yet", not GameState.is_tutorial_completed("hardening"))

	await _finish_dialogue(scene)
	scene = get_tree().current_scene
	_check("Hardening Tutorial leads to the real Hardening scene", scene != null and scene.scene_file_path == HARDENING)

	_complete_hardening(scene)
	_check("Hardening tutorial marked completed after confirming", GameState.is_tutorial_completed("hardening"))
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	_check("Hardening leads to a between-objective Story", scene != null and scene.scene_file_path == BETWEEN_OBJECTIVE_STORY)
	await _finish_dialogue(scene)

	# --- Response: real scene, driven just far enough to complete it ---
	scene = get_tree().current_scene
	_check("Response: tutorial not yet completed -> Tutorial Beat shown", scene != null and scene.scene_file_path == TUTORIAL_BEAT)
	_check("Response tutorial not marked completed yet", not GameState.is_tutorial_completed("response"))

	await _finish_dialogue(scene)
	scene = get_tree().current_scene
	_check("Response Tutorial leads to the real Response scene", scene != null and scene.scene_file_path == RESPONSE)

	_complete_response(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("Response tutorial marked completed after winning", GameState.is_tutorial_completed("response"))

	scene = get_tree().current_scene
	_check("Response leads to a between-objective Story", scene != null and scene.scene_file_path == BETWEEN_OBJECTIVE_STORY)
	await _finish_dialogue(scene)

	# --- Recovery: real scene, driven just far enough to complete it ---
	scene = get_tree().current_scene
	_check("Recovery: tutorial not yet completed -> Tutorial Beat shown", scene != null and scene.scene_file_path == TUTORIAL_BEAT)
	_check("Recovery tutorial not marked completed yet", not GameState.is_tutorial_completed("recovery"))

	await _finish_dialogue(scene)
	scene = get_tree().current_scene
	_check("Recovery Tutorial leads to the real Recovery scene", scene != null and scene.scene_file_path == RECOVERY)
	_check("Recovery has at least one damaged component to repair", not GameState.damaged_components.is_empty())

	await _complete_recovery(scene)
	_check("Recovery tutorial marked completed after repairing", GameState.is_tutorial_completed("recovery"))
	_check("all damaged components repaired", GameState.all_damaged_components_repaired())

	scene.get_node("%ContinueButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	_check("Recovery leads to the Day Conclusion", scene != null and scene.scene_file_path == SCENARIO_CONCLUSION)
	_check("scenario not yet marked completed during conclusion", not GameState.is_scenario_completed("credential_abuse"))

	await _finish_dialogue(scene)
	scene = get_tree().current_scene
	_check("Day Conclusion returns to the Scenario Book", scene != null and scene.scene_file_path == SCENARIO_BOOK)
	_check("Day 1 marked completed", GameState.is_scenario_completed("credential_abuse"))
	_check("Day 2 unlocked", GameState.is_day_unlocked(2))

	day_list = scene.get_node("%DayList")
	_check("book shows Day 1 threat name revealed", day_list.get_child(0).text == "Day 1 - Credential Abuse")
	_check("book shows Day 2 as selectable", day_list.get_child(1).text == "Day 2 - ???" and not day_list.get_child(1).disabled)

	# --- Day 2: every tutorial is already completed, so none of them should reappear. ---
	var day2: Button = day_list.get_child(1)
	day2.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	_check("Day 2: selecting it opens its Day Introduction", scene != null and scene.scene_file_path == SCENARIO_INTRO)
	_check("GameState started Day 2", GameState.scenario_id == "malware" and GameState.current_day == 2)

	await _finish_dialogue(scene)
	scene = get_tree().current_scene
	_check("Day 2 Investigation: tutorial already completed -> straight to the real scene", scene != null and scene.scene_file_path == INVESTIGATION)
	_check("Day 2 Investigation: no tutorial hints shown", not scene.get_node("%HintBanner").visible)

	await _complete_investigation(scene, "Malware")
	scene = get_tree().current_scene
	_check("Day 2 Investigation leads to a between-objective Story", scene != null and scene.scene_file_path == BETWEEN_OBJECTIVE_STORY)

	await _finish_dialogue(scene)
	scene = get_tree().current_scene
	_check("Day 2 Monitoring: tutorial already completed -> straight to the real scene", scene != null and scene.scene_file_path == MONITORING)
	_check("Day 2 Monitoring: no tutorial hints shown", not scene.get_node("%HintBanner").visible)

	_complete_monitoring(scene)
	scene.get_node("%ContinueButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	_check("Day 2 Monitoring leads to a between-objective Story", scene != null and scene.scene_file_path == BETWEEN_OBJECTIVE_STORY)

	await _finish_dialogue(scene)
	scene = get_tree().current_scene
	_check("Day 2 Hardening: tutorial already completed -> straight to the real scene", scene != null and scene.scene_file_path == HARDENING)
	_check("Day 2 Hardening: no tutorial hints shown", not scene.get_node("%HintBanner").visible)

	_complete_hardening(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	scene = get_tree().current_scene
	_check("Day 2 Hardening leads to a between-objective Story", scene != null and scene.scene_file_path == BETWEEN_OBJECTIVE_STORY)

	await _finish_dialogue(scene)
	scene = get_tree().current_scene
	_check("Day 2 Response: tutorial already completed -> straight to the real scene", scene != null and scene.scene_file_path == RESPONSE)
	_check("Day 2 Response: no tutorial hints shown", not scene.get_node("%HintBanner").visible)

	_complete_response(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	scene = get_tree().current_scene
	_check("Day 2 Response leads to a between-objective Story", scene != null and scene.scene_file_path == BETWEEN_OBJECTIVE_STORY)

	await _finish_dialogue(scene)
	scene = get_tree().current_scene
	_check("Day 2 Recovery: tutorial already completed -> straight to the real scene", scene != null and scene.scene_file_path == RECOVERY)
	_check("Day 2 Recovery: no tutorial hints shown", not scene.get_node("%HintBanner").visible)

	await _complete_recovery(scene)
	scene.get_node("%ContinueButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	_check("Day 2 Recovery leads to the Day Conclusion", scene != null and scene.scene_file_path == SCENARIO_CONCLUSION)

	print("=== SCENARIO FLOW TEST COMPLETE ===")
	get_tree().quit()


## Drives the real Investigation scene just far enough to succeed: marks every entry
## the active scenario's data flags as real evidence (there may be none, for scenarios
## without investigation data yet), then confirms the given (correct) threat.
## Investigation's own detailed evidence/tutorial behavior is covered in depth by
## tests/investigation_watcher.gd -- this only needs to reach a real success.
func _complete_investigation(investigation: Node, correct_threat: String) -> void:
	var scenario: Dictionary = ScenarioDatabase.get_scenario_by_id(GameState.scenario_id)
	var applications: Dictionary = scenario.get("investigation", {}).get("applications", {})

	for app_key in ["email", "logs", "computers", "login_activity", "files", "network", "servers", "reports"]:
		var entries: Array = applications.get(app_key, [])
		var has_evidence := false
		for entry in entries:
			if entry.get("is_evidence", false):
				has_evidence = true
				break
		if not has_evidence:
			continue

		var button_name: String = app_key.capitalize().replace(" ", "") + "Button"
		investigation.get_node("%" + button_name).pressed.emit()
		var entry_list: VBoxContainer = investigation.get_node("%EntryList")
		for i in range(entry_list.get_child_count()):
			if entries[i].get("is_evidence", false):
				entry_list.get_child(i).pressed.emit()
				investigation.get_node("%MarkEvidenceButton").pressed.emit()
		investigation.get_node("%CloseAppButton").pressed.emit()

	investigation.get_node("%EvidenceLogButton").pressed.emit()
	investigation.get_node("%CloseEvidenceButton").pressed.emit()

	investigation.get_node("%ConfirmThreatButton").pressed.emit()
	for child in investigation.get_node("%ThreatList").get_children():
		if child is Button and child.text == correct_threat:
			child.pressed.emit()
			break
	investigation.get_node("%ConfirmButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame


## Ends the real Monitoring scene immediately rather than waiting out its real-time
## countdown -- Monitoring's own detailed scoring/tutorial/spawning behavior is covered
## in depth by tests/monitoring_watcher.gd; this only needs to reach completion.
func _complete_monitoring(monitoring: Node) -> void:
	monitoring._end_monitoring()


## Confirms Hardening immediately without purchasing anything -- a valid loadout never
## requires any purchases (the base deck alone is enough to confirm). Hardening's own
## detailed shop/purchase/tutorial behavior is covered in depth by
## tests/hardening_watcher.gd; this only needs to reach completion.
func _complete_hardening(hardening: Node) -> void:
	hardening.get_node("%ConfirmButton").pressed.emit()


## Wins the real Response scene almost immediately rather than playing out a full
## multi-turn match -- Response's own detailed card-play/intent/tutorial behavior is
## covered in depth by tests/response_watcher.gd. Ends one real turn first (so Recovery
## actually has a real damaged component to work with) before forcing the win.
func _complete_response(response: Node) -> void:
	response.get_node("%EndTurnButton").pressed.emit()
	response.containment = 100
	response._check_win_loss()
	response.get_node("%ContinueButton").pressed.emit()


## Drives the real Recovery scene just far enough to complete it: repairs every
## damaged component via the real component-select -> minigame -> success flow, always
## succeeding on the first attempt. Which minigame type that is (a real one from
## scenes/recovery/minigames/, or the generic fallback) depends on which components
## Response happened to damage -- see _solve_current_minigame below. The Retry path and
## each minigame's own internals are covered in depth by tests/recovery_watcher.gd and
## tests/recovery_minigames_watcher.gd; this only needs to reach completion.
func _complete_recovery(recovery: Node) -> void:
	while not GameState.all_damaged_components_repaired():
		var damaged_button: Button = null
		for child in recovery.get_node("%ComponentList").get_children():
			if not child.disabled:
				damaged_button = child
				break
		if damaged_button == null:
			break
		damaged_button.pressed.emit()
		await get_tree().process_frame
		await _solve_current_minigame(recovery)
		await get_tree().create_timer(0.7).timeout
		await get_tree().process_frame


## Succeeds whichever minigame Recovery is currently showing on the first attempt.
func _solve_current_minigame(recovery: Node) -> void:
	var game = recovery._active_minigame

	if game == null:
		recovery.get_node("%OptionsRow").get_children()[recovery._correct_option_index].pressed.emit()
		return

	if "_target_indices" in game:
		await get_tree().create_timer(1.2).timeout
		for i in game._target_indices:
			game._tile_buttons[i].pressed.emit()
		game._confirm_button.pressed.emit()
		await get_tree().create_timer(1.2).timeout
	else:
		await get_tree().create_timer(2.3).timeout
		for step in game._sequence:
			game._pad_buttons[step].pressed.emit()
			await get_tree().create_timer(0.35).timeout
		await get_tree().create_timer(1.2).timeout


func _finish_dialogue(scene: Node) -> void:
	var dialogue_box = scene.get_node("%DialogueBox")
	dialogue_box.skip()
	await get_tree().process_frame
	await get_tree().process_frame


func _continue_phase(scene: Node) -> void:
	var continue_button: Button = scene.get_node("%ContinueButton")
	continue_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame


func _check(label: String, condition: bool) -> void:
	print("[PASS] %s" % label if condition else "[FAIL] %s" % label)
