extends Control
## Hardening phase: a shop-style preparation screen. The player spends the Security
## Points earned in Monitoring on defenses that modify the Response loadout. All
## scenario-specific content -- the base deck, the shop items, their costs, and what
## each one unlocks -- comes from
## ScenarioDatabase.get_scenario_by_id(GameState.scenario_id).hardening. Nothing about
## a specific threat is hardcoded here.
##
## The shop IS the interface: there is no separate inventory system. The actual
## gameplay is the player's decision about how to spend a limited resource, and every
## purchase directly and permanently modifies GameState.response_deck or
## GameState.passive_upgrades -- purchases are never purely cosmetic.

const _TUTORIAL_HINTS := [
	"Select a defense below to see what it does and how much it costs.",
	"Purchase it if you can afford it -- your Security Points are limited, so you can't buy everything.",
	"Check your Response Deck to see how the purchase changed it.",
]

@onready var _hint_banner: Control = %HintBanner
@onready var _hint_label: Label = %HintLabel

@onready var _security_points_label: Label = %SecurityPointsLabel
@onready var _shop_list: VBoxContainer = %ShopList

@onready var _detail_name_label: Label = %DetailNameLabel
@onready var _detail_description_label: Label = %DetailDescriptionLabel
@onready var _detail_cost_label: Label = %DetailCostLabel
@onready var _detail_feedback_label: Label = %DetailFeedbackLabel
@onready var _buy_button: Button = %BuyButton

@onready var _response_deck_panel: Control = %ResponseDeckPanel
@onready var _deck_list: VBoxContainer = %DeckList
@onready var _passives_list: VBoxContainer = %PassivesList

@onready var _view_deck_button: Button = %ViewDeckButton
@onready var _confirm_button: Button = %ConfirmButton

var _hardening_data: Dictionary = {}
var _shop_items: Array = []
var _owned_ids: Array = []
var _current_item: Dictionary = {}

var _tutorial_active: bool = false
var _tutorial_step: int = 0


func _ready() -> void:
	var scenario: Dictionary = ScenarioDatabase.get_scenario_by_id(GameState.scenario_id)
	_hardening_data = scenario.get("hardening", {})
	_shop_items = _hardening_data.get("shop_items", [])

	GameState.response_deck = _hardening_data.get("base_deck", []).duplicate()

	_buy_button.pressed.connect(_on_buy_pressed)
	_view_deck_button.pressed.connect(_on_view_deck_pressed)
	%CloseDeckButton.pressed.connect(_on_close_deck_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)

	_tutorial_active = not GameState.hardening_tutorial_completed
	_update_hint_banner()

	_response_deck_panel.visible = false
	_populate_shop_list()
	_update_points_label()
	_show_empty_detail()


func _populate_shop_list() -> void:
	for child in _shop_list.get_children():
		child.free()

	for item in _shop_items:
		var button := Button.new()
		var owned: bool = _owned_ids.has(String(item.get("id", "")))
		var prefix: String = "(Owned) " if owned else ""
		button.text = "%s%s -- %d Security Points" % [prefix, item.get("name", ""), int(item.get("cost", 0))]
		button.pressed.connect(_on_item_selected.bind(item))
		_shop_list.add_child(button)


func _show_empty_detail() -> void:
	_detail_name_label.text = "Select a defense to inspect it."
	_detail_description_label.text = ""
	_detail_cost_label.text = ""
	_detail_feedback_label.text = ""
	_buy_button.disabled = true


func _on_item_selected(item: Dictionary) -> void:
	_current_item = item
	_detail_name_label.text = String(item.get("name", ""))
	_detail_description_label.text = String(item.get("description", ""))
	var cost: int = int(item.get("cost", 0))
	_detail_cost_label.text = "Cost: %d Security Points" % cost
	_detail_feedback_label.text = ""

	var owned: bool = _owned_ids.has(String(item.get("id", "")))
	var affordable: bool = cost <= GameState.security_points
	_buy_button.disabled = owned or not affordable
	if owned:
		_detail_feedback_label.text = "Already purchased."
	elif not affordable:
		_detail_feedback_label.text = "Not enough Security Points."

	_advance_tutorial(0)


func _on_buy_pressed() -> void:
	var item_id: String = String(_current_item.get("id", ""))
	if item_id == "" or _owned_ids.has(item_id):
		return

	var cost: int = int(_current_item.get("cost", 0))
	if cost > GameState.security_points:
		_detail_feedback_label.text = "Not enough Security Points."
		return

	GameState.security_points -= cost
	_owned_ids.append(item_id)
	GameState.purchased_defenses.append(item_id)

	if String(_current_item.get("category", "")) == "passive":
		var passive_name: String = String(_current_item.get("passive_effect", _current_item.get("name", "")))
		GameState.passive_upgrades.append(passive_name)
		_detail_feedback_label.text = "Purchased. %s is now active." % passive_name
	else:
		var unlocked_card: String = String(_current_item.get("unlocks_card", ""))
		if unlocked_card != "" and not GameState.response_deck.has(unlocked_card):
			GameState.response_deck.append(unlocked_card)
		_detail_feedback_label.text = "Purchased. %s added to your Response deck." % unlocked_card

	_buy_button.disabled = true
	_update_points_label()
	_populate_shop_list()
	_advance_tutorial(1)


func _update_points_label() -> void:
	_security_points_label.text = "Security Points: %d" % GameState.security_points


func _on_view_deck_pressed() -> void:
	for child in _deck_list.get_children():
		child.free()
	for card_name in GameState.response_deck:
		var label := Label.new()
		label.text = "- %s" % card_name
		_deck_list.add_child(label)

	for child in _passives_list.get_children():
		child.free()
	if GameState.passive_upgrades.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No passive upgrades purchased."
		_passives_list.add_child(empty_label)
	else:
		for upgrade_name in GameState.passive_upgrades:
			var label := Label.new()
			label.text = "- %s" % upgrade_name
			_passives_list.add_child(label)

	_response_deck_panel.visible = true
	_advance_tutorial(2)


func _on_close_deck_pressed() -> void:
	_response_deck_panel.visible = false


func _on_confirm_pressed() -> void:
	if _tutorial_active:
		_tutorial_active = false
		GameState.complete_tutorial("hardening")
		_update_hint_banner()
	ScenarioFlow.on_phase_complete()


func _advance_tutorial(step_just_done: int) -> void:
	if not _tutorial_active or step_just_done != _tutorial_step:
		return
	_tutorial_step += 1
	if _tutorial_step >= _TUTORIAL_HINTS.size():
		_tutorial_active = false
		GameState.complete_tutorial("hardening")
	_update_hint_banner()


func _update_hint_banner() -> void:
	_hint_banner.visible = _tutorial_active
	if _tutorial_active:
		_hint_label.text = _TUTORIAL_HINTS[_tutorial_step]
