extends Node
## Bootstrap for the Scenario Book smoke test. Spawns a permanent watcher directly under
## the tree root (so it survives every scene change the flow triggers), then hands off
## straight to the Scenario Book -- Intro and Title Menu are covered by their own test
## harness and aren't re-tested here.

func _ready() -> void:
	var watcher := preload("res://tests/scenario_book_watcher.gd").new()
	get_tree().root.add_child.call_deferred(watcher)
	get_tree().change_scene_to_file.call_deferred("res://scenes/menus/scenario_book.tscn")
