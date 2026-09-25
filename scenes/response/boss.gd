extends RefCounted
## Generic data-driven boss engine. Any cybersecurity threat becomes a playable Response
## boss by providing data in this shape under its scenario's `response.boss` -- adding a
## new threat means writing new data (see ScenarioDatabase's credential_abuse entry),
## never a new script. response.gd owns the turn loop, energy, and card-effect
## resolution unchanged; this class owns only the boss's own identity, HP, and intent
## behavior.
##
## Required boss data:
##   id, name, max_hp,
##   intents: [ { id, label, description, damage, component, damage_growth? }, ... ]
##
## Optional reactive behavior (a boss "reacting to player actions" without needing
## per-threat code): once the player's System Integrity falls to/below
## reactive_threshold_percent, the boss permanently switches to reactive_intent_id.
##
## Optional escalation ("special behavior" without per-threat code): an intent with
## damage_growth adds that much extra damage every time it has previously been used,
## representing an attack that gets worse the longer it goes unchecked.

var id: String = ""
var display_name: String = ""
var max_hp: int = 100
var hp: int = 100
var intents: Array = []
var reactive_intent_id: String = ""
var reactive_threshold_percent: int = 0

var _intent_index: int = 0
var _use_counts: Dictionary = {}
var _reactive_triggered: bool = false


func configure(data: Dictionary) -> void:
	id = String(data.get("id", ""))
	display_name = String(data.get("name", ""))
	max_hp = max(1, int(data.get("max_hp", 100)))
	hp = max_hp
	intents = data.get("intents", [])
	reactive_intent_id = String(data.get("reactive_intent_id", ""))
	reactive_threshold_percent = int(data.get("reactive_threshold_percent", 0))


func current_intent() -> Dictionary:
	if intents.is_empty():
		return {}
	return intents[_intent_index % intents.size()]


## Lets the boss react to the player's current state before its intent is shown to
## them -- e.g. pressing the advantage with a specific intent once the player is
## vulnerable, rather than blindly cycling through a fixed rotation regardless of how
## the fight is going.
func update_intent_for_player_state(integrity_percent: float) -> void:
	if _reactive_triggered or reactive_intent_id == "":
		return
	if integrity_percent > float(reactive_threshold_percent):
		return
	for i in intents.size():
		if String(intents[i].get("id", "")) == reactive_intent_id:
			_intent_index = i
			_reactive_triggered = true
			return


func current_damage() -> int:
	var intent: Dictionary = current_intent()
	var base: int = int(intent.get("damage", 0))
	var growth: int = int(intent.get("damage_growth", 0))
	var used: int = int(_use_counts.get(String(intent.get("id", "")), 0))
	return base + growth * used


func current_component() -> String:
	return String(current_intent().get("component", ""))


func current_label() -> String:
	return String(current_intent().get("label", "UNKNOWN"))


func current_description() -> String:
	return String(current_intent().get("description", ""))


## Executes the current intent (call once per End Turn): returns what happened
## ({damage, component}) and advances the rotation to the next intent.
func execute_intent() -> Dictionary:
	var intent: Dictionary = current_intent()
	var damage: int = current_damage()
	var component: String = current_component()
	var intent_id: String = String(intent.get("id", ""))
	_use_counts[intent_id] = int(_use_counts.get(intent_id, 0)) + 1
	_intent_index += 1
	return {"damage": damage, "component": component}


## Receives card-effect damage against the boss's own HP.
func take_damage(amount: int) -> void:
	hp = clampi(hp - amount, 0, max_hp)


func is_defeated() -> bool:
	return hp <= 0
