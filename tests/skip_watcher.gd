extends Node
## Dedicated verification that the Skip button terminates the ENTIRE current story
## segment immediately -- not just "the next line" like Continue -- in every listed
## context: Day Introduction, Investigation-to-Monitoring, Monitoring-to-Hardening,
## Hardening-to-Response, Response-to-Recovery, Day Conclusion (success), and Failure
## Conclusion. For each, this advances one line first (so Skip is pressed from mid-
## sequence, matching the reported bug's exact "player is on line 2" scenario), presses
## Skip, and confirms zero further per-line signals fire and the same completion
## callback/next-scene transition happens as reaching the end normally would. Not part
## of the shipped game.

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

	# ---------------- 1. Day Introduction ----------------
	var scene := get_tree().current_scene
	_check("Day Introduction scene reached", scene != null and scene.scene_file_path == SCENARIO_INTRO)
	await _verify_skip_advances_scene("Day Introduction", scene, TUTORIAL_BEAT)

	scene = get_tree().current_scene  # Investigation Tutorial dialogue
	await _skip_dialogue(scene)
	var investigation = get_tree().current_scene
	_check("Investigation reached", investigation != null and investigation.scene_file_path == INVESTIGATION)
	await _complete_investigation(investigation, "Credential Abuse")

	# ---------------- 2. Investigation -> Monitoring ----------------
	scene = get_tree().current_scene
	_check("Investigation-to-Monitoring story reached", scene != null and scene.scene_file_path == BETWEEN_OBJECTIVE_STORY)
	await _verify_skip_advances_scene("Investigation-to-Monitoring", scene, TUTORIAL_BEAT)

	scene = get_tree().current_scene  # Monitoring Tutorial dialogue
	await _skip_dialogue(scene)
	var monitoring = get_tree().current_scene
	_check("Monitoring reached", monitoring != null and monitoring.scene_file_path == MONITORING)
	monitoring._end_monitoring()
	monitoring.get_node("%ContinueButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	# ---------------- 3. Monitoring -> Hardening ----------------
	scene = get_tree().current_scene
	_check("Monitoring-to-Hardening story reached", scene != null and scene.scene_file_path == BETWEEN_OBJECTIVE_STORY)
	await _verify_skip_advances_scene("Monitoring-to-Hardening", scene, TUTORIAL_BEAT)

	scene = get_tree().current_scene  # Hardening Tutorial dialogue
	await _skip_dialogue(scene)
	var hardening = get_tree().current_scene
	_check("Hardening reached", hardening != null and hardening.scene_file_path == HARDENING)
	hardening.get_node("%ConfirmButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	# ---------------- 4. Hardening -> Response ----------------
	scene = get_tree().current_scene
	_check("Hardening-to-Response story reached", scene != null and scene.scene_file_path == BETWEEN_OBJECTIVE_STORY)
	await _verify_skip_advances_scene("Hardening-to-Response", scene, TUTORIAL_BEAT)

	scene = get_tree().current_scene  # Response Tutorial dialogue
	await _skip_dialogue(scene)
	var response = get_tree().current_scene
	_check("Response reached", response != null and response.scene_file_path == RESPONSE)
	response.get_node("%EndTurnButton").pressed.emit()
	response.containment = 100
	response._check_win_loss()
	response.get_node("%ContinueButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	# ---------------- 5. Response -> Recovery ----------------
	scene = get_tree().current_scene
	_check("Response-to-Recovery story reached", scene != null and scene.scene_file_path == BETWEEN_OBJECTIVE_STORY)
	await _verify_skip_advances_scene("Response-to-Recovery", scene, TUTORIAL_BEAT)

	scene = get_tree().current_scene  # Recovery Tutorial dialogue
	await _skip_dialogue(scene)
	var recovery = get_tree().current_scene
	_check("Recovery reached", recovery != null and recovery.scene_file_path == RECOVERY)
	await _complete_recovery(recovery)
	recovery.get_node("%ContinueButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	# ---------------- 6. Day Conclusion (success) ----------------
	scene = get_tree().current_scene
	_check("Day Conclusion (success) reached", scene != null and scene.scene_file_path == SCENARIO_CONCLUSION)
	await _verify_skip_advances_scene("Day Conclusion (success)", scene, SCENARIO_BOOK)

	scene = get_tree().current_scene
	_check("Day 1 completed via Skip path just like Continue would", GameState.is_scenario_completed("credential_abuse"))
	_check("Day 2 unlocked via Skip path just like Continue would", GameState.is_day_unlocked(2))

	# ---------------- 7. Failure Conclusion ----------------
	# Force a fresh Day 1 attempt straight to a loss so the failure_conclusion sequence
	# (which has its own distinct content -- see autoload/scenario_database.gd) can be
	# Skip-tested too, without repeating the whole Day a second time. `scene` is already
	# the current (fresh) Scenario Book instance from the check just above -- `book` was
	# captured at the very start of this run and has since been freed by scene changes.
	day1 = scene.get_node("%DayList").get_child(0)
	day1.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	await _skip_dialogue(scene)  # Day Introduction (tutorials already learned -> straight to Investigation)
	investigation = get_tree().current_scene
	await _complete_investigation(investigation, "Credential Abuse")
	scene = get_tree().current_scene
	await _skip_dialogue(scene)
	monitoring = get_tree().current_scene
	monitoring._end_monitoring()
	monitoring.get_node("%ContinueButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	scene = get_tree().current_scene
	await _skip_dialogue(scene)
	hardening = get_tree().current_scene
	hardening.get_node("%ConfirmButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	scene = get_tree().current_scene
	await _skip_dialogue(scene)
	response = get_tree().current_scene
	GameState.take_system_damage(GameState.system_integrity, "Server")
	response._check_win_loss()
	response.get_node("%ContinueButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	scene = get_tree().current_scene
	await _skip_dialogue(scene)
	recovery = get_tree().current_scene
	await _complete_recovery(recovery)
	recovery.get_node("%ContinueButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	_check("Failure Conclusion reached", scene != null and scene.scene_file_path == SCENARIO_CONCLUSION)
	await _verify_skip_advances_scene("Failure Conclusion", scene, SCENARIO_BOOK)

	print("=== SKIP TEST COMPLETE ===")
	get_tree().quit()


## Advances one line (so Skip fires from mid-sequence, not the very first line), then
## presses Skip and confirms: (a) no further per-line "line_shown" signals fire -- proving
## the remaining lines were never shown one-by-one -- and (b) the same scene transition
## Continue would eventually reach happens immediately.
func _verify_skip_advances_scene(context_label: String, scene: Node, expected_next_scene: String) -> void:
	var dialogue_box = scene.get_node("%DialogueBox")
	var total_lines: int = dialogue_box.lines.size()
	_check("[%s] sequence has more than one line (a meaningful Skip test)" % context_label, total_lines > 1)

	dialogue_box.advance()
	_check("[%s] now on a later line, not the first" % context_label, dialogue_box.current_line.get("text", "") != dialogue_box.lines[0].get("text", ""))

	var shown_count := 0
	var counter := func(_i, _l): shown_count += 1
	dialogue_box.line_shown.connect(counter)

	dialogue_box.skip()

	_check("[%s] Skip shows zero further individual lines" % context_label, shown_count == 0)
	_check("[%s] Skip is no longer active after pressing it" % context_label, not dialogue_box.is_active())

	await get_tree().process_frame
	await get_tree().process_frame

	var next_scene = get_tree().current_scene
	_check("[%s] Skip reaches the same next scene Continue would" % context_label, next_scene != null and next_scene.scene_file_path == expected_next_scene)


## Skips a dialogue-only beat (a tutorial intro) without the mid-sequence verification --
## used purely to move the flow along between the beats actually under test above.
func _skip_dialogue(scene: Node) -> void:
	var dialogue_box = scene.get_node("%DialogueBox")
	dialogue_box.skip()
	await get_tree().process_frame
	await get_tree().process_frame


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


func _check(label: String, condition: bool) -> void:
	print("[PASS] %s" % label if condition else "[FAIL] %s" % label)
