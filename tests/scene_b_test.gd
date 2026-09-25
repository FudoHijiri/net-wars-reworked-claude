extends Node
## Foundation smoke test, part 2: runs after Scene A's scene change. Confirms every
## field set in Scene A survived, finishes the scenario, checks progress tracking,
## then starts a second scenario to confirm per-scenario data resets while progress
## (unlocked days, completed scenarios) does not.

func _ready() -> void:
	print("=== GameState Foundation Test: Scene B ===")

	_check("scenario_id persisted", GameState.scenario_id == "credential_abuse")
	_check("current_day persisted", GameState.current_day == 1)
	_check("current_threat persisted", GameState.current_threat == "Credential Abuse")
	_check("phase persisted as RESPONSE", GameState.current_phase == GameState.Phase.RESPONSE)
	_check("investigation_evidence persisted", GameState.investigation_evidence.size() == 1)
	_check("security_points persisted", GameState.security_points == 90)
	_check("reported_anomalies persisted", GameState.reported_anomalies.size() == 1)
	_check("purchased_defenses persisted", GameState.purchased_defenses.size() == 1)
	_check("response_deck persisted", GameState.response_deck.size() == 1)
	_check("system_integrity persisted", GameState.system_integrity == 70)
	_check("damaged_components persisted", GameState.damaged_components.size() == 1)

	_check("advance to RECOVERY", GameState.advance_phase() and GameState.current_phase == GameState.Phase.RECOVERY)
	GameState.repaired_components.append("Server")

	GameState.complete_scenario()
	_check("scenario marked completed", GameState.is_scenario_completed("credential_abuse"))
	_check("next day unlocked", GameState.is_day_unlocked(2))
	_check("threat_defeated flag set", GameState.threat_defeated == true)

	GameState.start_scenario("malware", 2, "Malware")
	_check("new scenario resets evidence", GameState.investigation_evidence.size() == 0)
	_check("new scenario resets security_points", GameState.security_points == 0)
	_check("new scenario resets damaged_components", GameState.damaged_components.size() == 0)
	_check("new scenario resets phase to INVESTIGATION", GameState.current_phase == GameState.Phase.INVESTIGATION)
	_check("progress survives reset: credential_abuse still completed", GameState.is_scenario_completed("credential_abuse"))
	_check("progress survives reset: day 2 still unlocked", GameState.is_day_unlocked(2))

	print("=== TEST RUN COMPLETE ===")
	get_tree().quit()


func _check(label: String, condition: bool) -> void:
	print("[PASS] %s" % label if condition else "[FAIL] %s" % label)
