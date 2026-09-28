extends Control
## Title screen. Play opens the Scenario Book; Settings and Credits open placeholder
## screens; Exit closes the game. No gameplay phase is loaded from here.

@onready var _play_button: Button = %PlayButton
@onready var _settings_button: Button = %SettingsButton
@onready var _credits_button: Button = %CreditsButton
@onready var _exit_button: Button = %ExitButton
@onready var _screen_content: Control = $MonitorFrame/ScreenContent


func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_credits_button.pressed.connect(_on_credits_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_play_power_on_flicker()


## Purely cosmetic "screen powering on" flicker -- never delays or blocks the buttons,
## which are already connected and clickable before this starts.
func _play_power_on_flicker() -> void:
	_screen_content.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_screen_content, "modulate:a", 0.25, 0.05)
	tween.tween_property(_screen_content, "modulate:a", 0.05, 0.04)
	tween.tween_property(_screen_content, "modulate:a", 1.0, 0.12)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/scenario_book.tscn")


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/settings_screen.tscn")


func _on_credits_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/credits_screen.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()
