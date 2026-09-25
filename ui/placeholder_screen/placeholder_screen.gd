extends Control
## Minimal reusable placeholder screen: a heading, a message, and a Back button that
## returns to a configurable scene. Used for Settings, Credits, and the not-yet-built
## Scenario Book entry point until each gets real content.

@export var heading: String = "Placeholder"
@export var message: String = "This screen is not implemented yet."
@export var return_scene_path: String = "res://scenes/menus/title_menu.tscn"

@onready var _heading_label: Label = %HeadingLabel
@onready var _message_label: Label = %MessageLabel
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_heading_label.text = heading
	_message_label.text = message
	_back_button.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(return_scene_path)
