extends Control
## Opening visual-novel-style introduction. Plays a short placeholder story beat, then
## hands off to the Title Menu. Uses the reusable DialogueBox story system so the same
## presenter can run every other story beat (scenario intro, between-objective dialogue,
## scenario conclusion) from new data alone -- no new presenter script per conversation.

const INTRO_SEQUENCE := {
	"background": null,
	"lines": [
		{"speaker": "Unknown Voice", "text": "Something is happening on the network. Alerts have started coming in overnight.", "position": "center"},
		{"speaker": "Unknown Voice", "text": "You've just been assigned as the organization's newest security analyst.", "position": "center"},
		{"speaker": "Unknown Voice", "text": "Your job: investigate incidents, contain the damage, and keep the organization running.", "position": "center"},
		{"speaker": "Unknown Voice", "text": "Let's see what's waiting for you today.", "position": "center"},
	],
}

@onready var _dialogue_box = %DialogueBox


func _ready() -> void:
	_dialogue_box.play(INTRO_SEQUENCE, _on_intro_finished)


func _on_intro_finished() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/title_menu.tscn")
