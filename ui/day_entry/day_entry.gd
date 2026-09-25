extends Button
## One selectable row in the Scenario Book: "Day X - <status>". Locked days are
## disabled and dimmed; unlocked days emit day_selected when clicked.

signal day_selected(day: int)

var day: int = 0


func setup(new_day: int, label_text: String, locked: bool) -> void:
	day = new_day
	text = label_text
	disabled = locked
	modulate = Color(0.5, 0.5, 0.5, 1.0) if locked else Color(1, 1, 1, 1)


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	day_selected.emit(day)
