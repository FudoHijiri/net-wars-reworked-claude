extends Node
## Foundation smoke test, part 1: starts a scenario, writes sample data into every
## phase's fields while advancing through Investigation → Response, then changes
## scene to verify GameState (an autoload) survives the transition.

func _ready() -> void:
	print("=== GameState Foundation Test: Scene A ===")

	GameState.start_scenario("credential_abuse", 1, "Credential Abuse")
	_check("scenario_id set", GameState.scenario_id == "credential_abuse")
	_check("current_day set", GameState.current_day == 1)
	_check("current_threat set", GameState.current_threat == "Credential Abuse")
	_check("phase resets to INVESTIGATION", GameState.current_phase == GameState.Phase.INVESTIGATION)

	GameState.investigation_evidence.append("unusual_login_location")
	GameState.identified_threat = "Credential Abuse"
	_check("investigation_evidence stored", GameState.investigation_evidence.size() == 1)

	_check("advance to MONITORING", GameState.advance_phase() and GameState.current_phase == GameState.Phase.MONITORING)
	GameState.security_points = 90
	GameState.reported_anomalies.append({"account": "Anna", "correct": true})

	_check("advance to HARDENING", GameState.advance_phase() and GameState.current_phase == GameState.Phase.HARDENING)
	GameState.purchased_defenses.append("MFA")
	GameState.response_deck.append("Force Re-authentication")

	_check("advance to RESPONSE", GameState.advance_phase() and GameState.current_phase == GameState.Phase.RESPONSE)
	GameState.system_integrity = 70
	GameState.damaged_components.append("Server")

	print("--- changing scene to Scene B to test cross-scene persistence ---")
	# Deferred: the scene tree is still finishing this node's _ready() and cannot
	# have its current scene swapped out mid-setup.
	get_tree().change_scene_to_file.call_deferred("res://tests/scene_b_test.tscn")


func _check(label: String, condition: bool) -> void:
	print("[PASS] %s" % label if condition else "[FAIL] %s" % label)
