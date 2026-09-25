extends Node
## Focused test for the two real repair minigames introduced for Recovery -- Pattern
## Matching (Server) and Sequence Puzzle (Database). Bypasses the rest of the Day flow
## entirely (already covered by tests/recovery_watcher.gd and tests/scenario_flow_watcher
## .gd) and instead sets GameState up directly with two damaged components, then drives
## each minigame through a deliberate failure + retry followed by a genuine success,
## using real signal emission throughout. Not part of the shipped game.

const RECOVERY := "res://scenes/recovery/recovery.tscn"


func _ready() -> void:
	await get_tree().process_frame

	GameState.start_scenario("credential_abuse", 1, "Credential Abuse")
	GameState.recovery_tutorial_completed = true
	GameState.damage_component("Server", 30)
	GameState.damage_component("Database", 25)

	get_tree().change_scene_to_file(RECOVERY)
	await get_tree().process_frame
	await get_tree().process_frame

	var recovery := get_tree().current_scene
	_check("Recovery scene loaded", recovery != null and recovery.scene_file_path == RECOVERY)
	_check("no tutorial hints shown (tutorial already completed)", not recovery.get_node("%HintBanner").visible)

	await _run_pattern_matching_case(recovery)
	await _run_sequence_puzzle_case(recovery)

	_check("both components repaired", GameState.all_damaged_components_repaired())
	_check("recovery reports completion once both minigames are solved", recovery.get_node("%CompletePanel").visible)

	print("=== RECOVERY MINIGAMES TEST COMPLETE ===")
	get_tree().quit()


## Server is configured (ScenarioDatabase) to use the Pattern Matching minigame.
func _run_pattern_matching_case(recovery: Node) -> void:
	var server_button: Button = _find_component_button(recovery, "Server")
	_check("Server is damaged and selectable", server_button != null and not server_button.disabled)
	server_button.pressed.emit()
	await get_tree().process_frame

	_check("selecting Server opens the minigame panel", recovery.get_node("%MinigamePanel").visible)
	_check("a real minigame instance was created", recovery._active_minigame != null)
	_check("generic fallback UI is hidden for a real minigame", not recovery.get_node("%OptionsRow").visible)

	var game: Control = recovery._active_minigame

	await get_tree().create_timer(1.2).timeout
	_check("pattern minigame finished its preview and now accepts input", game._accepting_input)
	_check("pattern minigame chose a 3-tile target pattern", game._target_indices.size() == 3)

	# --- deliberate failure: select the exact complement of the target set ---
	var wrong_indices: Array = []
	for i in range(6):
		if not game._target_indices.has(i):
			wrong_indices.append(i)
	_check("a guaranteed-wrong selection of the right size exists", wrong_indices.size() == 3)

	for i in wrong_indices:
		game._tile_buttons[i].pressed.emit()
	_check("confirm enables once the right number of tiles are picked", not game._confirm_button.disabled)

	game._confirm_button.pressed.emit()
	await get_tree().create_timer(0.6).timeout

	_check("a wrong pattern is not repaired", not GameState.is_component_repaired("Server"))
	_check("failure feedback is shown", recovery.get_node("%FeedbackLabel").text == "That wasn't the right fix. Try again.")
	_check("Retry is offered after a failed pattern", recovery.get_node("%RetryButton").visible)
	_check("the same minigame instance is reused for Retry", recovery._active_minigame == game)

	# --- retry, then succeed for real ---
	recovery.get_node("%RetryButton").pressed.emit()
	await get_tree().create_timer(1.2).timeout
	_check("retrying re-runs the preview and accepts input again", game._accepting_input)

	for i in game._target_indices:
		game._tile_buttons[i].pressed.emit()
	game._confirm_button.pressed.emit()
	await get_tree().create_timer(1.2).timeout

	_check("a correct pattern repairs the component", GameState.is_component_repaired("Server"))
	_check("recovery returns to the network view after success", recovery.get_node("%NetworkView").visible)

	var restored_button: Button = _find_component_button(recovery, "Server")
	_check("Server now shows RESTORED and is no longer selectable", "RESTORED" in restored_button.text and restored_button.disabled)


## Database is configured (ScenarioDatabase) to use the Sequence Puzzle minigame.
func _run_sequence_puzzle_case(recovery: Node) -> void:
	var database_button: Button = _find_component_button(recovery, "Database")
	_check("Database is damaged and selectable", database_button != null and not database_button.disabled)
	database_button.pressed.emit()
	await get_tree().process_frame

	_check("a real minigame instance was created for Database", recovery._active_minigame != null)
	var game: Control = recovery._active_minigame

	# Sequence length is 3 and each flash step takes _FLASH_SECONDS + _GAP_SECONDS;
	# give it comfortable margin to finish playing the sequence back.
	await get_tree().create_timer(2.5).timeout
	_check("sequence minigame finished playback and now accepts input", game._accepting_input)
	_check("sequence minigame picked a 3-step sequence", game._sequence.size() == 3)

	# --- deliberate failure: press a pad that is NOT the first step ---
	var wrong_index: int = 0 if game._sequence[0] != 0 else 1
	game._pad_buttons[wrong_index].pressed.emit()
	await get_tree().create_timer(0.6).timeout

	_check("a wrong first press is not repaired", not GameState.is_component_repaired("Database"))
	_check("failure feedback is shown for the sequence puzzle", recovery.get_node("%FeedbackLabel").text == "That wasn't the right fix. Try again.")
	_check("Retry is offered after a failed sequence", recovery.get_node("%RetryButton").visible)

	# --- retry, then succeed for real ---
	recovery.get_node("%RetryButton").pressed.emit()
	await get_tree().create_timer(2.5).timeout
	_check("retrying re-plays the sequence and accepts input again", game._accepting_input)

	var sequence: Array = game._sequence.duplicate()
	for step in sequence:
		game._pad_buttons[step].pressed.emit()
		await get_tree().create_timer(0.35).timeout

	# Sequence success path has its own internal delays (gap + result pause) before
	# emitting `finished`, and Recovery waits again after that before switching views --
	# give it comfortable margin rather than racing it.
	await get_tree().create_timer(1.2).timeout

	_check("pressing the sequence back correctly repairs the component", GameState.is_component_repaired("Database"))
	# Database was the last damaged component, so this success also completes Recovery
	# outright (straight to the complete panel) rather than returning to the network view
	# -- that full-completion transition is asserted by the caller.
	_check("minigame panel closes once the sequence succeeds", not recovery.get_node("%MinigamePanel").visible)


func _find_component_button(recovery: Node, component_name: String) -> Button:
	for child in recovery.get_node("%ComponentList").get_children():
		if child is Button and String(child.text).begins_with(component_name):
			return child
	return null


func _check(label: String, condition: bool) -> void:
	print("[PASS] %s" % label if condition else "[FAIL] %s" % label)
