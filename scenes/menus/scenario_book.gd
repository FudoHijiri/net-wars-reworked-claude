extends Control
## Book-style scenario/day selection screen. Reads every day from ScenarioDatabase and
## its unlocked/completed status from GameState, so adding a new threat later (one more
## entry in ScenarioDatabase) requires no changes here.

const DAY_ENTRY_SCENE := preload("res://ui/day_entry/day_entry.tscn")

@onready var _day_list: VBoxContainer = %DayList
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_populate_days()


func _populate_days() -> void:
	for day in range(1, ScenarioDatabase.get_day_count() + 1):
		var scenario: Dictionary = ScenarioDatabase.get_scenario_for_day(day)
		var locked: bool = not GameState.is_day_unlocked(day)
		var completed: bool = not locked and scenario.has("id") and GameState.is_scenario_completed(scenario.id)

		var label_text: String
		if locked:
			label_text = "Day %d - LOCKED" % day
		elif completed:
			label_text = "Day %d - %s" % [day, scenario.get("threat_name", "???")]
		else:
			label_text = "Day %d - ???" % day

		var entry = DAY_ENTRY_SCENE.instantiate()
		_day_list.add_child(entry)
		entry.setup(day, label_text, locked)
		entry.day_selected.connect(_on_day_selected)


func _on_day_selected(day: int) -> void:
	ScenarioFlow.begin_scenario(day)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/title_menu.tscn")
