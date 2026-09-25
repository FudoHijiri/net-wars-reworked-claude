extends Node
## Automated end-to-end test of the Hardening gameplay, driven through real signals
## starting from the Scenario Book (Day 1 / Credential Abuse). Gets through
## Investigation and Monitoring quickly (their own detailed behavior is covered by
## investigation_watcher.gd and monitoring_watcher.gd), sets Security Points to a known
## test value, then exercises Hardening: browsing, inspecting cost/description,
## purchasing, insufficient-funds rejection, a passive upgrade, the Response Deck
## review, the interactive tutorial, and confirmation handing off back to ScenarioFlow.
## Not part of the shipped game.

const SCENARIO_INTRO := "res://scenes/scenario_flow/scenario_intro.tscn"
const TUTORIAL_BEAT := "res://scenes/scenario_flow/tutorial_beat.tscn"
const INVESTIGATION := "res://scenes/investigation/investigation.tscn"
const MONITORING := "res://scenes/monitoring/monitoring.tscn"
const HARDENING := "res://scenes/hardening/hardening.tscn"
const BETWEEN_OBJECTIVE_STORY := "res://scenes/scenario_flow/between_objective_story.tscn"
const RESPONSE := "res://scenes/response/response.tscn"


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
	_check("Hardening tutorial not completed yet", not GameState.hardening_tutorial_completed)

	await _finish_dialogue(scene)
	var hardening = get_tree().current_scene
	_check("Hardening Tutorial dialogue leads to the real Hardening scene", hardening != null and hardening.scene_file_path == HARDENING)
	_check("interactive tutorial hint banner visible on entry", hardening.get_node("%HintBanner").visible)

	# Give the player a known, deterministic budget rather than depending on exactly how
	# Monitoring was played (that scoring is covered by monitoring_watcher.gd).
	GameState.security_points = 100
	hardening._update_points_label()
	_check("Security Points shown reflect GameState", hardening.get_node("%SecurityPointsLabel").text == "Security Points: 100")

	var shop_items: Array = hardening.get_node("%ShopList").get_children()
	_check("shop lists all 5 items", shop_items.size() == 5)

	# --- inspect and purchase MFA ---
	shop_items[0].pressed.emit()
	_check("inspecting MFA shows its name", hardening.get_node("%DetailNameLabel").text == "MFA")
	_check("inspecting MFA shows its cost", hardening.get_node("%DetailCostLabel").text == "Cost: 30 Security Points")
	_check("affordable item leaves Buy enabled", not hardening.get_node("%BuyButton").disabled)
	_check("hint advances past 'inspect a defense'", hardening.get_node("%HintLabel").text != "Select a defense below to see what it does and how much it costs.")

	hardening.get_node("%BuyButton").pressed.emit()
	_check("purchase deducts the cost", GameState.security_points == 70)
	_check("purchase recorded in purchased_defenses", GameState.purchased_defenses.has("mfa"))
	_check("purchase unlocks its card in the Response deck", GameState.response_deck.has("Force Re-authentication"))
	_check("feedback names the unlocked card", hardening.get_node("%DetailFeedbackLabel").text == "Purchased. Force Re-authentication added to your Response deck.")

	# --- re-selecting an owned item blocks a repeat purchase ---
	hardening.get_node("%ShopList").get_children()[0].pressed.emit()
	_check("owned item shows as already purchased", hardening.get_node("%DetailFeedbackLabel").text == "Already purchased.")
	_check("Buy is disabled for an owned item", hardening.get_node("%BuyButton").disabled)
	hardening.get_node("%BuyButton").pressed.emit()
	_check("re-purchase attempt is ignored", GameState.security_points == 70 and GameState.purchased_defenses.size() == 1)

	# --- purchase Account Protection ---
	hardening.get_node("%ShopList").get_children()[1].pressed.emit()
	hardening.get_node("%BuyButton").pressed.emit()
	_check("second purchase deducts its cost", GameState.security_points == 45)
	_check("second purchase unlocks its card", GameState.response_deck.has("Disable Account"))

	# --- Network Segmentation (cost 50) is now unaffordable at 45 points ---
	hardening.get_node("%ShopList").get_children()[3].pressed.emit()
	_check("unaffordable item shows insufficient-funds feedback", hardening.get_node("%DetailFeedbackLabel").text == "Not enough Security Points.")
	_check("Buy is disabled for an unaffordable item", hardening.get_node("%BuyButton").disabled)
	hardening.get_node("%BuyButton").pressed.emit()
	_check("attempting to buy beyond available resources is rejected", GameState.security_points == 45 and not GameState.purchased_defenses.has("network_segmentation"))

	# --- purchase the passive upgrade ---
	hardening.get_node("%ShopList").get_children()[4].pressed.emit()
	_check("passive item detail shows its description", hardening.get_node("%DetailDescriptionLabel").text != "")
	hardening.get_node("%BuyButton").pressed.emit()
	_check("passive purchase deducts its cost", GameState.security_points == 30)
	_check("passive purchase recorded separately from deck cards", GameState.passive_upgrades.has("Increased System Integrity"))
	_check("passive purchase feedback confirms activation", hardening.get_node("%DetailFeedbackLabel").text == "Purchased. Increased System Integrity is now active.")

	# --- review the resulting Response deck ---
	hardening.get_node("%ViewDeckButton").pressed.emit()
	_check("Response Deck panel opens", hardening.get_node("%ResponseDeckPanel").visible)
	var deck_entries: Array = hardening.get_node("%DeckList").get_children()
	_check("deck = base deck (4) + 2 purchased cards", deck_entries.size() == 6)
	_check("passive upgrades list shows the purchase", hardening.get_node("%PassivesList").get_child_count() == 1)
	_check("tutorial completes once the deck has been reviewed", GameState.hardening_tutorial_completed)
	_check("hint banner hides once the tutorial completes", not hardening.get_node("%HintBanner").visible)

	hardening.get_node("%CloseDeckButton").pressed.emit()
	_check("closing the deck panel returns to the shop", not hardening.get_node("%ResponseDeckPanel").visible)

	# --- confirm preparation ---
	hardening.get_node("%ConfirmButton").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	_check("Confirm hands off to ScenarioFlow (between-objective story)", scene != null and scene.scene_file_path == BETWEEN_OBJECTIVE_STORY)
	_check("current_phase still HARDENING until the story finishes", GameState.current_phase == GameState.Phase.HARDENING)
	_check("final purchased_defenses recorded exactly the 3 successful purchases", GameState.purchased_defenses == ["mfa", "account_protection", "increased_integrity"])
	_check("final response_deck is base deck plus the 2 card unlocks", GameState.response_deck == ["Investigate", "Scan", "Block", "Isolate", "Force Re-authentication", "Disable Account"])

	await _finish_dialogue(scene)
	scene = get_tree().current_scene
	_check("story finishing advances to RESPONSE", GameState.current_phase == GameState.Phase.RESPONSE)
	_check("Response's own tutorial dialogue plays next", scene != null and scene.scene_file_path == TUTORIAL_BEAT)

	await _finish_dialogue(scene)
	scene = get_tree().current_scene
	_check("Response Tutorial dialogue leads to the real Response scene", scene != null and scene.scene_file_path == RESPONSE)

	print("=== HARDENING TEST COMPLETE ===")
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
