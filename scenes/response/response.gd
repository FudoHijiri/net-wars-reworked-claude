extends Control
## Response phase: Slay-the-Spire-style card combat, adapted from
## D:\GitHub\the-spire\Scripts\PlayUI.gd rather than rebuilt. DeckManager (deck_manager.gd,
## ported unchanged) and the card view (ui/response_card/, adapted from CardNode.gd with
## placeholder art) are reused directly. The card-effect resolver below is the same
## logic-string keyword interpreter the-spire used, trimmed to the keywords Response
## actually needs (Containment/Integrity/Draw/Energy).
##
## The boss itself is a generic, data-driven engine (boss.gd) configured from this
## scenario's response.boss data -- see boss.gd for the full schema. A new threat
## becomes a new boss by writing new data, not new code. `containment` stays as a
## backward-compatible view onto the boss's HP (containment == damage dealt so far,
## i.e. max_hp - hp) so nothing about the turn loop or existing card data had to change
## to adopt real boss HP underneath it.
##
## Required input (read from GameState, set by earlier phases): current_threat,
## response_deck, passive_upgrades, system_integrity.
## Required output (written to GameState for later phases/Recovery): threat_defeated,
## system_integrity, damaged_components, response_result.

const CARD_SCENE := preload("res://ui/response_card/response_card.tscn")
const DeckManagerScript := preload("res://scenes/response/deck_manager.gd")
const BossScript := preload("res://scenes/response/boss.gd")

const _TUTORIAL_HINTS := [
	"This is your hand -- each card shows its Energy cost. Click a card to play it.",
	"Watch the threat's Intent: it shows what will happen to your System Integrity when you end your turn.",
	"Keep playing cards and ending turns until Containment reaches 100 -- that's how you neutralize the threat.",
]

@onready var _hint_banner: Control = %HintBanner
@onready var _hint_label: Label = %HintLabel

@onready var _integrity_label: Label = %IntegrityLabel
@onready var _boss_hp_label: Label = %BossHpLabel
@onready var _energy_label: Label = %EnergyLabel

@onready var _boss_name_label: Label = %BossNameLabel
@onready var _intent_label: Label = %IntentLabel

@onready var _hand_container: HBoxContainer = %HandContainer
@onready var _deck_count_label: Label = %DeckCountLabel
@onready var _discard_count_label: Label = %DiscardCountLabel
@onready var _end_turn_button: Button = %EndTurnButton

@onready var _result_panel: Control = %ResultPanel
@onready var _result_label: Label = %ResultLabel
@onready var _summary_label: Label = %SummaryLabel
@onready var _continue_button: Button = %ContinueButton

var _response_data: Dictionary = {}
var _card_pool: Dictionary = {}
var _base_deck_names: Array = []

var _boss = null

## Backward-compatible view onto the boss's HP: "how much damage has been dealt so
## far," i.e. what the previous non-boss implementation tracked directly. Reading or
## writing this proxies straight to _boss.hp so existing card-effect logic (and tests)
## didn't need to change when the real boss/HP framework was introduced.
var containment: int:
	get:
		return 0 if _boss == null else _boss.max_hp - _boss.hp
	set(value):
		if _boss != null:
			_boss.hp = clampi(_boss.max_hp - value, 0, _boss.max_hp)

var energy: int = 3
var max_energy: int = 3
var hand_size_max: int = 5

var deck_manager = null

var _animating: bool = false
var _ended: bool = false
var _end_turn_count: int = 0

var _tutorial_active: bool = false
var _tutorial_step: int = 0


func _ready() -> void:
	var scenario: Dictionary = ScenarioDatabase.get_scenario_by_id(GameState.scenario_id)
	_response_data = scenario.get("response", {})
	_card_pool = _response_data.get("card_pool", {})
	_base_deck_names = scenario.get("hardening", {}).get("base_deck", [])

	_boss = BossScript.new()
	var boss_data: Dictionary = _response_data.get("boss", {})
	if boss_data.is_empty():
		# Scenarios without boss data yet still get a functional (empty-rotation) boss
		# rather than a crash -- matches the graceful fallback used elsewhere for
		# scenarios that don't have full content yet.
		boss_data = {"id": GameState.scenario_id, "name": GameState.current_threat, "max_hp": 100, "intents": []}
	_boss.configure(boss_data)

	if GameState.passive_upgrades.has("Increased System Integrity"):
		GameState.max_system_integrity += 10
		GameState.system_integrity = GameState.max_system_integrity

	_boss_name_label.text = _boss.display_name.to_upper()

	deck_manager = DeckManagerScript.new()
	deck_manager.initialize(_build_deck())

	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)

	_tutorial_active = not GameState.response_tutorial_completed
	_update_hint_banner()

	_result_panel.visible = false
	_show_intent()
	_start_turn()


## Builds the actual playable deck from GameState.response_deck (a list of card names
## set by Hardening) plus this scenario's card_pool (stats for each name). Base-deck
## cards are duplicated once for a fuller draw pile; Hardening-unlocked cards appear
## once, matching what was actually purchased.
func _build_deck() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card_name in GameState.response_deck:
		var stats: Dictionary = _card_pool.get(card_name, {})
		var copies: int = 2 if _base_deck_names.has(card_name) else 1
		for i in copies:
			result.append({
				"id": card_name,
				"name": card_name,
				"type": stats.get("type", "Response"),
				"energy": int(stats.get("energy", 1)),
				"logic": stats.get("logic", ""),
				"tooltip": stats.get("tooltip", ""),
			})
	return result


func _integrity_percent() -> float:
	if GameState.max_system_integrity <= 0:
		return 0.0
	return float(GameState.system_integrity) / float(GameState.max_system_integrity) * 100.0


