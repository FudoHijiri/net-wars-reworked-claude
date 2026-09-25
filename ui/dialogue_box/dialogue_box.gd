extends Control
## Reusable visual-novel-style story/dialogue presenter. Feed it a "sequence":
## { "background": Texture2D (optional), "lines": [ { "speaker": String, "text": String,
## "portrait": Texture2D (optional), "position": "left"|"center"|"right" (optional) }, ... ] }
## and it shows one line at a time -- with a placeholder background and a positioned
## character placeholder -- advancing on Continue and jumping to the end on Skip.
##
## This is the one presenter meant to run every story beat (opening intro, scenario
## intro, between-objective dialogue, scenario conclusion): a new conversation is new
## sequence data passed to play(), never a new presenter script.

signal line_shown(index: int, line: Dictionary)
signal finished

@export var portrait_placeholder: Texture2D = preload("res://icon.svg")

const _POSITION_ANCHORS := {
	"left": {"left": 0.02, "right": 0.32},
	"center": {"left": 0.35, "right": 0.65},
	"right": {"left": 0.68, "right": 0.98},
}

@onready var _background_image: TextureRect = %BackgroundImage
@onready var _portrait_rect: TextureRect = %PortraitRect
@onready var _speaker_label: Label = %SpeakerLabel
@onready var _dialogue_label: Label = %DialogueLabel
@onready var _skip_button: Button = %SkipButton
@onready var _continue_button: Button = %ContinueButton

var lines: Array = []
var current_line: Dictionary:
	get:
		if _index >= 0 and _index < lines.size():
			return lines[_index]
		return {}

var _index: int = -1
var _active: bool = false
var _on_complete: Callable = Callable()


func _ready() -> void:
	_continue_button.pressed.connect(advance)
	_skip_button.pressed.connect(skip)


## Begins presenting a new story sequence. `on_complete`, if given, is called with no
## arguments when the sequence finishes -- in addition to the `finished` signal, so
## callers can use whichever fits (a direct callback, or connecting to the signal).
func play(sequence: Dictionary, on_complete: Callable = Callable()) -> void:
	lines = sequence.get("lines", [])
	_on_complete = on_complete
	_apply_background(sequence.get("background", null))
	_index = -1
	_active = true
	visible = true
	advance()


## Shows the next line, or finishes if there is none.
func advance() -> void:
	if not _active:
		return
	_index += 1
	if _index >= lines.size():
		_finish()
		return
	_show_line(lines[_index])


## Ends the sequence immediately without showing any remaining lines.
func skip() -> void:
	if not _active:
		return
	_finish()


func is_active() -> bool:
	return _active


func _show_line(line: Dictionary) -> void:
	_speaker_label.text = String(line.get("speaker", ""))
	_dialogue_label.text = String(line.get("text", ""))

	var portrait: Texture2D = line.get("portrait", null)
	_portrait_rect.texture = portrait if portrait != null else portrait_placeholder
	_apply_position(String(line.get("position", "center")))

	line_shown.emit(_index, line)


func _apply_position(character_position: String) -> void:
	var anchors: Dictionary = _POSITION_ANCHORS.get(character_position, _POSITION_ANCHORS["center"])
	_portrait_rect.anchor_left = anchors["left"]
	_portrait_rect.anchor_right = anchors["right"]
	_portrait_rect.offset_left = 0.0
	_portrait_rect.offset_right = 0.0


func _apply_background(background: Texture2D) -> void:
	_background_image.texture = background
	_background_image.visible = background != null


func _finish() -> void:
	_active = false
	finished.emit()
	if _on_complete.is_valid():
		_on_complete.call()
