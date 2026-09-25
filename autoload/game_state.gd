extends Node
## Central state autoload shared by all five gameplay phases.
##
## This script only stores state and manages phase transitions. It contains no gameplay —
## each phase scene is responsible for its own mechanics and for reading/writing the fields
## it owns here so later phases can react to earlier decisions.

signal phase_changed(previous_phase: Phase, new_phase: Phase)
signal scenario_started(scenario_id: String)
signal scenario_completed(scenario_id: String)

enum Phase {
	INVESTIGATION,
	MONITORING,
	HARDENING,
	RESPONSE,
	RECOVERY,
}

const PHASE_ORDER: Array = [
	Phase.INVESTIGATION,
	Phase.MONITORING,
	Phase.HARDENING,
	Phase.RESPONSE,
	Phase.RECOVERY,
]

const DEFAULT_MAX_SYSTEM_INTEGRITY: int = 100

## Baseline set of network components any threat's Response boss can damage. A
## placeholder visual metaphor, not literal network architecture (see CLAUDE.md §8).
const NETWORK_COMPONENTS: Array = ["Server", "Router", "Switch", "Computer", "Database"]

# --- Scenario ---
var scenario_id: String = ""
var current_day: int = 0
var current_threat: String = ""
var current_phase: Phase = Phase.INVESTIGATION

# --- Investigation ---
var investigation_evidence: Array = []
var identified_threat: String = ""

# --- Monitoring ---
var security_points: int = 0
var monitoring_score: int = 0
var reported_anomalies: Array = []

# --- Hardening ---
var purchased_defenses: Array = []
var response_deck: Array = []
var passive_upgrades: Array = []

# --- Response ---
var system_integrity: int = DEFAULT_MAX_SYSTEM_INTEGRITY
var max_system_integrity: int = DEFAULT_MAX_SYSTEM_INTEGRITY
## Array of { "name": String, "damage": int } -- one entry per damaged component, with
## damage accumulating if the same component is hit more than once. Reusable by any
## phase/threat via damage_component()/take_system_damage() below, not Response-only.
var damaged_components: Array = []
## Total System Integrity damage taken this scenario, independent of any healing --
## lets Recovery (or a results screen) reflect how rough the fight was even if the
## final system_integrity number was restored partway back up.
var total_damage_taken: int = 0
var threat_defeated: bool = false
var response_result: String = ""

# --- Recovery ---
var repaired_components: Array = []

# --- Progress (persists across scenarios, not reset by start_scenario) ---
var unlocked_days: Array = [1]
var completed_scenarios: Array = []

# --- Tutorial completion (persists across scenarios, not reset by start_scenario).
# Once true for a phase, later Days skip that phase's tutorial. ---
var investigation_tutorial_completed: bool = false
var monitoring_tutorial_completed: bool = false
var hardening_tutorial_completed: bool = false
var response_tutorial_completed: bool = false
var recovery_tutorial_completed: bool = false


## Begins a new scenario: sets identity fields, resets all per-scenario phase data,
## and returns current_phase to INVESTIGATION.
func start_scenario(new_scenario_id: String, day: int, threat_name: String) -> void:
	scenario_id = new_scenario_id
	current_day = day
	current_threat = threat_name
	_reset_scenario_data()
	set_phase(Phase.INVESTIGATION)
	scenario_started.emit(scenario_id)


## Moves directly to the given phase and notifies listeners. No-op if already in that phase.
func set_phase(new_phase: Phase) -> void:
	if new_phase == current_phase:
		return
	var previous_phase: Phase = current_phase
	current_phase = new_phase
	phase_changed.emit(previous_phase, new_phase)


## Moves to the next phase in the fixed Investigation → Recovery order.
## Returns false (and does nothing) if already in the last phase.
func advance_phase() -> bool:
	var index: int = PHASE_ORDER.find(current_phase)
	if index == -1 or index >= PHASE_ORDER.size() - 1:
		return false
	set_phase(PHASE_ORDER[index + 1])
	return true


