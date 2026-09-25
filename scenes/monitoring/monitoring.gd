extends Control
## Monitoring phase: a short observation/anomaly-detection game. The player watches
## live activity across four perspectives (Computer/Login/Network/Server), inspects
## events, and reports the ones that look suspicious. All scenario-specific content --
## which events exist, which view they belong to, whether reporting them is correct,
## how long the session lasts -- comes from
## ScenarioDatabase.get_scenario_by_id(GameState.scenario_id).monitoring. Nothing about
## a specific threat is hardcoded here.
##
## This is deliberately NOT tower defense and has no combat: events never attack
## anything, they only accumulate for the player to review and judge.

const _VIEW_KEYS := ["computer", "login", "network", "server"]

const _SPAWN_INTERVAL := 4.0

const _POINTS_CORRECT := 20
const _POINTS_CORRECT_IMPORTANT := 30
const _POINTS_FALSE := -10

const _TUTORIAL_HINTS := [
	"Switch between the four views to see what's happening across the network.",
	"Click an event in the list to inspect it.",
	"If it looks suspicious, use Report Anomaly.",
	"Not every unusual event is a real threat -- read the details carefully before reporting.",
]

@onready var _hint_banner: Control = %HintBanner
@onready var _hint_label: Label = %HintLabel

@onready var _time_label: Label = %TimeLabel
@onready var _security_points_label: Label = %SecurityPointsLabel
@onready var _event_list: VBoxContainer = %EventList

@onready var _detail_panel: Control = %DetailPanel
@onready var _detail_title_label: Label = %DetailTitleLabel
@onready var _detail_fields_list: VBoxContainer = %DetailFieldsList
@onready var _report_feedback_label: Label = %ReportFeedbackLabel
@onready var _report_button: Button = %ReportButton

@onready var _complete_panel: Control = %CompletePanel
@onready var _summary_label: Label = %SummaryLabel
@onready var _continue_button: Button = %ContinueButton

var _monitoring_data: Dictionary = {}
var _current_view: String = "computer"
var _current_event: Dictionary = {}
var _pending_events: Array = []
var _spawned_events: Array = []
var _reported_ids: Array = []

var _correct_reports: int = 0
var _false_reports: int = 0
var _report_count: int = 0

var _time_left: float = 0.0
var _spawn_elapsed: float = 0.0
var _ended: bool = false

var _tutorial_active: bool = false
var _tutorial_step: int = 0


func _ready() -> void:
	var scenario: Dictionary = ScenarioDatabase.get_scenario_by_id(GameState.scenario_id)
	_monitoring_data = scenario.get("monitoring", {})
	_pending_events = _monitoring_data.get("events", []).duplicate()
	_time_left = float(_monitoring_data.get("duration_seconds", 30))

	for view_key in _VIEW_KEYS:
		var button: Button = get_node("%" + _view_button_name(view_key))
		button.pressed.connect(_on_view_button_pressed.bind(view_key))

	_report_button.pressed.connect(_on_report_pressed)
	%CloseDetailButton.pressed.connect(_close_detail)
	_continue_button.pressed.connect(_on_continue_pressed)

	_tutorial_active = not GameState.monitoring_tutorial_completed
	_update_hint_banner()

	_detail_panel.visible = false
	_complete_panel.visible = false

	_set_view("computer")
	_update_time_label()
	_update_points_label()


func _process(delta: float) -> void:
	if _ended:
		return

	_time_left = max(_time_left - delta, 0.0)
	_update_time_label()

	_spawn_elapsed += delta
	if _spawn_elapsed >= _SPAWN_INTERVAL:
		_spawn_elapsed = 0.0
		_spawn_next_event()

	if _time_left <= 0.0:
		_end_monitoring()


func _view_button_name(view_key: String) -> String:
	return view_key.capitalize() + "ViewButton"


func _on_view_button_pressed(view_key: String) -> void:
	_set_view(view_key)
	_advance_tutorial(0)


func _set_view(view_key: String) -> void:
	_current_view = view_key
	_populate_event_list()


