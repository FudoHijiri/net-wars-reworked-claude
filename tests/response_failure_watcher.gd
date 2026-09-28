extends Node
## Integration test for the Response FAILURE path -- the progression fix this task
## implements. Drives a real Day 1 playthrough exactly like
## tests/scenario_flow_watcher.gd's success run, but forces System Integrity to 0 in
## Response instead of winning, then verifies:
##
##   Response fails (threat_defeated=false, response_result="system_compromised")
##   -> between-objective story (not bypassed)
##   -> Recovery still runs and can still be completed
##   -> the Day Conclusion plays the scenario's "failure_conclusion" story, not the
##      success "day_conclusion" story
##   -> GameState.complete_scenario() is NOT invoked: the Day is NOT marked completed
##      and Day 2 remains LOCKED
##   -> back at the Scenario Book, Day 1 is still "???" (not revealed) but remains
##      selectable, and replaying it works (tutorials, already completed this run,
##      are skipped on the retry)
##
## Not part of the shipped game.

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
	var day1: Button = book.get_node("%DayList").get_child(0)
	day1.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	var scene := get_tree().current_scene
	await _finish_dialogue(scene)  # Day intro -> Investigation Tutorial dialogue
	scene = get_tree().current_scene
	await _finish_dialogue(scene)  # -> real Investigation scene

	var investigation = get_tree().current_scene
	await _complete_investigation(investigation, "Credential Abuse")
	scene = get_tree().current_scene
	await _finish_dialogue(scene)  # investigation_to_monitoring story -> Monitoring Tutorial dialogue
	scene = get_tree().current_scene
	await _finish_dialogue(scene)  # -> real Monitoring scene

	var monitoring = get_tree().current_scene
	monitoring._end_monitoring()
	monitoring.get_node("%ContinueButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	await _finish_dialogue(scene)  # monitoring_to_hardening story -> Hardening Tutorial dialogue
	scene = get_tree().current_scene
	await _finish_dialogue(scene)  # -> real Hardening scene

	var hardening = get_tree().current_scene
	hardening.get_node("%ConfirmButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	await _finish_dialogue(scene)  # hardening_to_response story -> Response Tutorial dialogue
	scene = get_tree().current_scene
	await _finish_dialogue(scene)  # -> real Response scene

	# ================= Force a Response FAILURE =================
	var response = get_tree().current_scene
	_check("Response scene reached", response != null and response.scene_file_path == RESPONSE)

	# Drive System Integrity to 0 through the same production entry point Response's own
	# boss-intent damage uses, so a real damaged component is recorded for Recovery to
	# repair -- exactly what a real lost fight would leave behind.
	GameState.take_system_damage(GameState.system_integrity, "Server")
	response._check_win_loss()

	_check("[failure] threat_defeated is false", not GameState.threat_defeated)
	_check("[failure] response_result is system_compromised", GameState.response_result == "system_compromised")
	_check("[failure] result panel shown", response.get_node("%ResultPanel").visible)
	_check("[failure] result label announces defeat", response.get_node("%ResultLabel").text == "SYSTEM COMPROMISED")
	_check("[failure] a real damaged component was recorded", GameState.is_component_damaged("Server"))

	response.get_node("%ContinueButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	# ================= Failure must still proceed through Recovery, not bypass it =================
	scene = get_tree().current_scene
	_check("[failure] Response failure leads to a between-objective story (not skipped)", scene != null and scene.scene_file_path == BETWEEN_OBJECTIVE_STORY)
	await _finish_dialogue(scene)

	scene = get_tree().current_scene
	_check("[failure] Recovery Tutorial dialogue plays before the real scene", scene != null and scene.scene_file_path == TUTORIAL_BEAT)
	await _finish_dialogue(scene)

	var recovery = get_tree().current_scene
	_check("[failure] failed Response still reaches the real Recovery scene", recovery != null and recovery.scene_file_path == RECOVERY)
	_check("[failure] Recovery has the damage from the lost fight to repair", not GameState.damaged_components.is_empty())

	await _complete_recovery(recovery)
	_check("[failure] Recovery can still be completed after a loss", GameState.all_damaged_components_repaired())

	recovery.get_node("%ContinueButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	# ================= Day Conclusion must use the FAILURE story, not the success one =================
	scene = get_tree().current_scene
	_check("[failure] Recovery leads to the Day Conclusion (not skipped)", scene != null and scene.scene_file_path == SCENARIO_CONCLUSION)

	var expected_failure_lines: Array = ScenarioDatabase.get_scenario_by_id("credential_abuse").get("story", {}).get("failure_conclusion", [])
	_check("[failure] credential_abuse defines real failure_conclusion content", not expected_failure_lines.is_empty())

	var dialogue_box = scene.get_node("%DialogueBox")
	_check("[failure] the failure_conclusion dialogue (not the success one) is shown", dialogue_box.current_line.get("text", "") == expected_failure_lines[0].get("text", ""))

	await _finish_dialogue(scene)

	# ================= A failed Day must NOT be recorded as completed =================
	scene = get_tree().current_scene
	_check("[failure] Day Conclusion returns to the Scenario Book", scene != null and scene.scene_file_path == SCENARIO_BOOK)
	_check("[failure] GameState.complete_scenario() was NOT called: Day 1 not marked completed", not GameState.is_scenario_completed("credential_abuse"))
	_check("[failure] Day 2 remains locked", not GameState.is_day_unlocked(2))

	var day_list = scene.get_node("%DayList")
	_check("[failure] Scenario Book still shows 'Day 1 - ???' (threat not revealed)", day_list.get_child(0).text == "Day 1 - ???")
	_check("[failure] Day 2 still shows LOCKED", day_list.get_child(1).text == "Day 2 - LOCKED" and day_list.get_child(1).disabled)

	# ================= A failed Day must remain selectable/replayable =================
	var day1_retry: Button = day_list.get_child(0)
	_check("[failure] Day 1 remains selectable after a failure (not locked out)", not day1_retry.disabled)

	day1_retry.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	_check("[failure] Day 1 can be re-entered after failing it", scene != null and scene.scene_file_path == SCENARIO_INTRO)
	await _finish_dialogue(scene)

	scene = get_tree().current_scene
	_check("[failure] retrying skips the Investigation tutorial (already completed this run)", scene != null and scene.scene_file_path == INVESTIGATION)
	_check("[failure] no tutorial hints shown on retry", not scene.get_node("%HintBanner").visible)

	print("=== RESPONSE FAILURE TEST COMPLETE ===")
	get_tree().quit()


## Drives the real Investigation scene just far enough to succeed. Identical logic to
## tests/scenario_flow_watcher.gd's helper of the same name -- Investigation's own
## detailed evidence/tutorial behavior is covered in depth by tests/investigation_watcher.gd.
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


## Repairs every damaged component via the real component-select -> minigame -> success
## flow. Identical logic to tests/scenario_flow_watcher.gd's helpers of the same names --
## the Retry path and each minigame's own internals are covered in depth by
## tests/recovery_watcher.gd and tests/recovery_minigames_watcher.gd.
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


func _check(label: String, condition: bool) -> void:
	print("[PASS] %s" % label if condition else "[FAIL] %s" % label)
