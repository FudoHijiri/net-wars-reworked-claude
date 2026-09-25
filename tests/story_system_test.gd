extends Control
## Automated smoke test for the reusable story/dialogue system (DialogueBox.play()).
## Instantiates the presenter directly, feeds it a small sample sequence, and verifies
## speaker/text display, advancing through lines, clean completion, the `finished`
## signal, and the scene-completion callback -- without touching any menu/scenario
## scene. Not part of the shipped game.

const SAMPLE_SEQUENCE := {
	"background": null,
	"lines": [
		{"speaker": "Analyst", "text": "Morning briefing: nothing unusual overnight.", "position": "left"},
		{"speaker": "IT Director", "text": "Good. Keep an eye on the new monitoring dashboards today.", "position": "right"},
		{"speaker": "Analyst", "text": "Will do. I'll flag anything that looks off.", "position": "left"},
	],
}

var _signal_fired := false
var _callback_fired := false


func _ready() -> void:
	var dialogue_box = preload("res://ui/dialogue_box/dialogue_box.tscn").instantiate()
	add_child(dialogue_box)
	dialogue_box.finished.connect(_on_finished)

	dialogue_box.play(SAMPLE_SEQUENCE, _on_scene_complete)

	_check("sequence loads and shows the first line", dialogue_box.is_active())
	_check("first line shows correct speaker", dialogue_box.current_line.get("speaker", "") == "Analyst")
	_check("first line shows correct text", dialogue_box.current_line.get("text", "") == SAMPLE_SEQUENCE["lines"][0]["text"])

	dialogue_box.advance()
	_check("advances to second line's speaker", dialogue_box.current_line.get("speaker", "") == "IT Director")
	_check("advances to second line's text", dialogue_box.current_line.get("text", "") == SAMPLE_SEQUENCE["lines"][1]["text"])

	dialogue_box.advance()
	_check("advances to third line's speaker", dialogue_box.current_line.get("speaker", "") == "Analyst")
	_check("advances to third line's text", dialogue_box.current_line.get("text", "") == SAMPLE_SEQUENCE["lines"][2]["text"])

	dialogue_box.advance()
	_check("sequence ends cleanly (no longer active)", not dialogue_box.is_active())
	_check("finished signal emitted", _signal_fired)
	_check("scene completion callback fired", _callback_fired)

	print("=== STORY SYSTEM TEST COMPLETE ===")
	get_tree().quit()


func _on_finished() -> void:
	_signal_fired = true


func _on_scene_complete() -> void:
	_callback_fired = true


func _check(label: String, condition: bool) -> void:
	print("[PASS] %s" % label if condition else "[FAIL] %s" % label)
