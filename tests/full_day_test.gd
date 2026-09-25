extends Node
## Bootstrap for the full Day 1 integration smoke test. Spawns a permanent watcher
## directly under the tree root (so it survives every scene change the real flow
## triggers), then hands off to the real game entry point exactly as a normal launch
## would -- no manual scene changes anywhere in this test.

func _ready() -> void:
	var watcher := preload("res://tests/full_day_watcher.gd").new()
	get_tree().root.add_child.call_deferred(watcher)
	get_tree().change_scene_to_file.call_deferred("res://scenes/boot/intro.tscn")
