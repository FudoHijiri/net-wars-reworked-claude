extends Node
## Automated end-to-end test of the Monitoring gameplay, driven through real signals
## starting from the Scenario Book (Day 1 / Credential Abuse). Gets through Investigation
## quickly (its own detailed behavior is covered by investigation_watcher.gd), then
## exercises Monitoring: real time countdown, event spawning, view switching, correct/
## false/important reporting and scoring, duplicate-report prevention, the interactive
## tutorial, and completion handing off back to ScenarioFlow. Not part of the shipped
## game.

const SCENARIO_INTRO := "res://scenes/scenario_flow/scenario_intro.tscn"
const TUTORIAL_BEAT := "res://scenes/scenario_flow/tutorial_beat.tscn"
const INVESTIGATION := "res://scenes/investigation/investigation.tscn"
const MONITORING := "res://scenes/monitoring/monitoring.tscn"
const HARDENING := "res://scenes/hardening/hardening.tscn"
const BETWEEN_OBJECTIVE_STORY := "res://scenes/scenario_flow/between_objective_story.tscn"


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
	_check("Investigation success leads to a between-objective story", scene != null and scene.scene_file_path == BETWEEN_OBJECTIVE_STORY)

	await _finish_dialogue(scene)  # -> Monitoring Tutorial dialogue
	scene = get_tree().current_scene
	_check("Monitoring tutorial dialogue plays before the real scene", scene != null and scene.scene_file_path == TUTORIAL_BEAT)
	_check("monitoring tutorial not completed yet", not GameState.monitoring_tutorial_completed)

	await _finish_dialogue(scene)
	var monitoring = get_tree().current_scene
	_check("Monitoring Tutorial dialogue leads to the real Monitoring scene", monitoring != null and monitoring.scene_file_path == MONITORING)
	_check("interactive tutorial hint banner visible on entry", monitoring.get_node("%HintBanner").visible)
	_check("initial timer shows the configured duration", monitoring.get_node("%TimeLabel").text == "Time Remaining: 0:45")
	_check("security points start at 0", monitoring.get_node("%SecurityPointsLabel").text == "Security Points: 0")

	# --- verify the countdown genuinely ticks down over real time ---
	await get_tree().create_timer(2.0).timeout
	_check("timer counts down over real time", monitoring.get_node("%TimeLabel").text != "Time Remaining: 0:45")

	# --- spawn every scripted event directly (bypassing the real spawn interval) ---
	for i in range(8):
		monitoring._spawn_next_event()

	# --- Login View: 3 events, including the flagship important anomaly ---
	monitoring.get_node("%LoginViewButton").pressed.emit()
	_check("Login View lists its 3 events", monitoring.get_node("%EventList").get_child_count() == 3)
	_check("hint advances past 'switch views'", monitoring.get_node("%HintLabel").text != "Switch between the four views to see what's happening across the network.")

	# Every report rebuilds the event list (to show the "[Reported]" prefix), so the
	# list of buttons must be re-fetched fresh after each one rather than reused.
	monitoring.get_node("%EventList").get_children()[0].pressed.emit()
	_check("inspecting an event shows the flagship title", monitoring.get_node("%DetailTitleLabel").text == "SUSPICIOUS LOGIN DETECTED")
	_check("detail fields are populated", monitoring.get_node("%DetailFieldsList").get_child_count() == 4)

	monitoring.get_node("%ReportButton").pressed.emit()
	_check("correct + important report awards 30 points", GameState.security_points == 30)
	_check("feedback confirms the points awarded", monitoring.get_node("%ReportFeedbackLabel").text == "Reported. +30 Security Points.")
	_check("reported_anomalies records a correct report", GameState.reported_anomalies.size() == 1 and GameState.reported_anomalies[0]["correct"])

	# --- duplicate report of the same event must not double-count ---
	monitoring.get_node("%ReportButton").pressed.emit()
	_check("reporting the same event again is ignored", GameState.security_points == 30 and GameState.reported_anomalies.size() == 1)

	monitoring.get_node("%EventList").get_children()[1].pressed.emit()
	monitoring.get_node("%ReportButton").pressed.emit()
	_check("correct, non-important report awards 20 points", GameState.security_points == 50)
	_check("tutorial completes after the second report", GameState.monitoring_tutorial_completed)
	_check("hint banner hides once the tutorial completes", not monitoring.get_node("%HintBanner").visible)

	monitoring.get_node("%EventList").get_children()[2].pressed.emit()
	monitoring.get_node("%ReportButton").pressed.emit()
	_check("false report costs 10 points", GameState.security_points == 40)
	_check("feedback explains the activity was legitimate", monitoring.get_node("%ReportFeedbackLabel").text == "That activity was legitimate. -10 Security Points.")
	_check("reported_anomalies records the false report", GameState.reported_anomalies[2]["correct"] == false)

	monitoring.get_node("%CloseDetailButton").pressed.emit()

	# --- Computer View ---
	monitoring.get_node("%ComputerViewButton").pressed.emit()
	_check("Computer View lists its 2 events", monitoring.get_node("%EventList").get_child_count() == 2)
	var computer_entries: Array = monitoring.get_node("%EventList").get_children()
	computer_entries[0].pressed.emit()
	monitoring.get_node("%ReportButton").pressed.emit()
	_check("Computer View correct report awards points", GameState.security_points == 60)
	monitoring.get_node("%CloseDetailButton").pressed.emit()

	# --- Network View ---
	monitoring.get_node("%NetworkViewButton").pressed.emit()
	_check("Network View lists its 2 events", monitoring.get_node("%EventList").get_child_count() == 2)
	var network_entries: Array = monitoring.get_node("%EventList").get_children()
	network_entries[0].pressed.emit()
	monitoring.get_node("%ReportButton").pressed.emit()
	_check("Network View important report awards 30 points", GameState.security_points == 90)
	monitoring.get_node("%CloseDetailButton").pressed.emit()

	# --- Server View: 1 normal event, left unreported on purpose ---
	monitoring.get_node("%ServerViewButton").pressed.emit()
	_check("Server View lists its 1 event", monitoring.get_node("%EventList").get_child_count() == 1)

	# --- end monitoring directly rather than waiting out the remaining real time ---
	monitoring._end_monitoring()
	_check("Complete panel shown", monitoring.get_node("%CompletePanel").visible)
	_check("summary reports 4 correct, 1 false, 90 points", monitoring.get_node("%SummaryLabel").text == "Correct Reports: 4\nFalse Reports: 1\nSecurity Points: 90")
	_check("monitoring_score reflects net correct reports", GameState.monitoring_score == 3)

	monitoring.get_node("%ContinueButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	_check("Monitoring completion leads to a between-objective story", scene != null and scene.scene_file_path == BETWEEN_OBJECTIVE_STORY)
	_check("current_phase still MONITORING until the story finishes", GameState.current_phase == GameState.Phase.MONITORING)

	await _finish_dialogue(scene)
	scene = get_tree().current_scene
	_check("story finishing advances to HARDENING", GameState.current_phase == GameState.Phase.HARDENING)
	_check("Hardening's own tutorial dialogue plays next", scene != null and scene.scene_file_path == TUTORIAL_BEAT)

	await _finish_dialogue(scene)
	scene = get_tree().current_scene
	_check("Hardening Tutorial leads to the real Hardening scene", scene != null and scene.scene_file_path == HARDENING)

	print("=== MONITORING TEST COMPLETE ===")
	get_tree().quit()


## Quickly drives the real Investigation scene to success: marks every entry the active
## scenario flags as real evidence, visits the evidence log (needed for its own
## interactive tutorial to complete), and confirms the correct threat.
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


func _finish_dialogue(scene: Node) -> void:
	var dialogue_box = scene.get_node("%DialogueBox")
	dialogue_box.skip()
	await get_tree().process_frame
	await get_tree().process_frame


func _check(label: String, condition: bool) -> void:
	print("[PASS] %s" % label if condition else "[FAIL] %s" % label)
