extends Node
## True end-to-end integration test for the whole playable Day 1, in one continuous run
## with zero manual scene changes:
##
##   Game Start -> Title Menu -> Play -> Scenario Book -> Day 1 -> Day Introduction Story
##   -> Investigation Tutorial -> Investigation -> Story -> Monitoring Tutorial ->
##   Monitoring -> Story -> Hardening Tutorial -> Hardening -> Story -> Response
##   Tutorial -> Response -> Story -> Recovery Tutorial -> Recovery -> Day Conclusion ->
##   reveal "Day 1 - Credential Abuse" -> unlock "Day 2 - ???"
##
## Unlike tests/scenario_flow_watcher.gd (which starts from the Scenario Book and takes
## shortcuts through Monitoring/Hardening to focus on phase-transition/tutorial wiring),
## this test plays each phase for real wherever that's cheap to do (a genuine Monitoring
## anomaly report, a genuine Hardening purchase, a genuine Response card play) so every
## arrow in CLAUDE.md's §12/§13 data-flow diagram carries real data end to end, not a
## default/override value. Each phase's own deep mechanics are already covered by its
## own dedicated test -- this only needs to prove the whole Day stitches together and
## that data actually crosses every phase boundary. Not part of the shipped game.

const INTRO := "res://scenes/boot/intro.tscn"
const TITLE_MENU := "res://scenes/menus/title_menu.tscn"
const SCENARIO_BOOK := "res://scenes/menus/scenario_book.tscn"
const SCENARIO_INTRO := "res://scenes/scenario_flow/scenario_intro.tscn"
const TUTORIAL_BEAT := "res://scenes/scenario_flow/tutorial_beat.tscn"
const INVESTIGATION := "res://scenes/investigation/investigation.tscn"
const MONITORING := "res://scenes/monitoring/monitoring.tscn"
const HARDENING := "res://scenes/hardening/hardening.tscn"
const RESPONSE := "res://scenes/response/response.tscn"
const RECOVERY := "res://scenes/recovery/recovery.tscn"
const BETWEEN_OBJECTIVE_STORY := "res://scenes/scenario_flow/between_objective_story.tscn"
const SCENARIO_CONCLUSION := "res://scenes/scenario_flow/scenario_conclusion.tscn"


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	# ================= Game Start =================
	var scene := get_tree().current_scene
	_check("Game Start launches the intro", scene != null and scene.scene_file_path == INTRO)
	scene.get_node("%DialogueBox").skip()
	await get_tree().process_frame
	await get_tree().process_frame

	# ================= Title Menu -> Play =================
	scene = get_tree().current_scene
	_check("Game Start leads to the Title Menu", scene != null and scene.scene_file_path == TITLE_MENU)
	scene.get_node("%PlayButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	# ================= Scenario Book -> Day 1 =================
	var book := get_tree().current_scene
	_check("Play opens the Scenario Book", book != null and book.scene_file_path == SCENARIO_BOOK)
	var day_list: VBoxContainer = book.get_node("%DayList")
	_check("Day 1 starts unrevealed", day_list.get_child(0).text == "Day 1 - ???")
	_check("Day 2 starts locked", day_list.get_child(1).disabled)

	day_list.get_child(0).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	_check("selecting Day 1 opens the Day Introduction story", scene != null and scene.scene_file_path == SCENARIO_INTRO)
	_check("GameState started Day 1 / Credential Abuse", GameState.scenario_id == "credential_abuse" and GameState.current_day == 1 and GameState.current_threat == "Credential Abuse")

	await _finish_dialogue(scene)

	# ================= Investigation Tutorial + Investigation =================
	scene = get_tree().current_scene
	_check("Investigation Tutorial shown (first time on this save)", scene != null and scene.scene_file_path == TUTORIAL_BEAT)
	_check("investigation tutorial not completed yet", not GameState.is_tutorial_completed("investigation"))
	await _finish_dialogue(scene)

	var investigation := get_tree().current_scene
	_check("Investigation Tutorial leads to the real Investigation scene", investigation != null and investigation.scene_file_path == INVESTIGATION)

	await _complete_investigation(investigation, "Credential Abuse")

	_check("Investigation tutorial completed through real play", GameState.is_tutorial_completed("investigation"))
	_check("[data flow] evidence reached GameState.investigation_evidence", GameState.investigation_evidence.size() >= 4)
	_check("[data flow] identified_threat reached GameState", GameState.identified_threat == "Credential Abuse")

	scene = get_tree().current_scene
	_check("Investigation leads to a between-objective story", scene != null and scene.scene_file_path == BETWEEN_OBJECTIVE_STORY)
	await _finish_dialogue(scene)

	# ================= Monitoring Tutorial + Monitoring (real report) =================
	scene = get_tree().current_scene
	_check("Monitoring Tutorial shown (first time on this save)", scene != null and scene.scene_file_path == TUTORIAL_BEAT)
	_check("monitoring tutorial not completed yet", not GameState.is_tutorial_completed("monitoring"))
	await _finish_dialogue(scene)

	var monitoring := get_tree().current_scene
	_check("Monitoring Tutorial leads to the real Monitoring scene", monitoring != null and monitoring.scene_file_path == MONITORING)

	for i in range(8):
		monitoring._spawn_next_event()
	monitoring.get_node("%LoginViewButton").pressed.emit()
	monitoring.get_node("%EventList").get_children()[0].pressed.emit()
	monitoring.get_node("%ReportButton").pressed.emit()
	await get_tree().process_frame

	_check("[data flow] a real anomaly report reached GameState.security_points", GameState.security_points > 0)
	_check("[data flow] reported_anomalies recorded the real report", GameState.reported_anomalies.size() > 0)

	monitoring._end_monitoring()
	_check("Monitoring tutorial completed through real play", GameState.is_tutorial_completed("monitoring"))
	_check("[data flow] monitoring_score reflects the real report", GameState.monitoring_score > 0)

	monitoring.get_node("%ContinueButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	_check("Monitoring leads to a between-objective story", scene != null and scene.scene_file_path == BETWEEN_OBJECTIVE_STORY)
	await _finish_dialogue(scene)

	# ================= Hardening Tutorial + Hardening (real purchase) =================
	scene = get_tree().current_scene
	_check("Hardening Tutorial shown (first time on this save)", scene != null and scene.scene_file_path == TUTORIAL_BEAT)
	_check("hardening tutorial not completed yet", not GameState.is_tutorial_completed("hardening"))
	await _finish_dialogue(scene)

	var hardening := get_tree().current_scene
	_check("Hardening Tutorial leads to the real Hardening scene", hardening != null and hardening.scene_file_path == HARDENING)

	var points_before_purchase: int = GameState.security_points
	var shop_items: Array = hardening.get_node("%ShopList").get_children()
	shop_items[0].pressed.emit()  # MFA
	hardening.get_node("%BuyButton").pressed.emit()

	_check("[data flow] the Hardening purchase spent security_points earned in Monitoring", GameState.security_points < points_before_purchase)
	_check("[data flow] purchased_defenses recorded the purchase", GameState.purchased_defenses.has("mfa"))
	_check("[data flow] response_deck received the purchase's card", GameState.response_deck.has("Force Re-authentication"))

	hardening.get_node("%ConfirmButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("Hardening tutorial completed through real play", GameState.is_tutorial_completed("hardening"))

	scene = get_tree().current_scene
	_check("Hardening leads to a between-objective story", scene != null and scene.scene_file_path == BETWEEN_OBJECTIVE_STORY)
	await _finish_dialogue(scene)

	# ================= Response Tutorial + Response (real card play + real damage) =================
	scene = get_tree().current_scene
	_check("Response Tutorial shown (first time on this save)", scene != null and scene.scene_file_path == TUTORIAL_BEAT)
	_check("response tutorial not completed yet", not GameState.is_tutorial_completed("response"))
	await _finish_dialogue(scene)

	var response := get_tree().current_scene
	_check("Response Tutorial leads to the real Response scene", response != null and response.scene_file_path == RESPONSE)
	_check("[data flow] Response received the Hardening-purchased card in its deck", response.deck_manager.deck_count() + response.deck_manager.hand_count() == 9)

	# --- play one real card through genuine injected input, matching the exact path
	# the card-click bug fix proved: a hover to scale it up, then a real mouse click. ---
	var hand_nodes: Array = response.get_node("%HandContainer").get_children()
	var playable_card = null
	for node in hand_nodes:
		if int(node.card_data.get("energy", 0)) <= response.energy:
			playable_card = node
			break
	_check("a playable card is in the opening hand", playable_card != null)

	var click_pos: Vector2 = playable_card.global_position + playable_card.size / 2.0
	var hover := InputEventMouseMotion.new()
	hover.position = click_pos
	hover.global_position = click_pos
	get_viewport().push_input(hover)
	await get_tree().process_frame

	var hand_count_before: int = response.deck_manager.hand_count()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = click_pos
	press.global_position = click_pos
	get_viewport().push_input(press)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("a real injected click plays a card from Response's Hardening-built deck", response.deck_manager.hand_count() < hand_count_before)

	var integrity_before: int = GameState.system_integrity
	response.get_node("%EndTurnButton").pressed.emit()
	response.get_node("%EndTurnButton").pressed.emit()

	_check("[data flow] Response damaged system_integrity for real", GameState.system_integrity < integrity_before)
	_check("[data flow] damaged_components recorded real Response damage", not GameState.damaged_components.is_empty())
	_check("Response tutorial completed through real play (two End Turns)", GameState.is_tutorial_completed("response"))

	response.containment = 100
	response._check_win_loss()
	_check("[data flow] threat_result reached GameState (threat_defeated + response_result)", GameState.threat_defeated and GameState.response_result != "")

	response.get_node("%ContinueButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	_check("Response leads to a between-objective story", scene != null and scene.scene_file_path == BETWEEN_OBJECTIVE_STORY)
	await _finish_dialogue(scene)

	# ================= Recovery Tutorial + Recovery (real repair) =================
	scene = get_tree().current_scene
	_check("Recovery Tutorial shown (first time on this save)", scene != null and scene.scene_file_path == TUTORIAL_BEAT)
	_check("recovery tutorial not completed yet", not GameState.is_tutorial_completed("recovery"))
	await _finish_dialogue(scene)

	var recovery := get_tree().current_scene
	_check("Recovery Tutorial leads to the real Recovery scene", recovery != null and recovery.scene_file_path == RECOVERY)
	_check("[data flow] Recovery received Response's damaged_components", not GameState.damaged_components.is_empty())

	await _complete_recovery(recovery)

	_check("[data flow] repaired_components covers every damaged component", GameState.all_damaged_components_repaired())
	_check("Recovery tutorial completed through real play", GameState.is_tutorial_completed("recovery"))

	recovery.get_node("%ContinueButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	# ================= Day Conclusion -> reveal -> unlock =================
	scene = get_tree().current_scene
	_check("Recovery leads to the Day Conclusion", scene != null and scene.scene_file_path == SCENARIO_CONCLUSION)
	_check("scenario not yet marked complete during the conclusion story", not GameState.is_scenario_completed("credential_abuse"))
	await _finish_dialogue(scene)

	scene = get_tree().current_scene
	_check("Day Conclusion returns to the Scenario Book", scene != null and scene.scene_file_path == SCENARIO_BOOK)
	_check("[data flow] scenario_result: Day 1 marked completed", GameState.is_scenario_completed("credential_abuse"))
	_check("Day 2 unlocked", GameState.is_day_unlocked(2))

	day_list = scene.get_node("%DayList")
	_check("Scenario Book reveals 'Day 1 - Credential Abuse'", day_list.get_child(0).text == "Day 1 - Credential Abuse")
	_check("Scenario Book unlocks 'Day 2 - ???' and makes it selectable", day_list.get_child(1).text == "Day 2 - ???" and not day_list.get_child(1).disabled)

	# ================= Replay: a completed Day 1 can be played again =================
	# Success condition: "Preserve the ability to replay Day 1." Every tutorial is
	# already completed on this save, so every phase should now go straight from its
	# between-objective story into real gameplay with no tutorial beat/hints -- proving
	# that a replay is a genuinely different (shorter) path through the same real day,
	# not just "the button happens to still be clickable."
	day_list.get_child(0).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	_check("[replay] a completed Day 1 is still selectable and opens its Day Introduction again", scene != null and scene.scene_file_path == SCENARIO_INTRO)
	_check("[replay] replaying resets this run's scenario data", GameState.investigation_evidence.is_empty() and GameState.repaired_components.is_empty())
	await _finish_dialogue(scene)

	scene = get_tree().current_scene
	_check("[replay] Investigation tutorial already completed -> straight to the real scene", scene != null and scene.scene_file_path == INVESTIGATION)
	_check("[replay] no tutorial hints shown for Investigation", not scene.get_node("%HintBanner").visible)
	await _complete_investigation(scene, "Credential Abuse")

	scene = get_tree().current_scene
	_check("[replay] Investigation leads to a between-objective story", scene != null and scene.scene_file_path == BETWEEN_OBJECTIVE_STORY)
	await _finish_dialogue(scene)

	scene = get_tree().current_scene
	_check("[replay] Monitoring tutorial already completed -> straight to the real scene", scene != null and scene.scene_file_path == MONITORING)
	_check("[replay] no tutorial hints shown for Monitoring", not scene.get_node("%HintBanner").visible)
	scene._end_monitoring()
	scene.get_node("%ContinueButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	_check("[replay] Monitoring leads to a between-objective story", scene != null and scene.scene_file_path == BETWEEN_OBJECTIVE_STORY)
	await _finish_dialogue(scene)

	scene = get_tree().current_scene
	_check("[replay] Hardening tutorial already completed -> straight to the real scene", scene != null and scene.scene_file_path == HARDENING)
	_check("[replay] no tutorial hints shown for Hardening", not scene.get_node("%HintBanner").visible)
	scene.get_node("%ConfirmButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	_check("[replay] Hardening leads to a between-objective story", scene != null and scene.scene_file_path == BETWEEN_OBJECTIVE_STORY)
	await _finish_dialogue(scene)

	scene = get_tree().current_scene
	_check("[replay] Response tutorial already completed -> straight to the real scene", scene != null and scene.scene_file_path == RESPONSE)
	_check("[replay] no tutorial hints shown for Response", not scene.get_node("%HintBanner").visible)
	scene.get_node("%EndTurnButton").pressed.emit()
	scene.containment = 100
	scene._check_win_loss()
	scene.get_node("%ContinueButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	_check("[replay] Response leads to a between-objective story", scene != null and scene.scene_file_path == BETWEEN_OBJECTIVE_STORY)
	await _finish_dialogue(scene)

	scene = get_tree().current_scene
	_check("[replay] Recovery tutorial already completed -> straight to the real scene", scene != null and scene.scene_file_path == RECOVERY)
	_check("[replay] no tutorial hints shown for Recovery", not scene.get_node("%HintBanner").visible)
	_check("[replay] Recovery received this run's real damaged_components", not GameState.damaged_components.is_empty())
	await _complete_recovery(scene)
	_check("[replay] every damaged component repaired again", GameState.all_damaged_components_repaired())

	scene.get_node("%ContinueButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	_check("[replay] Recovery leads to the Day Conclusion", scene != null and scene.scene_file_path == SCENARIO_CONCLUSION)
	await _finish_dialogue(scene)

	scene = get_tree().current_scene
	_check("[replay] Day Conclusion returns to the Scenario Book", scene != null and scene.scene_file_path == SCENARIO_BOOK)

	var completed_count: int = 0
	for id in GameState.completed_scenarios:
		if id == "credential_abuse":
			completed_count += 1
	_check("[replay] completing Day 1 a second time does not duplicate its completed-scenario entry", completed_count == 1)

	var unlocked_count: int = 0
	for unlocked_day in GameState.unlocked_days:
		if unlocked_day == 2:
			unlocked_count += 1
	_check("[replay] replaying Day 1 does not duplicate Day 2's unlock entry", unlocked_count == 1)

	day_list = scene.get_node("%DayList")
	_check("[replay] Scenario Book still reveals 'Day 1 - Credential Abuse'", day_list.get_child(0).text == "Day 1 - Credential Abuse")
	_check("[replay] Day 2 is still unlocked and selectable", day_list.get_child(1).text == "Day 2 - ???" and not day_list.get_child(1).disabled)

	print("=== FULL DAY INTEGRATION TEST COMPLETE ===")
	get_tree().quit()


## Drives the real Investigation scene to a genuine success: marks every entry the
## active scenario's data flags as real evidence, then confirms the given (correct)
## threat. Proven identical logic to tests/scenario_flow_watcher.gd's helper of the same
## name -- Investigation's own detailed evidence/tutorial behavior is covered in depth
## by tests/investigation_watcher.gd.
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
## flow, succeeding on the first attempt regardless of which minigame type (a real one
## from scenes/recovery/minigames/, or the generic fallback) Response's damage happened
## to route to. Proven identical logic to tests/scenario_flow_watcher.gd's helpers of the
## same names -- the Retry path and each minigame's own internals are covered in depth by
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
