extends Node
## One-off automated smoke test for the opening flow (Intro -> Title Menu -> placeholder
## screens -> back -> Exit wiring check). Not part of the shipped game. Added directly
## under the tree root by opening_flow_test.tscn so it survives every real scene change
## the flow triggers, then drives the actual production scenes by emitting their real
## button signals -- exercising the same code paths a player's click would.

const FIRST_LINE_TEXT := "Something is happening on the network. Alerts have started coming in overnight."


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var scene := get_tree().current_scene
	_check("Intro scene launched", scene != null and scene.scene_file_path == "res://scenes/boot/intro.tscn")

	var dialogue_box = scene.get_node("%DialogueBox")
	_check("first dialogue line shown", dialogue_box.current_line.get("text", "") == FIRST_LINE_TEXT)

	dialogue_box.advance()
	_check("dialogue advances to a new line", dialogue_box.current_line.get("text", "") != FIRST_LINE_TEXT)

	dialogue_box.skip()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	_check("skip finishes intro and reaches Title Menu", scene != null and scene.scene_file_path == "res://scenes/menus/title_menu.tscn")

	await _check_play_button()
	await _check_menu_button("SettingsButton", "res://scenes/menus/settings_screen.tscn", "Settings")
	await _check_menu_button("CreditsButton", "res://scenes/menus/credits_screen.tscn", "Credits")

	scene = get_tree().current_scene
	var exit_button: Button = scene.get_node("%ExitButton")
	_check("Exit button is wired to a handler", exit_button.pressed.get_connections().size() > 0)

	print("=== OPENING FLOW TEST COMPLETE ===")
	get_tree().quit()


func _check_play_button() -> void:
	var title_menu_scene := get_tree().current_scene
	var play_button: Button = title_menu_scene.get_node("%PlayButton")
	play_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	var target := get_tree().current_scene
	_check("PlayButton opens res://scenes/menus/scenario_book.tscn", target != null and target.scene_file_path == "res://scenes/menus/scenario_book.tscn")

	var day_list = target.get_node("%DayList")
	_check("Scenario Book lists days", day_list.get_child_count() > 0)

	var back_button: Button = target.get_node("%BackButton")
	back_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	var back_to := get_tree().current_scene
	_check("Back from Scenario Book returns to Title Menu", back_to != null and back_to.scene_file_path == "res://scenes/menus/title_menu.tscn")


func _check_menu_button(button_unique_name: String, expected_path: String, expected_heading: String) -> void:
	var title_menu_scene := get_tree().current_scene
	var button: Button = title_menu_scene.get_node("%" + button_unique_name)
	button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	var target := get_tree().current_scene
	_check("%s opens %s" % [button_unique_name, expected_path], target != null and target.scene_file_path == expected_path)

	var heading_label: Label = target.get_node("%HeadingLabel")
	_check("%s screen shows heading '%s'" % [button_unique_name, expected_heading], heading_label.text == expected_heading)

	var back_button: Button = target.get_node("%BackButton")
	back_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	var back_to := get_tree().current_scene
	_check("Back from %s returns to Title Menu" % button_unique_name, back_to != null and back_to.scene_file_path == "res://scenes/menus/title_menu.tscn")


func _check(label: String, condition: bool) -> void:
	print("[PASS] %s" % label if condition else "[FAIL] %s" % label)
