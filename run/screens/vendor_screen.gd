class_name VendorScreen
extends RunScreen
## The vendor stop: the stall scene, card and relic offers, and the Remove / Heal / Leave services.
## Keeps the vendor's own view state (last result message, remove picker) across redraws.

## The vendor's relic slot: badge size (the plate is the size of an offer card).
const RELIC_OFFER_SCALE := 0.8
## Height reserved above the speech banner for the shopkeeper's hood (see VendorScene).
const VENDOR_HEAD_HEIGHT := 104.0
## Width of the Remove / Heal column on the left and the Leave column on the right.
const SERVICE_COLUMN_WIDTH := 190.0
const SERVICE_BUTTON_HEIGHT := 34.0
const SERVICE_FONT_SIZE := 14
## Offer cards are drawn smaller than reward cards so the art stays visible.
const VENDOR_CARD_SCALE := 0.85

## The stop title and journey number for the top-left info (set by run.gd before show).
var stop_title := ""
var journey_text := ""
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
	# The stall fills the whole screen; everything else is laid over it without a backing box.
	var stall := VendorScene.new()
	add_backdrop(stall)
	stall.set_gold(run.gold)
	stall.dimmed = removing
	_add_hud_info()
	var greeting := "What will you carry with you?" if run.gold >= Vendor.PRICE_CHEAP else "\"Empty pockets? Look, then. Looking is free.\""
	if removing:
		var picker := panel(greeting, true)
		style_banner(picker.get_child(0) as Label)
		if message != "":
			var note := make_label(message)
			style_banner(note)
			picker.add_child(note)
		add_remove_picker(picker, _remove_card, cancel_removing)
		return
	# Top centre: room for the shopkeeper's hood.
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 12)
	var head := Control.new()
	head.custom_minimum_size = Vector2(0, VENDOR_HEAD_HEIGHT)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(head)
	stall.head_anchor = head
	# Bottom HUD: the speech banner (and last result) centred above a row with the gold and the
	# Remove / Heal buttons on the left, the offers in the middle and Leave on the right.
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	body.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	stack.size_flags_vertical = Control.SIZE_SHRINK_END
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(stack)
	var banner := make_label(greeting)
	style_banner(banner)
	banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(banner)
	if message != "":
		var result := make_label(message)
		style_banner(result)
		result.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(result)
	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(bottom)
	var left := _service_column()
	bottom.add_child(left)
	bottom.add_child(_expander())
	var row := _offer_row(vendor)
	bottom.add_child(row)
	stall.counter_anchor = row
	bottom.add_child(_expander())
	var right := _service_column()
	bottom.add_child(right)
	# Disabled up front when the purchase would be refused, so the player is not
	# sent into a picker or a click that can only fail.
	left.add_child(GoldBadge.new(run.gold))
	var remove := add_button(left, "Remove a card (%d gold)" % Vendor.REMOVE_CARD_PRICE, start_removing)
	remove.disabled = vendor.has_removed() or run.gold < Vendor.REMOVE_CARD_PRICE or run.deck.size() <= 1
	var heal := add_button(left, "Heal %d HP (%d gold)" % [Vendor.HEAL_AMOUNT, Vendor.HEAL_PRICE], buy_heal)
	heal.disabled = vendor.has_healed() or run.gold < Vendor.HEAL_PRICE or run.player.hp >= run.player.max_hp
	var leave := add_button(right, "Leave", leave_vendor)
	for button in [remove, heal, leave]:
		style_service(button)
		compact_plaque(button, SERVICE_BUTTON_HEIGHT, SERVICE_FONT_SIZE)
		stall.service_anchors.append(button)


## Top-left info like the fight HUD: stop title, journey number, then HP, gold, deck and relics.
func _add_hud_info() -> void:
	var info := VBoxContainer.new()
	info.position = Vector2(14, 10)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 0)
	body.add_child(info)
	var lines := [
		[stop_title, 20, MenuStyle.TEXT, 2],
		[journey_text, 20, MenuStyle.TEXT_DIM, 2],
	]
	for line in lines:
		var label := Label.new()
		label.text = line[0]
		label.add_theme_font_size_override("font_size", line[1])
		label.add_theme_color_override("font_color", line[2])
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		label.add_theme_constant_override("shadow_offset_y", line[3])
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(label)
	info.add_child(RelicStrip.create(run.relics))


## A column of service buttons; both columns share one width so the offers stay centred.
func _service_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.custom_minimum_size = Vector2(SERVICE_COLUMN_WIDTH, 0)
	column.size_flags_vertical = Control.SIZE_SHRINK_END
	return column


func _expander() -> Control:
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


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
		var view := card_view(card, VENDOR_CARD_SCALE, buy_card.bind(i))
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
	# Like a card offer: a card-sized plate you click to buy, the price below it. A sold or
	# unaffordable relic is dimmed with the reason on it and cannot be clicked.
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 2)
	var plate := Button.new()
	plate.name = "RelicOffer"
	plate.clip_contents = true
	plate.custom_minimum_size = CardView.BASE * VENDOR_CARD_SCALE
	plate.tooltip_text = "%s (%d gold)\n%s" % [relic.display_name, price, relic.description]
	plate.disabled = sold or not affordable
	plate.pressed.connect(buy_relic)
	plate.pressed.connect(sfx.bind(&"click"))
	var states := {"normal": Color(0.09, 0.11, 0.15, 0.92), "hover": Color(0.14, 0.17, 0.22, 0.95), "pressed": Color(0.06, 0.08, 0.11, 0.95), "disabled": Color(0.07, 0.08, 0.1, 0.8)}
	for state in states:
		var style := StyleBoxFlat.new()
		style.bg_color = states[state]
		style.set_border_width_all(1)
		style.border_color = Color("#9b9e90") if state != "disabled" else MenuStyle.BORDER
		style.set_corner_radius_all(3)
		plate.add_theme_stylebox_override(state, style)
	outer.add_child(plate)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	plate.add_child(column)
	var view := RelicView.new()
	view.view_scale = RELIC_OFFER_SCALE
	view.set_relic(relic)
	view.dimmed = sold or not affordable
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(view)
	var name_label := make_label(relic.display_name)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color("#D7D0BC"))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)
	var text := make_label(relic.description)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 12)
	text.add_theme_color_override("font_color", Color("#bcc5bd"))
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(text)
	if sold or not affordable:
		var reason := make_label("SOLD" if sold else "NEED %d GOLD" % price)
		reason.add_theme_font_size_override("font_size", 13)
		reason.add_theme_color_override("font_color", MenuStyle.AMBER)
		reason.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(reason)
	outer.add_child(make_label("Sold" if sold else "%d gold" % price))
	return outer


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
	message = "" if result.ok else "Can't: %s." % result.reason
	refresh.call()