func _show_intent() -> void:
	_boss.update_intent_for_player_state(_integrity_percent())
	if _boss.intents.is_empty():
		_intent_label.text = "The threat has no further moves prepared."
		return
	_intent_label.text = "%s\n%s\n(could affect: %s)" % [_boss.current_label(), _boss.current_description(), _boss.current_component()]


func _start_turn() -> void:
	energy = max_energy
	deck_manager.draw_cards(hand_size_max - deck_manager.hand_count())
	_render_hand()
	_update_hud()


func _render_hand() -> void:
	for child in _hand_container.get_children():
		child.free()

	for cdata in deck_manager.hand:
		var node = CARD_SCENE.instantiate()
		_hand_container.add_child(node)
		node.setup(cdata)
		node.set_playable(int(cdata.get("energy", 0)) <= energy)
		node.card_played.connect(_on_card_played)


func _on_card_played(cdata: Dictionary) -> void:
	if _animating or _ended:
		return
	var cost: int = int(cdata.get("energy", 0))
	if cost > energy:
		return

	_animating = true
	energy -= cost
	_apply_card_effect(cdata)

	# Defer the hand rebuild: this handler is still running inside the played card's
	# own signal emission, and freeing that card node synchronously here would try to
	# free a locked object (the-spire's original avoided this with a fly-out animation
	# and await before rendering; a plain frame wait gets the same safety here).
	await get_tree().process_frame

	deck_manager.play_card(cdata)
	_render_hand()
	_update_hud()
	_animating = false
	_advance_tutorial(0)
	_check_win_loss()


## Same keyword-matching approach the-spire used in PlayUI._apply_card_effect(),
## trimmed to the keywords Response's own card pool actually uses. "Containment" still
## means "damage the boss" -- see the `containment` property above.
func _apply_card_effect(cdata: Dictionary) -> void:
	var logic: String = String(cdata.get("logic", ""))
	for line in logic.split("\n"):
		line = line.strip_edges()
		var n := _extract_int(line)
		if "Containment" in line:
			containment = min(_boss.max_hp, containment + n)
		if "Integrity" in line:
			GameState.system_integrity = min(GameState.max_system_integrity, GameState.system_integrity + n)
		if "Draw" in line and "card" in line:
			deck_manager.draw_cards(max(1, n))
		if "Energy" in line and "Gain" in line:
			max_energy = min(10, max_energy + 1)
			energy += 1


func _extract_int(text: String) -> int:
	var s := ""
	for ch in text:
		if ch >= "0" and ch <= "9":
			s += ch
		elif s != "":
			break
	return s.to_int() if s != "" else 0


func _on_end_turn_pressed() -> void:
	if _animating or _ended:
		return
	_animating = true
	_end_turn_button.disabled = true

	deck_manager.discard_hand()
	_apply_boss_intent()
	_end_turn_count += 1
	_advance_tutorial(1)
	if _end_turn_count >= 2:
		_advance_tutorial(2)

	_update_hud()
	if not _check_win_loss():
		_show_intent()
		_start_turn()

	_animating = false
	_end_turn_button.disabled = _ended


func _apply_boss_intent() -> void:
	var result: Dictionary = _boss.execute_intent()
	var damage: int = int(result.get("damage", 0))
	var component: String = String(result.get("component", ""))
	GameState.take_system_damage(damage, component)


func _check_win_loss() -> bool:
	if _boss.is_defeated():
		_finish_response(true)
		return true
	if GameState.system_integrity <= 0:
		_finish_response(false)
		return true
	return false


func _finish_response(won: bool) -> void:
	_ended = true
	GameState.threat_defeated = won
	GameState.response_result = "threat_neutralized" if won else "system_compromised"

	if _tutorial_active:
		_tutorial_active = false
		GameState.complete_tutorial("response")
		_update_hint_banner()

	_end_turn_button.disabled = true
	_result_panel.visible = true

	_result_label.text = "THREAT NEUTRALIZED" if won else "SYSTEM COMPROMISED"

	var damaged_names: Array = []
	for entry in GameState.damaged_components:
		damaged_names.append(String(entry.get("name", "")))

	_summary_label.text = "System Integrity: %d / %d\n\nDamaged:\n%s\n\nSafe:\n%s" % [
		GameState.system_integrity,
		GameState.max_system_integrity,
		_format_component_list(damaged_names),
		_format_component_list(GameState.get_safe_components()),
	]


func _format_component_list(names: Array) -> String:
	if names.is_empty():
		return "(none)"
	var lines: Array = []
	for component_name in names:
		lines.append("- %s" % component_name)
	return "\n".join(lines)


func _on_continue_pressed() -> void:
	if _tutorial_active:
		_tutorial_active = false
		GameState.complete_tutorial("response")
	ScenarioFlow.on_phase_complete()


func _update_hud() -> void:
	_integrity_label.text = "System Integrity: %d / %d" % [GameState.system_integrity, GameState.max_system_integrity]
	_boss_hp_label.text = "%s HP: %d / %d" % [_boss.display_name, _boss.hp, _boss.max_hp]
	_energy_label.text = "Energy: %d / %d" % [energy, max_energy]
	_deck_count_label.text = "Deck: %d" % deck_manager.deck_count()
	_discard_count_label.text = "Discard: %d" % deck_manager.discard_count()


func _advance_tutorial(step_just_done: int) -> void:
	if not _tutorial_active or step_just_done != _tutorial_step:
		return
	_tutorial_step += 1
	if _tutorial_step >= _TUTORIAL_HINTS.size():
		_tutorial_active = false
		GameState.complete_tutorial("response")
	_update_hint_banner()


func _update_hint_banner() -> void:
	_hint_banner.visible = _tutorial_active
	if _tutorial_active:
		_hint_label.text = _TUTORIAL_HINTS[_tutorial_step]
