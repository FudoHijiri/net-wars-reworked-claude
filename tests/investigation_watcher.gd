extends Node
## Automated end-to-end test of the Investigation gameplay, driven entirely through
## real signals starting from the Scenario Book (Day 1 / Credential Abuse). Covers:
## tutorial progression, inspecting entries, marking real evidence, a false-positive
## entry that must NOT count as evidence, confirming with insufficient evidence,
## confirming the wrong threat, and finally succeeding -- then verifies the result
## reaches GameState and hands off to ScenarioFlow correctly. Not part of the shipped
## game.

const SCENARIO_INTRO := "res://scenes/scenario_flow/scenario_intro.tscn"
const TUTORIAL_BEAT := "res://scenes/scenario_flow/tutorial_beat.tscn"
const INVESTIGATION := "res://scenes/investigation/investigation.tscn"
const MONITORING := "res://scenes/monitoring/monitoring.tscn"
const BETWEEN_OBJECTIVE_STORY := "res://scenes/scenario_flow/between_objective_story.tscn"
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
	_check("Day 1 selected -> Day Introduction", scene != null and scene.scene_file_path == SCENARIO_INTRO)
	await _finish_dialogue(scene)

	scene = get_tree().current_scene
	_check("Day Introduction -> Investigation Tutorial (dialogue)", scene != null and scene.scene_file_path == TUTORIAL_BEAT)
	_check("tutorial not completed before the dialogue plays", not GameState.investigation_tutorial_completed)
	await _finish_dialogue(scene)

	var investigation = get_tree().current_scene
	_check("Investigation Tutorial dialogue -> real Investigation scene (not the placeholder)", investigation != null and investigation.scene_file_path == INVESTIGATION)
	_check("interactive tutorial still active on entry", investigation.get_node("%HintBanner").visible)
	_check("tutorial still not marked completed yet", not GameState.investigation_tutorial_completed)

	# --- open an app, inspect an entry, mark real evidence ---
	investigation.get_node("%LoginActivityButton").pressed.emit()
	_check("opening Login Activity shows its entries", investigation.get_node("%EntryList").get_child_count() == 3)
	_check("hint advanced past step 1", investigation.get_node("%HintLabel").text != "Click an application on the desktop to open it.")

	var login_entries: Array = investigation.get_node("%EntryList").get_children()
	login_entries[0].pressed.emit()
	_check("inspecting an entry shows its detail", investigation.get_node("%DetailPanel").visible and investigation.get_node("%DetailLabel").text != "")

	investigation.get_node("%MarkEvidenceButton").pressed.emit()
	_check("marking real evidence records it in GameState", GameState.investigation_evidence.has("strange_login_location"))
	_check("evidence count label updates", investigation.get_node("%EvidenceLogButton").text == "Evidence Log (1)")

	# --- second entry in the same app ---
	login_entries[1].pressed.emit()
	investigation.get_node("%MarkEvidenceButton").pressed.emit()
	_check("second piece of real evidence recorded", GameState.investigation_evidence.has("unknown_device"))

	# --- false positive: a normal entry must not become evidence ---
	login_entries[2].pressed.emit()
	investigation.get_node("%MarkEvidenceButton").pressed.emit()
	_check("marking a normal entry gives feedback instead of adding evidence", investigation.get_node("%MarkFeedbackLabel").text == "This doesn't seem directly relevant to the incident.")
	_check("evidence count unaffected by the false positive", GameState.investigation_evidence.size() == 2)

	investigation.get_node("%CloseAppButton").pressed.emit()
	_check("Close returns to the desktop", investigation.get_node("%DesktopView").visible)

	# --- confirming now (2 of 4 required) must be blocked regardless of the guess ---
	investigation.get_node("%ConfirmThreatButton").pressed.emit()
	_select_threat(investigation, "Credential Abuse")
	investigation.get_node("%ConfirmButton").pressed.emit()
	_check("confirming with insufficient evidence is blocked", investigation.get_node("%FeedbackLabel").text == "The evidence is inconsistent or insufficient. Keep investigating.")
	_check("scene has not advanced", get_tree().current_scene == investigation)
	investigation.get_node("%CloseThreatButton").pressed.emit()

	# --- collect the remaining two required pieces of evidence ---
	investigation.get_node("%LogsButton").pressed.emit()
	investigation.get_node("%EntryList").get_child(0).pressed.emit()
	investigation.get_node("%MarkEvidenceButton").pressed.emit()
	_check("third piece of real evidence recorded", GameState.investigation_evidence.has("repeated_auth_attempts"))
	investigation.get_node("%CloseAppButton").pressed.emit()

	investigation.get_node("%ReportsButton").pressed.emit()
	investigation.get_node("%EntryList").get_child(0).pressed.emit()
	investigation.get_node("%MarkEvidenceButton").pressed.emit()
	_check("fourth piece of real evidence recorded", GameState.investigation_evidence.has("unusual_time_activity"))
	investigation.get_node("%CloseAppButton").pressed.emit()

	_check("all 4 required evidence pieces collected", GameState.investigation_evidence.size() == 4)

	# --- review evidence log ---
	investigation.get_node("%EvidenceLogButton").pressed.emit()
	_check("Evidence Log lists all collected evidence", investigation.get_node("%EvidenceList").get_child_count() == 4)
	investigation.get_node("%CloseEvidenceButton").pressed.emit()

	# --- wrong threat with full evidence must still be rejected ---
	investigation.get_node("%ConfirmThreatButton").pressed.emit()
	_check("interactive tutorial completed once Confirm Threat was reached", not investigation.get_node("%HintBanner").visible)
	_check("GameState.investigation_tutorial_completed is now true", GameState.investigation_tutorial_completed)

	_select_threat(investigation, "Malware")
	investigation.get_node("%ConfirmButton").pressed.emit()
	_check("wrong threat is rejected without ending the scenario", investigation.get_node("%FeedbackLabel").text == "That doesn't match the evidence. Review your findings and try again.")
	_check("identified_threat still unset after a wrong guess", GameState.identified_threat == "")
	_check("still on the Investigation scene after a wrong guess", get_tree().current_scene == investigation)

	# --- correct threat with full evidence succeeds ---
	_select_threat(investigation, "Credential Abuse")
	investigation.get_node("%ConfirmButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	_check("GameState.identified_threat set on success", GameState.identified_threat == "Credential Abuse")

	var scene_after = get_tree().current_scene
	_check("Investigation success hands off to ScenarioFlow (between-objective story)", scene_after != null and scene_after.scene_file_path == BETWEEN_OBJECTIVE_STORY)
	_check("current_phase still INVESTIGATION until the story finishes", GameState.current_phase == GameState.Phase.INVESTIGATION)

	await _finish_dialogue(scene_after)
	scene_after = get_tree().current_scene
	_check("story finishing advances to MONITORING", GameState.current_phase == GameState.Phase.MONITORING)
	_check("Monitoring's own tutorial dialogue plays next", scene_after != null and scene_after.scene_file_path == TUTORIAL_BEAT)

	await _finish_dialogue(scene_after)
	scene_after = get_tree().current_scene
	_check("Monitoring Tutorial leads to the real Monitoring scene", scene_after != null and scene_after.scene_file_path == MONITORING)

	print("=== INVESTIGATION TEST COMPLETE ===")
	get_tree().quit()


func _select_threat(investigation: Node, threat_name: String) -> void:
	for child in investigation.get_node("%ThreatList").get_children():
		if child is Button and child.text == threat_name:
			child.pressed.emit()
			return


func _finish_dialogue(scene: Node) -> void:
	var dialogue_box = scene.get_node("%DialogueBox")
	dialogue_box.skip()
	await get_tree().process_frame
	await get_tree().process_frame


func _check(label: String, condition: bool) -> void:
	print("[PASS] %s" % label if condition else "[FAIL] %s" % label)
