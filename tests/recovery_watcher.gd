extends Node
## Automated end-to-end test of the Recovery gameplay, driven through real signals
## starting from the Scenario Book (Day 1 / Credential Abuse). Gets through
## Investigation, Monitoring, and Hardening quickly (their own detailed behavior is
## covered elsewhere), drives Response through 3 real turns to accumulate 3 distinct
## damaged components, then thoroughly exercises Recovery: network display, component
## selection, the repair minigame (including a wrong guess + Retry), progress tracking,
## restored-state display, completion, and the interactive tutorial. Not part of the
## shipped game.

const TUTORIAL_BEAT := "res://scenes/scenario_flow/tutorial_beat.tscn"
const RECOVERY := "res://scenes/recovery/recovery.tscn"
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
	await _complete_investigation(investigation)
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

	var response = get_tree().current_scene
	# End 3 real turns so 3 distinct components take damage (Server, Database, Router)
	# before forcing the win -- Recovery needs real, varied damage to test against.
	response.get_node("%EndTurnButton").pressed.emit()
	response.get_node("%EndTurnButton").pressed.emit()
	response.get_node("%EndTurnButton").pressed.emit()
	_check("three real boss turns damaged three distinct components", GameState.damaged_components.size() == 3)

	response.containment = 100
	response._check_win_loss()
	response.get_node("%ContinueButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	await _finish_dialogue(scene)  # response_to_recovery story -> Recovery Tutorial dialogue
	scene = get_tree().current_scene
	_check("Recovery Tutorial dialogue plays before the real scene", scene != null and scene.scene_file_path == TUTORIAL_BEAT)
	_check("recovery tutorial not completed yet", not GameState.recovery_tutorial_completed)

	await _finish_dialogue(scene)
	var recovery = get_tree().current_scene
	_check("Recovery Tutorial dialogue leads to the real Recovery scene", recovery != null and recovery.scene_file_path == RECOVERY)
	_check("interactive tutorial hint banner visible on entry", recovery.get_node("%HintBanner").visible)

	# --- required outcomes: network display shows damaged vs. restored vs. safe ---
	var damaged_names: Array = []
	for entry in GameState.damaged_components:
		damaged_names.append(String(entry.get("name", "")))
	var component_buttons: Array = recovery.get_node("%ComponentList").get_children()
	_check("network view lists all 5 components", component_buttons.size() == 5)

	var damaged_button_count := 0
	var safe_button_count := 0
	for button in component_buttons:
		var is_damaged: bool = false
		for damaged_name in damaged_names:
			if damaged_name in button.text:
				is_damaged = true
		if is_damaged:
			damaged_button_count += 1
			_check("damaged component shown as DAMAGED and selectable", "DAMAGED" in button.text and not button.disabled)
		else:
			safe_button_count += 1
			_check("safe component shown as SAFE and not selectable", "SAFE" in button.text and button.disabled)
	_check("3 components shown as damaged", damaged_button_count == 3)
	_check("2 components shown as safe", safe_button_count == 2)
	_check("progress starts at 0 of 3 repaired", recovery.get_node("%ProgressLabel").text == "Repaired: 0 / 3 damaged components")

	# --- select the first damaged component and inspect the minigame ---
	var first_damaged_button: Button = null
	for button in component_buttons:
		if not button.disabled:
			first_damaged_button = button
			break
	var first_component_name: String = String(first_damaged_button.text.split(" -- ")[0])
	first_damaged_button.pressed.emit()

	_check("selecting a component opens the minigame panel", recovery.get_node("%MinigamePanel").visible and not recovery.get_node("%NetworkView").visible)
	_check("minigame title names the component being repaired", first_component_name.to_upper() in recovery.get_node("%MinigameTitleLabel").text)
	_check("hint advances past 'select a component'", recovery.get_node("%HintLabel").text != "These are the components damaged during the incident. Select one to start repairing it.")

	if recovery._active_minigame == null:
		_check("instructions mention the scenario's minigame type for this component", recovery.get_node("%InstructionLabel").text != "")
		_check("three options are offered", recovery.get_node("%OptionsRow").get_child_count() == 3)
	else:
		_check("a real minigame is shown instead of the generic fallback", recovery.get_node("%OptionsRow").get_child_count() == 0)

	# --- guess wrong on purpose, then use Retry ---
	await _attempt_current_minigame(recovery, false)
	_check("a wrong guess shows failure feedback", recovery.get_node("%FeedbackLabel").text == "That wasn't the right fix. Try again.")
	_check("a wrong guess offers Retry", recovery.get_node("%RetryButton").visible)
	_check("component is not repaired after a wrong guess", not GameState.is_component_repaired(first_component_name))

	recovery.get_node("%RetryButton").pressed.emit()
	await get_tree().process_frame
	_check("Retry clears the feedback and restarts the attempt", recovery.get_node("%FeedbackLabel").text == "" and not recovery.get_node("%RetryButton").visible)

	# --- succeed on the retry ---
	await _attempt_current_minigame(recovery, true)
	_check("correct guess shows success feedback", "Repair successful!" in recovery.get_node("%FeedbackLabel").text)
	_check("successful repair marks the component restored", GameState.is_component_repaired(first_component_name))

	await get_tree().create_timer(0.7).timeout
	await get_tree().process_frame

	_check("scene returns to the network view after a repair", recovery.get_node("%NetworkView").visible and not recovery.get_node("%MinigamePanel").visible)
	_check("progress updates to 1 of 3 repaired", recovery.get_node("%ProgressLabel").text == "Repaired: 1 / 3 damaged components")

	var repaired_button: Button = null
	for button in recovery.get_node("%ComponentList").get_children():
		if first_component_name in button.text:
			repaired_button = button
			break
	_check("repaired component now shows RESTORED and is no longer selectable", "RESTORED" in repaired_button.text and repaired_button.disabled)

	# --- repair the remaining two damaged components (first-try each) ---
	for i in range(2):
		var next_button: Button = null
		for button in recovery.get_node("%ComponentList").get_children():
			if not button.disabled:
				next_button = button
				break
		_check("a next damaged component is available to select", next_button != null)
		next_button.pressed.emit()
		await get_tree().process_frame
		await _attempt_current_minigame(recovery, true)
		await get_tree().create_timer(0.7).timeout
		await get_tree().process_frame

	# --- success condition: every damaged component restored ---
	_check("recovery tutorial completed via real interaction", GameState.recovery_tutorial_completed)
	_check("hint banner hidden once the tutorial completes", not recovery.get_node("%HintBanner").visible)
	_check("GameState confirms every damaged component repaired", GameState.all_damaged_components_repaired())
	_check("complete panel shown", recovery.get_node("%CompletePanel").visible)
	_check("summary reports restored systems", "restored" in recovery.get_node("%SummaryLabel").text.to_lower())

	recovery.get_node("%ContinueButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	_check("Recovery completion leads to the Day Conclusion (last phase, no between-objective story after it)", scene != null and scene.scene_file_path == SCENARIO_CONCLUSION)

	await _finish_dialogue(scene)
	scene = get_tree().current_scene
	_check("Day Conclusion returns to the Scenario Book", scene != null and scene.scene_file_path == SCENARIO_BOOK)
	_check("Day 1 marked completed", GameState.is_scenario_completed("credential_abuse"))
	_check("Day 2 unlocked", GameState.is_day_unlocked(2))

	print("=== RECOVERY TEST COMPLETE ===")
	get_tree().quit()


## Quickly drives the real Investigation scene to success -- covered in depth by
## tests/investigation_watcher.gd, this only needs to reach a real success.
func _complete_investigation(investigation: Node) -> void:
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
	var correct_threat: String = String(scenario.get("threat_name", ""))
	for child in investigation.get_node("%ThreatList").get_children():
		if child is Button and child.text == correct_threat:
			child.pressed.emit()
			break
	investigation.get_node("%ConfirmButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame


## Drives whichever minigame Recovery is currently showing -- a real minigame instance
## (see scenes/recovery/minigames/) or the generic fallback -- to either a deliberate
## failure or a genuine success. Each real minigame's own internals (preview timing,
## retry, exact UI) are already covered in depth by tests/recovery_minigames_watcher.gd;
## this only needs to reliably reach the outcome so the surrounding Recovery integration
## (progress, tutorial, hand-off) can keep being checked regardless of which component
## -- and therefore which minigame type -- Response happened to damage.
func _attempt_current_minigame(recovery: Node, succeed: bool) -> void:
	var game = recovery._active_minigame

	if game == null:
		var options: Array = recovery.get_node("%OptionsRow").get_children()
		var index: int = recovery._correct_option_index if succeed else (0 if recovery._correct_option_index != 0 else 1)
		options[index].pressed.emit()
		await get_tree().create_timer(0.1).timeout
		return

	if "_target_indices" in game:
		# Pattern Matching: wait out the preview, then pick either the real target set or
		# its exact complement (guaranteed wrong, same size).
		await get_tree().create_timer(1.2).timeout
		var indices: Array = game._target_indices if succeed else _complement_indices(game._target_indices, game._tile_buttons.size())
		for i in indices:
			game._tile_buttons[i].pressed.emit()
		game._confirm_button.pressed.emit()
		await get_tree().create_timer(1.2).timeout
	else:
		# Sequence Puzzle: wait out the flash playback, then either repeat it back
		# correctly or press a pad that's guaranteed not to be the first step.
		await get_tree().create_timer(2.3).timeout
		if succeed:
			for step in game._sequence:
				game._pad_buttons[step].pressed.emit()
				await get_tree().create_timer(0.35).timeout
			await get_tree().create_timer(1.2).timeout
		else:
			var wrong_index: int = 0 if game._sequence[0] != 0 else 1
			game._pad_buttons[wrong_index].pressed.emit()
			await get_tree().create_timer(0.7).timeout


func _complement_indices(target: Array, total: int) -> Array:
	var complement: Array = []
	for i in range(total):
		if not target.has(i):
			complement.append(i)
	return complement


func _finish_dialogue(scene: Node) -> void:
	var dialogue_box = scene.get_node("%DialogueBox")
	dialogue_box.skip()
	await get_tree().process_frame
	await get_tree().process_frame


func _check(label: String, condition: bool) -> void:
	print("[PASS] %s" % label if condition else "[FAIL] %s" % label)
