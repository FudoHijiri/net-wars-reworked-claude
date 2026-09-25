extends Control
## Investigation phase: a point-and-click evidence search across the Security Desktop's
## eight applications. All scenario-specific content -- which apps contain which
## entries, which entries are real evidence, how many are required -- comes from
## ScenarioDatabase.get_scenario_by_id(GameState.scenario_id).investigation. Nothing
## about a specific threat is hardcoded here; this same scene runs any scenario that
## provides investigation data.
##
## First-time players (GameState.investigation_tutorial_completed == false) see a short
## sequence of hints tied to the real actions below -- open an app, inspect an entry,
## mark evidence, review the evidence log, open the confirmation screen -- rather than a
## separate tutorial level. Later Days skip the hints entirely.

const _APP_KEYS := ["email", "logs", "computers", "login_activity", "files", "network", "servers", "reports"]
const _APP_LABELS := {
	"email": "Email",
	"logs": "Logs",
	"computers": "Computers",
	"login_activity": "Login Activity",
	"files": "Files",
	"network": "Network",
	"servers": "Servers",
	"reports": "Reports",
}

const _TUTORIAL_HINTS := [
	"Click an application on the desktop to open it.",
	"Click an entry in the list to inspect it.",
	"If it looks relevant, use Mark as Evidence to record it.",
	"Open the Evidence Log to review what you've found so far.",
	"When you're ready, use Confirm Threat to state your conclusion.",
]

@onready var _hint_banner: Control = %HintBanner
@onready var _hint_label: Label = %HintLabel

@onready var _desktop_view: Control = %DesktopView
@onready var _app_view: Control = %AppView
@onready var _evidence_view: Control = %EvidenceView
@onready var _threat_view: Control = %ThreatView

@onready var _evidence_log_button: Button = %EvidenceLogButton

@onready var _app_title_label: Label = %AppTitleLabel
@onready var _entry_list: VBoxContainer = %EntryList
@onready var _detail_panel: Control = %DetailPanel
@onready var _detail_label: Label = %DetailLabel
@onready var _mark_feedback_label: Label = %MarkFeedbackLabel
@onready var _mark_evidence_button: Button = %MarkEvidenceButton

@onready var _evidence_list: VBoxContainer = %EvidenceList

@onready var _threat_list: VBoxContainer = %ThreatList
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _confirm_button: Button = %ConfirmButton

var _investigation_data: Dictionary = {}
var _current_entry: Dictionary = {}
var _selected_threat: String = ""

var _tutorial_active: bool = false
var _tutorial_step: int = 0


func _ready() -> void:
	var scenario: Dictionary = ScenarioDatabase.get_scenario_by_id(GameState.scenario_id)
	_investigation_data = scenario.get("investigation", {})

	for app_key in _APP_KEYS:
		var button: Button = get_node("%" + _app_button_name(app_key))
		button.pressed.connect(_on_app_opened.bind(app_key))

	_evidence_log_button.pressed.connect(_on_evidence_log_opened)
	%ConfirmThreatButton.pressed.connect(_on_threat_view_opened)
	%CloseAppButton.pressed.connect(_show_desktop)
	%CloseEvidenceButton.pressed.connect(_show_desktop)
	%CloseThreatButton.pressed.connect(_show_desktop)
	_mark_evidence_button.pressed.connect(_on_mark_evidence_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)

	_tutorial_active = not GameState.investigation_tutorial_completed
	_refresh_evidence_count_label()
	_update_hint_banner()
	_show_desktop()


func _app_button_name(app_key: String) -> String:
	return app_key.capitalize().replace(" ", "") + "Button"


func _show_desktop() -> void:
	_current_entry = {}
	_desktop_view.visible = true
	_app_view.visible = false
	_evidence_view.visible = false
	_threat_view.visible = false


func _on_app_opened(app_key: String) -> void:
	_current_entry = {}
	_app_title_label.text = _APP_LABELS.get(app_key, app_key.capitalize())
	_detail_panel.visible = false
	_populate_entry_list(app_key)

	_desktop_view.visible = false
	_app_view.visible = true
	_evidence_view.visible = false
	_threat_view.visible = false

	_advance_tutorial(0)


func _populate_entry_list(app_key: String) -> void:
	for child in _entry_list.get_children():
		child.free()

	var entries: Array = _investigation_data.get("applications", {}).get(app_key, [])
	for entry in entries:
		var button := Button.new()
		button.text = String(entry.get("title", ""))
		button.pressed.connect(_on_entry_selected.bind(entry))
		_entry_list.add_child(button)


