extends Node
## Bootstrap for the repair-minigames smoke test. Spawns a permanent watcher directly
## under the tree root, then hands off to the Recovery scene directly -- this test only
## needs Recovery itself with a couple of components pre-damaged, not the whole Day flow.

func _ready() -> void:
	var watcher := preload("res://tests/recovery_minigames_watcher.gd").new()
	get_tree().root.add_child.call_deferred(watcher)
