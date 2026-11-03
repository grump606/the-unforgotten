class_name VendorScreen
extends RunScreen
## The vendor stop: the stall scene, card and relic offers, and the Remove / Heal / Leave services.
## Keeps the vendor's own view state (last result message, remove picker) across redraws.

## The vendor's relic slot: badge size and the width of the plate around it.
const RELIC_OFFER_SCALE := 1.5
const RELIC_SLOT_WIDTH := 150.0
## Height reserved above the speech banner for the shopkeeper's hood (see VendorScene).
const VENDOR_HEAD_HEIGHT := 104.0

## Result text of the last vendor action, shown on the vendor panel.
var message := ""
## True while the panel shows the pick-a-card-to-remove list.
var removing := false


## Forgets the last message and the picker (a new or resumed run starts clean).
func reset() -> void:
	message = ""
	removing = false


func show() -> void:
	var vendor := run.vendor()
	# The stall is drawn behind the panel (the panel is added after it, so it sits on top).
	var stall := VendorScene.new()
	add_backdrop(stall)
	stall.set_gold(run.gold)
	stall.dimmed = removing
	var box := panel("What will you carry with you?" if run.gold >= Vendor.PRICE_CHEAP else "\"Empty pockets? Look, then. Looking is free.\"", true)
	style_banner(box.get_child(0) as Label)
	if not removing:
		var head := Control.new() # room for the shopkeeper's hood above the speech banner
		head.custom_minimum_size = Vector2(0, VENDOR_HEAD_HEIGHT)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(head)
		box.move_child(head, 0)
		stall.head_anchor = head
	if message != "":
		var result := make_label(message)
		style_banner(result)
		box.add_child(result)
	if removing:
		add_remove_picker(box, _remove_card, cancel_removing)
		return
	var row := _offer_row(vendor)
	box.add_child(row)
	stall.counter_anchor = row
	# The services sit on the counter front in a row, each with a prop drawn to its left by the stall
	# (the spacers keep the row centred).
	var services := HBoxContainer.new()
	services.alignment = BoxContainer.ALIGNMENT_CENTER
	services.add_theme_constant_override("separation", 52)
	box.add_child(services)
	services.add_child(_service_gap())
	# Disabled up front when the purchase would be refused, so the player is not
	# sent into a picker or a click that can only fail.
	var remove := add_button(services, "Remove a card (%d gold)" % Vendor.REMOVE_CARD_PRICE, start_removing)
	remove.disabled = vendor.has_removed() or run.gold < Vendor.REMOVE_CARD_PRICE or run.deck.size() <= 1
	var heal := add_button(services, "Heal %d HP (%d gold)" % [Vendor.HEAL_AMOUNT, Vendor.HEAL_PRICE], buy_heal)
	heal.disabled = vendor.has_healed() or run.gold < Vendor.HEAL_PRICE or run.player.hp >= run.player.max_hp
	var leave := add_button(services, "Leave", leave_vendor)
	services.add_child(_service_gap())
	for button in [remove, heal, leave]:
		style_service(button)
		stall.service_anchors.append(button)


## The card offers and, when there is one, the relic slot.
func _offer_row(vendor: Vendor) -> HBoxContainer:
	var offers := vendor.offers()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	for i in offers.size():
		var card: CardData = offers[i]["card"]
		var sold: bool = offers[i]["sold"]
		var price: int = offers[i]["price"]
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 2)
		var view := card_view(card, OFFER_CARD_SCALE, buy_card.bind(i))
		# A sold or unaffordable offer is dimmed with the reason on the card, and cannot be clicked.
		if sold:
			view.set_state(CardView.State.UNPLAYABLE, "SOLD")
		elif run.gold < price:
			view.set_state(CardView.State.UNPLAYABLE, "NEED %d GOLD" % price)
		column.add_child(view)
		column.add_child(make_label("Sold" if sold else "%d gold" % price))
		row.add_child(column)
	var relic_offer := vendor.relic_offer()
	if not relic_offer.is_empty():
		row.add_child(_relic_slot(relic_offer))
	return row


## The vendor's relic for sale, beside the cards: badge, name, effect, price and a Buy button. Like a
## card offer it shows "Sold" afterwards and cannot be bought without the gold.
func _relic_slot(offer: Dictionary) -> Control:
	var relic: RelicData = offer["relic"]
	var sold: bool = offer["sold"]
	var price: int = offer["price"]
	var affordable := run.gold >= price
	var plate := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.15, 0.92)
	style.set_border_width_all(1)
	style.border_color = Color("#9b9e90")
	style.set_corner_radius_all(3)
	style.set_content_margin_all(10)
	plate.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	column.custom_minimum_size = Vector2(RELIC_SLOT_WIDTH, 0)
	plate.add_child(column)
	var view := RelicView.new()
	view.view_scale = RELIC_OFFER_SCALE
	view.set_relic(relic)
	view.dimmed = sold or not affordable
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(view)
	var name_label := make_label(relic.display_name)
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Color("#D7D0BC"))
	column.add_child(name_label)
	var text := make_label(relic.description)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_color_override("font_color", Color("#bcc5bd"))
	column.add_child(text)
	var price_label := make_label("Sold" if sold else "%d gold" % price)
	price_label.add_theme_color_override("font_color", Color("#D7D0BC"))
	column.add_child(price_label)
	var buy := add_button(column, "Buy relic", buy_relic)
	buy.disabled = sold or not affordable
	style_service(buy)
	return plate


func _service_gap() -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(36, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


func buy_card(offer_index: int) -> void:
	_finish(run.vendor_buy_card(offer_index), "Bought")


func buy_relic() -> void:
	var result := run.vendor_buy_relic()
	_finish(result, "Bought %s" % result.relic.display_name if result.ok else "")


func buy_heal() -> void:
	_finish(run.vendor_buy_heal(), "Healed")


func start_removing() -> void:
	removing = true
	message = "Pick a card to remove."
	refresh.call()


func cancel_removing() -> void:
	removing = false
	message = ""
	refresh.call()


func leave_vendor() -> void:
	message = ""
	removing = false
	run.leave_vendor()
	refresh.call()


func _remove_card(deck_index: int) -> void:
	removing = false
	_finish(run.vendor_remove_card(deck_index), "Removed")


func _finish(result: Vendor.Result, done_text: String) -> void:
	message = done_text if result.ok else "Can't: %s." % result.reason
	refresh.call()