func _on_entry_selected(entry: Dictionary) -> void:
	_current_entry = entry
	_detail_label.text = String(entry.get("detail", ""))
	_mark_feedback_label.text = ""

	var entry_id: String = String(entry.get("id", ""))
	var already_marked: bool = entry.get("is_evidence", false) and GameState.investigation_evidence.has(entry_id)
	_mark_evidence_button.disabled = already_marked

	_detail_panel.visible = true
	_advance_tutorial(1)


func _on_mark_evidence_pressed() -> void:
	var entry_id: String = String(_current_entry.get("id", ""))
	if entry_id == "":
		return

	if _current_entry.get("is_evidence", false):
		if not GameState.investigation_evidence.has(entry_id):
			GameState.investigation_evidence.append(entry_id)
		_mark_feedback_label.text = "Added to the evidence log."
		_mark_evidence_button.disabled = true
		_refresh_evidence_count_label()
	else:
		_mark_feedback_label.text = "This doesn't seem directly relevant to the incident."

	_advance_tutorial(2)


func _on_evidence_log_opened() -> void:
	_populate_evidence_list()

	_desktop_view.visible = false
	_app_view.visible = false
	_evidence_view.visible = true
	_threat_view.visible = false

	_advance_tutorial(3)


func _populate_evidence_list() -> void:
	for child in _evidence_list.get_children():
		child.free()

	if GameState.investigation_evidence.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No evidence collected yet."
		_evidence_list.add_child(empty_label)
		return

	for evidence_id in GameState.investigation_evidence:
		var label := Label.new()
		label.text = "- %s" % _describe_evidence(String(evidence_id))
		_evidence_list.add_child(label)


func _describe_evidence(evidence_id: String) -> String:
	var applications: Dictionary = _investigation_data.get("applications", {})
	for app_key in _APP_KEYS:
		for entry in applications.get(app_key, []):
			if entry.get("id", "") == evidence_id:
				return String(entry.get("title", evidence_id))
	return evidence_id


func _on_threat_view_opened() -> void:
	_selected_threat = ""
	_feedback_label.text = ""
	_populate_threat_list()

	_desktop_view.visible = false
	_app_view.visible = false
	_evidence_view.visible = false
	_threat_view.visible = true

	_advance_tutorial(4)


func _populate_threat_list() -> void:
	for child in _threat_list.get_children():
		child.free()

	for threat_name in _get_all_threat_names():
		var button := Button.new()
		button.text = threat_name
		button.toggle_mode = true
		button.pressed.connect(_on_threat_option_pressed.bind(threat_name))
		_threat_list.add_child(button)


func _get_all_threat_names() -> Array:
	var names: Array = []
	for scenario in ScenarioDatabase.SCENARIOS:
		names.append(scenario.get("threat_name", ""))
	return names


func _on_threat_option_pressed(threat_name: String) -> void:
	_selected_threat = threat_name
	_feedback_label.text = ""
	for child in _threat_list.get_children():
		if child is Button:
			child.button_pressed = (child.text == threat_name)


func _on_confirm_pressed() -> void:
	if _selected_threat == "":
		_feedback_label.text = "Select a suspected threat first."
		return

	var required_count: int = int(_investigation_data.get("required_evidence_count", 0))
	var evidence_count: int = GameState.investigation_evidence.size()

	if evidence_count < required_count:
		_feedback_label.text = "The evidence is inconsistent or insufficient. Keep investigating."
		return

	var scenario: Dictionary = ScenarioDatabase.get_scenario_by_id(GameState.scenario_id)
	var correct_threat: String = String(scenario.get("threat_name", ""))

	if _selected_threat != correct_threat:
		_feedback_label.text = "That doesn't match the evidence. Review your findings and try again."
		return

	GameState.identified_threat = correct_threat
	ScenarioFlow.on_phase_complete()


func _refresh_evidence_count_label() -> void:
	_evidence_log_button.text = "Evidence Log (%d)" % GameState.investigation_evidence.size()


func _advance_tutorial(step_just_done: int) -> void:
	if not _tutorial_active or step_just_done != _tutorial_step:
		return
	_tutorial_step += 1
	if _tutorial_step >= _TUTORIAL_HINTS.size():
		_tutorial_active = false
		GameState.complete_tutorial("investigation")
	_update_hint_banner()


func _update_hint_banner() -> void:
	_hint_banner.visible = _tutorial_active
	if _tutorial_active:
		_hint_label.text = _TUTORIAL_HINTS[_tutorial_step]
