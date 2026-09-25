extends Node
## Automated end-to-end test of the Response gameplay, driven through real signals
## starting from the Scenario Book (Day 1 / Credential Abuse). Gets through
## Investigation and Monitoring quickly (their own detailed behavior is covered by
## investigation_watcher.gd and monitoring_watcher.gd), purchases MFA and the passive
## upgrade in Hardening (to prove passive_upgrades actually reaches Response), then
## exercises Response: boss load, deck built from Hardening, playing cards, containment
## rising, boss intent damaging System Integrity and recording a damaged component,
## the interactive tutorial, winning, and the result handing off back to ScenarioFlow.
## Not part of the shipped game.

const TUTORIAL_BEAT := "res://scenes/scenario_flow/tutorial_beat.tscn"
const HARDENING := "res://scenes/hardening/hardening.tscn"
const RESPONSE := "res://scenes/response/response.tscn"
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
	_check("Hardening scene reached", hardening != null and hardening.scene_file_path == HARDENING)

	# Buy MFA (unlocks Force Re-authentication) and the passive upgrade so Response has
	# both a Hardening-purchased card AND a passive_upgrades entry to receive.
	GameState.security_points = 100
	hardening._update_points_label()
	var shop_items: Array = hardening.get_node("%ShopList").get_children()
	shop_items[0].pressed.emit()  # MFA
	hardening.get_node("%BuyButton").pressed.emit()
	hardening.get_node("%ShopList").get_children()[4].pressed.emit()  # Increased System Integrity
	hardening.get_node("%BuyButton").pressed.emit()
	_check("MFA purchased, unlocking Force Re-authentication", GameState.response_deck.has("Force Re-authentication"))
	_check("passive upgrade purchased", GameState.passive_upgrades.has("Increased System Integrity"))

	hardening.get_node("%ConfirmButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	await _finish_dialogue(scene)  # hardening_to_response story -> Response Tutorial dialogue
	scene = get_tree().current_scene
	_check("Response Tutorial dialogue plays before the real scene", scene != null and scene.scene_file_path == TUTORIAL_BEAT)
	_check("response tutorial not completed yet", not GameState.response_tutorial_completed)

	await _finish_dialogue(scene)
	var response = get_tree().current_scene
	_check("Response Tutorial dialogue leads to the real Response scene", response != null and response.scene_file_path == RESPONSE)

	# --- required input: current_threat, response_deck, passive_upgrades, system_integrity ---
	_check("boss loads as the identified threat", response.get_node("%BossNameLabel").text == "CREDENTIAL ABUSE")
	_check("passive upgrade boosted max System Integrity", GameState.max_system_integrity == 110)
	_check("System Integrity starts at the boosted maximum", GameState.system_integrity == 110)
	_check("interactive tutorial hint banner visible on entry", response.get_node("%HintBanner").visible)

	# --- boss framework: tested in isolation with throwaway data, independent of the
	# full UI/turn-loop flow (already covered below and elsewhere), to prove the
	# generic engine itself supports react-to-player-state and escalating "special
	# behavior" for ANY threat's data, not just Credential Abuse's specific numbers ---
	var Boss = load("res://scenes/response/boss.gd")

	var reactive_boss = Boss.new()
	reactive_boss.configure({
		"id": "test_reactive", "name": "Test Reactive", "max_hp": 999,
		"intents": [
			{"id": "normal", "label": "NORMAL MOVE", "description": "A routine move.", "damage": 5, "component": "Server"},
			{"id": "aggressive", "label": "AGGRESSIVE MOVE", "description": "A dangerous move.", "damage": 20, "component": "Database"},
		],
		"reactive_intent_id": "aggressive",
		"reactive_threshold_percent": 50,
	})
	_check("boss starts on its first configured intent", reactive_boss.current_label() == "NORMAL MOVE")
	reactive_boss.update_intent_for_player_state(80.0)
	_check("boss does not react while the player is healthy", reactive_boss.current_label() == "NORMAL MOVE")
	reactive_boss.update_intent_for_player_state(30.0)
	_check("boss reacts to player vulnerability by switching intent", reactive_boss.current_label() == "AGGRESSIVE MOVE")

	var growth_boss = Boss.new()
	growth_boss.configure({
		"id": "test_growth", "name": "Test Growth", "max_hp": 999,
		"intents": [{"id": "growing_attack", "label": "GROWING ATTACK", "description": "Gets worse over time.", "damage": 10, "component": "Server", "damage_growth": 5}],
	})
	var use1: Dictionary = growth_boss.execute_intent()
	var use2: Dictionary = growth_boss.execute_intent()
	var use3: Dictionary = growth_boss.execute_intent()
	_check("special behavior: intent deals base damage on first use", int(use1.get("damage")) == 10)
	_check("special behavior: same intent deals more damage on repeated use", int(use2.get("damage")) == 15)
	_check("special behavior: damage keeps escalating the longer it's unchecked", int(use3.get("damage")) == 20)

	var expected_cards: int = 2 + 2 + 2 + 2 + 1  # Investigate/Scan/Block/Isolate x2 (base) + Force Re-authentication x1
	_check("deck built from response_deck: base cards doubled, purchased card once", response.deck_manager.deck_count() + response.deck_manager.hand_count() == expected_cards)
	_check("hand drawn up to hand_size_max", response.deck_manager.hand_count() == 5)

	# --- play a card that raises Containment ---
	var hand_nodes: Array = response.get_node("%HandContainer").get_children()
	var containment_card = null
	for node in hand_nodes:
		if "Containment" in String(node.card_data.get("logic", "")):
			containment_card = node
			break
	_check("a Containment-raising card is in hand", containment_card != null)

	# Drive this through REAL input (push_input), not a direct signal .emit() -- this is
	# the exact path that was broken by ui/response_card/response_card.tscn's Bg node
	# defaulting to mouse_filter STOP and swallowing every click on the card.
	var click_pos: Vector2 = containment_card.global_position + containment_card.size / 2.0

	var hover := InputEventMouseMotion.new()
	hover.position = click_pos
	hover.global_position = click_pos
	get_viewport().push_input(hover)
	await get_tree().process_frame
	_check("hovering a card over real input scales it up", containment_card.scale != Vector2.ONE)

	var containment_before: int = response.containment
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = click_pos
	press.global_position = click_pos
	get_viewport().push_input(press)
	await get_tree().process_frame
	_check("a real injected click plays the card and raises Containment", response.containment > containment_before)

	# _on_card_played defers the hand rebuild by one frame (freeing the just-played
	# card's node synchronously, while its own signal is still emitting, would try to
	# free a locked object) -- wait for that to land before checking what depends on it.
	await get_tree().process_frame
	await get_tree().process_frame
	_check("hint advances past 'play a card'", response.get_node("%HintLabel").text != "This is your hand -- each card shows its Energy cost. Click a card to play it.")

	# --- boss intent damages System Integrity and records a damaged component on End Turn ---
	var integrity_before: int = GameState.system_integrity
	var total_damage_before: int = GameState.total_damage_taken
	response.get_node("%EndTurnButton").pressed.emit()
	_check("boss intent damages System Integrity", GameState.system_integrity == integrity_before - 12)
	_check("boss intent accumulates total_damage_taken", GameState.total_damage_taken == total_damage_before + 12)
	_check("boss intent records a damaged component", GameState.is_component_damaged("Server"))
	_check("damaged component records its damage amount", GameState.get_component_damage("Server") == 12)
	_check("intent label shows the next boss move in readable language", "REPLAYING CREDENTIALS" in response.get_node("%IntentLabel").text and "attacker" in response.get_node("%IntentLabel").text)

	response.get_node("%EndTurnButton").pressed.emit()
	_check("a second boss intent damages System Integrity again", GameState.is_component_damaged("Database"))
	_check("two distinct damaged components produce two entries", GameState.damaged_components.size() == 2)
	_check("tutorial completes after two End Turns", GameState.response_tutorial_completed)
	_check("hint banner hides once the tutorial completes", not response.get_node("%HintBanner").visible)

	# --- damaging the SAME component twice accumulates damage rather than duplicating it ---
	var server_damage_before: int = GameState.get_component_damage("Server")
	GameState.damage_component("Server", 7)
	_check("re-damaging a component accumulates its damage", GameState.get_component_damage("Server") == server_damage_before + 7)
	_check("re-damaging a component does not add a duplicate entry", GameState.damaged_components.size() == 2)

	_check("get_safe_components excludes damaged ones", not GameState.get_safe_components().has("Server") and not GameState.get_safe_components().has("Database"))
	_check("get_safe_components includes untouched ones", GameState.get_safe_components().has("Router") and GameState.get_safe_components().has("Switch") and GameState.get_safe_components().has("Computer"))

	# --- fast-forward to a win: Containment reaching 100 is what a real, longer playthrough
	# would reach through more turns of card play -- this only needs to prove the win path
	# reports correctly, not re-simulate an entire multi-turn match. ---
	response.containment = 100
	response._check_win_loss()

	_check("GameState.threat_defeated set on win", GameState.threat_defeated)
	_check("GameState.response_result set on win", GameState.response_result == "threat_neutralized")
	_check("result panel shown", response.get_node("%ResultPanel").visible)
	_check("result label announces victory", response.get_node("%ResultLabel").text == "THREAT NEUTRALIZED")

	# --- success conditions: GameState carries the exact Response result Recovery needs ---
	var summary_text: String = response.get_node("%SummaryLabel").text
	_check("summary shows final System Integrity", ("System Integrity: %d / %d" % [GameState.system_integrity, GameState.max_system_integrity]) in summary_text)
	_check("summary lists damaged components", "- Server" in summary_text and "- Database" in summary_text)
	_check("summary lists safe components", "- Router" in summary_text and "- Switch" in summary_text and "- Computer" in summary_text)
	_check("GameState.total_damage_taken accumulated across the fight", GameState.total_damage_taken == 12 + 15)
	_check("GameState.damaged_components carries a damage amount per component", GameState.get_component_damage("Server") > 0 and GameState.get_component_damage("Database") > 0)

	response.get_node("%ContinueButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	_check("Response completion hands off to ScenarioFlow (between-objective story)", scene != null and scene.scene_file_path == BETWEEN_OBJECTIVE_STORY)
	_check("current_phase still RESPONSE until the story finishes", GameState.current_phase == GameState.Phase.RESPONSE)

	await _finish_dialogue(scene)
	scene = get_tree().current_scene
	_check("story finishing advances to RECOVERY", GameState.current_phase == GameState.Phase.RECOVERY)

	print("=== RESPONSE TEST COMPLETE ===")
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


func _finish_dialogue(scene: Node) -> void:
	var dialogue_box = scene.get_node("%DialogueBox")
	dialogue_box.skip()
	await get_tree().process_frame
	await get_tree().process_frame


func _check(label: String, condition: bool) -> void:
	print("[PASS] %s" % label if condition else "[FAIL] %s" % label)