func _populate_event_list() -> void:
	for child in _event_list.get_children():
		child.free()

	for event in _spawned_events:
		if event.get("view", "") != _current_view:
			continue
		var button := Button.new()
		var prefix: String = "[Reported] " if _reported_ids.has(event.get("id", "")) else ""
		button.text = prefix + String(event.get("summary", ""))
		button.pressed.connect(_on_event_selected.bind(event))
		_event_list.add_child(button)


## Spawns the next scripted event (if any remain) into the feed and refreshes the
## current view if it belongs there. A plain function (not a Timer signal) so automated
## tests can also call it directly to fast-forward past the real-time spawn interval.
func _spawn_next_event() -> void:
	if _pending_events.is_empty():
		return
	var event: Dictionary = _pending_events.pop_front()
	_spawned_events.append(event)
	if event.get("view", "") == _current_view:
		_populate_event_list()


func _on_event_selected(event: Dictionary) -> void:
	_current_event = event
	_detail_title_label.text = String(event.get("title", "EVENT DETAILS"))
	_report_feedback_label.text = ""

	for child in _detail_fields_list.get_children():
		child.free()
	for field in event.get("details", []):
		var label := Label.new()
		label.text = "%s: %s" % [field.get("label", ""), field.get("value", "")]
		_detail_fields_list.add_child(label)

	_report_button.disabled = _reported_ids.has(String(event.get("id", "")))

	_detail_panel.visible = true
	_advance_tutorial(1)


func _close_detail() -> void:
	_detail_panel.visible = false


func _on_report_pressed() -> void:
	var event_id: String = String(_current_event.get("id", ""))
	if event_id == "" or _reported_ids.has(event_id):
		return

	_reported_ids.append(event_id)
	var correct: bool = _current_event.get("should_report", false)
	var important: bool = _current_event.get("important", false)
	var points: int

	if correct:
		points = _POINTS_CORRECT_IMPORTANT if important else _POINTS_CORRECT
		_correct_reports += 1
		_report_feedback_label.text = "Reported. +%d Security Points." % points
	else:
		points = _POINTS_FALSE
		_false_reports += 1
		_report_feedback_label.text = "That activity was legitimate. %d Security Points." % points

	GameState.security_points = max(0, GameState.security_points + points)
	GameState.reported_anomalies.append({"event_id": event_id, "correct": correct})
	_update_points_label()

	_report_button.disabled = true
	_report_count += 1

	_advance_tutorial(2)
	if _report_count >= 2:
		_advance_tutorial(3)

	_populate_event_list()


func _update_time_label() -> void:
	var seconds: int = int(ceil(_time_left))
	@warning_ignore("integer_division")
	var minutes: int = seconds / 60
	_time_label.text = "Time Remaining: %d:%02d" % [minutes, seconds % 60]


func _update_points_label() -> void:
	_security_points_label.text = "Security Points: %d" % GameState.security_points


func _end_monitoring() -> void:
	if _ended:
		return
	_ended = true

	if _tutorial_active:
		_tutorial_active = false
		GameState.complete_tutorial("monitoring")
		_update_hint_banner()

	GameState.monitoring_score = _correct_reports - _false_reports

	_detail_panel.visible = false
	_summary_label.text = "Correct Reports: %d\nFalse Reports: %d\nSecurity Points: %d" % [_correct_reports, _false_reports, GameState.security_points]
	_complete_panel.visible = true


func _on_continue_pressed() -> void:
	ScenarioFlow.on_phase_complete()


func _advance_tutorial(step_just_done: int) -> void:
	if not _tutorial_active or step_just_done != _tutorial_step:
		return
	_tutorial_step += 1
	if _tutorial_step >= _TUTORIAL_HINTS.size():
		_tutorial_active = false
		GameState.complete_tutorial("monitoring")
	_update_hint_banner()


func _update_hint_banner() -> void:
	_hint_banner.visible = _tutorial_active
	if _tutorial_active:
		_hint_label.text = _TUTORIAL_HINTS[_tutorial_step]
