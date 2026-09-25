extends Node
## Bootstrap for the Monitoring smoke test. Spawns a permanent watcher directly under
## the tree root (so it survives every scene change the flow triggers), then hands off
## to the Scenario Book -- the same entry point a real player uses after Title Menu.

func _ready() -> void:
	var watcher := preload("res://tests/monitoring_watcher.gd").new()
	get_tree().root.add_child.call_deferred(watcher)
	get_tree().change_scene_to_file.call_deferred("res://scenes/menus/scenario_book.tscn")