## Marks the current scenario as finished: flags it defeated, records it as completed,
## and unlocks the next day. Does not reset per-scenario data — the Recovery/results
## screen may still need to read it after this is called.
func complete_scenario() -> void:
	threat_defeated = true
	if not completed_scenarios.has(scenario_id):
		completed_scenarios.append(scenario_id)
	var next_day: int = current_day + 1
	if not unlocked_days.has(next_day):
		unlocked_days.append(next_day)
	scenario_completed.emit(scenario_id)


func is_day_unlocked(day: int) -> bool:
	return unlocked_days.has(day)


func is_scenario_completed(id: String) -> bool:
	return completed_scenarios.has(id)


## `phase_name` is the lowercase phase key ("investigation", "monitoring", "hardening",
## "response", "recovery").
func is_tutorial_completed(phase_name: String) -> bool:
	match phase_name:
		"investigation":
			return investigation_tutorial_completed
		"monitoring":
			return monitoring_tutorial_completed
		"hardening":
			return hardening_tutorial_completed
		"response":
			return response_tutorial_completed
		"recovery":
			return recovery_tutorial_completed
	return false


func complete_tutorial(phase_name: String) -> void:
	match phase_name:
		"investigation":
			investigation_tutorial_completed = true
		"monitoring":
			monitoring_tutorial_completed = true
		"hardening":
			hardening_tutorial_completed = true
		"response":
			response_tutorial_completed = true
		"recovery":
			recovery_tutorial_completed = true


func get_phase_name(phase: Phase = current_phase) -> String:
	return Phase.keys()[phase]


## Applies System Integrity damage and (if a component is given) records which
## component it hit, with how much. This is the single entry point any phase should
## use to damage the org -- it keeps system_integrity, total_damage_taken, and
## damaged_components consistent with each other automatically.
func take_system_damage(amount: int, component: String = "") -> void:
	if amount <= 0:
		return
	system_integrity = max(0, system_integrity - amount)
	total_damage_taken += amount
	if component != "":
		damage_component(component, amount)


## Marks a component as damaged, or adds to its accumulated damage if it already was.
func damage_component(component_name: String, amount: int) -> void:
	for entry in damaged_components:
		if entry.get("name", "") == component_name:
			entry["damage"] = int(entry.get("damage", 0)) + amount
			return
	damaged_components.append({"name": component_name, "damage": amount})


func is_component_damaged(component_name: String) -> bool:
	for entry in damaged_components:
		if entry.get("name", "") == component_name:
			return true
	return false


func get_component_damage(component_name: String) -> int:
	for entry in damaged_components:
		if entry.get("name", "") == component_name:
			return int(entry.get("damage", 0))
	return 0


## Every component from NETWORK_COMPONENTS that hasn't taken damage this scenario.
func get_safe_components() -> Array:
	var safe: Array = []
	for component_name in NETWORK_COMPONENTS:
		if not is_component_damaged(component_name):
			safe.append(component_name)
	return safe


## Marks a component restored during Recovery. Safe to call more than once for the
## same component -- it won't be recorded twice.
func repair_component(component_name: String) -> void:
	if not repaired_components.has(component_name):
		repaired_components.append(component_name)


func is_component_repaired(component_name: String) -> bool:
	return repaired_components.has(component_name)


## Recovery succeeds once every component Response damaged has been repaired. True
## (vacuously) if nothing was damaged in the first place.
func all_damaged_components_repaired() -> bool:
	for entry in damaged_components:
		if not is_component_repaired(String(entry.get("name", ""))):
			return false
	return true


func _reset_scenario_data() -> void:
	investigation_evidence = []
	identified_threat = ""

	security_points = 0
	monitoring_score = 0
	reported_anomalies = []

	purchased_defenses = []
	response_deck = []
	passive_upgrades = []

	system_integrity = max_system_integrity
	damaged_components = []
	total_damage_taken = 0
	threat_defeated = false
	response_result = ""

	repaired_components = []
