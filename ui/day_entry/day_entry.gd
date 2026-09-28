extends Button
## One selectable row in the Scenario Book: "Day X - <status>". Locked days use the
## "DayLocked" theme variation (dim, flat) and unlocked days use "DayUnlocked" (bright,
## cyan-bordered case-file look) -- see assets/ui/theme.tres. Locked days are disabled;
## unlocked days emit day_selected when clicked.

signal day_selected(day: int)

var day: int = 0


func setup(new_day: int, label_text: String, locked: bool) -> void:
	day = new_day
	text = label_text
	disabled = locked
	theme_type_variation = &"DayLocked" if locked else &"DayUnlocked"
	custom_minimum_size = Vector2(330, 68)
	alignment = HORIZONTAL_ALIGNMENT_LEFT


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	day_selected.emit(day)
