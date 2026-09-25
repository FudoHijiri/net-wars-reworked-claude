extends Node
## Automated smoke test for the Scenario Book / day-selection system. Verifies initial
## lock/unlock/??? display, then simulates completing Day 1 by calling
## GameState.complete_scenario() directly -- the same call the real Response phase will
## eventually make -- and re-opens the book to confirm Day 1 reveals its threat name and
## Day 2 unlocks while Day 3 stays locked. Not part of the shipped game.

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var book = get_tree().current_scene
	_check("Scenario Book launched", book != null and book.scene_file_path == "res://scenes/menus/scenario_book.tscn")

	var day_list = book.get_node("%DayList")
	_check("book lists all 8 days", day_list.get_child_count() == 8)

	var day1 = day_list.get_child(0)
	var day2 = day_list.get_child(1)
	var day3 = day_list.get_child(2)

	_check("Day 1 shows '???' before completion", day1.text == "Day 1 - ???")
	_check("Day 1 is unlocked (not disabled)", not day1.disabled)
	_check("Day 2 shows LOCKED", day2.text == "Day 2 - LOCKED")
	_check("Day 2 is disabled", day2.disabled)
	_check("Day 3 shows LOCKED", day3.text == "Day 3 - LOCKED")
	_check("Day 3 is disabled", day3.disabled)

	# Select Day 1 through the real button, exactly like a player click.
	day1.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	var scenario_intro = get_tree().current_scene
	_check("selecting Day 1 opens the Scenario Intro", scenario_intro != null and scenario_intro.scene_file_path == "res://scenes/scenario_flow/scenario_intro.tscn")
	_check("GameState.start_scenario set scenario_id", GameState.scenario_id == "credential_abuse")
	_check("GameState.start_scenario set current_day", GameState.current_day == 1)

	# Simulate the (not-yet-built) Response phase finishing the scenario.
	GameState.complete_scenario()
	_check("Day 1 marked completed in GameState", GameState.is_scenario_completed("credential_abuse"))
	_check("Day 2 unlocked in GameState", GameState.is_day_unlocked(2))

	get_tree().change_scene_to_file("res://scenes/menus/scenario_book.tscn")
	await get_tree().process_frame
	await get_tree().process_frame

	book = get_tree().current_scene
	day_list = book.get_node("%DayList")
	day1 = day_list.get_child(0)
	day2 = day_list.get_child(1)
	day3 = day_list.get_child(2)

	_check("Day 1 reveals threat name after completion", day1.text == "Day 1 - Credential Abuse")
	_check("Day 2 is now unlocked and shows '???'", day2.text == "Day 2 - ???" and not day2.disabled)
	_check("Day 3 still LOCKED", day3.text == "Day 3 - LOCKED" and day3.disabled)

	print("=== SCENARIO BOOK TEST COMPLETE ===")
	get_tree().quit()


func _check(label: String, condition: bool) -> void:
	print("[PASS] %s" % label if condition else "[FAIL] %s" % label)
