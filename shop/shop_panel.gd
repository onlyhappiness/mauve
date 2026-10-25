class_name ShopPanel
extends Panel

# 상점 패널(680×510). 진주로 물고기를 사고판다. 화면 전체 장면(Screen)에 연결하는 일은 D18이다.
# 진주·물고기는 Game 함수로 바꾸고, Game 시그널을 받아 다시 그린다. 상품 목록은 Catalog.FISH 순서를 따른다.
# 배치·색은 OpenDesign 상점 시안(DESIGN.md)을 따르고, 안쪽 노드는 _build()에서 코드로 만든다.
# 수초 탭은 D18 범위라 아직 고를 수 없다.

signal closed

const CLOSE_ICON := preload("res://assets/ui/close.svg")
const RADIUS := 28  # 패널 바깥 모서리
const PADDING := 24  # 바깥 테두리 4 + 안쪽 여백 20
const DEV_PEARLS := 100  # 디버그 실행에서 상점을 연 채 P 키를 누르면 받는 진주(D07 확인용)

var kinds: Array = Catalog.FISH.keys()  # 상품 칸 순서대로 종류 id
var selected := 0  # kinds 위치
var note := ""  # 방금 사고판 결과 문구. 다른 상품을 고르면 지운다.

var _cards: Array[Button] = []
var _badges: Array[Label] = []
var _wallet: Control
var _amount: Label
var _delta: Label
var _delta_tween: Tween
var _fish_count: Label
var _detail_thumb: Control
var _detail_thumb_index := -1  # _detail_thumb가 그리고 있는 kinds 위치
var _detail_name: Label
var _description: Label
var _buy_price: Label
var _sell_price: Label
var _owned: Label
var _reason: Label
var _buy_button: Button
var _sell_button: Button


func _ready() -> void:
	theme_type_variation = &"ShopPanelBox"
	_build()
	Game.pearls_changed.connect(_refresh.unbind(1))
	Game.fish_added.connect(_refresh.unbind(1))
	Game.fish_removed.connect(_refresh.unbind(1))
	_refresh()


func open() -> void:
	note = ""
	_refresh()
	show()


# 어항 유리와 같은 이중선: 바깥 테두리(테마) 안쪽에 밝은 선 4, 중간 선 3을 더 그린다.
func _draw() -> void:
	for ring: Array in [[4, WidgetTheme.GLASS_HI, 4], [8, WidgetTheme.GLASS_MID, 3]]:
		var inset: int = ring[0]
		var box := StyleBoxFlat.new()
		box.draw_center = false
		box.border_color = ring[1]
		box.set_border_width_all(ring[2])
		box.set_corner_radius_all(RADIUS - inset)
		draw_style_box(box, Rect2(Vector2.ZERO, size).grow(-inset))


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if visible and OS.is_debug_build() and key and key.pressed and not key.echo and key.keycode == KEY_P:
		Game.add_pearls(DEV_PEARLS)
		_flash(DEV_PEARLS)


func _buy() -> void:
	var kind: String = kinds[selected]
	var item: Dictionary = Catalog.FISH[kind]
	if _buy_block(kind) != "" or not Game.add_fish(kind):
		return
	Game.spend_pearls(item["price"])
	note = "%s 샀어요" % _with_object_particle(item["name"])
	_flash(-item["price"])
	_refresh()


func _sell() -> void:
	var kind: String = kinds[selected]
	var item: Dictionary = Catalog.FISH[kind]
	if _sell_block(kind) != "" or not Game.remove_fish(kind):
		return
	Game.add_pearls(_sell_price_of(item))
	note = "%s 팔았어요" % _with_object_particle(item["name"])
	_flash(_sell_price_of(item))
	_refresh()


func _select(index: int) -> void:
	selected = index
	note = ""
	_refresh()


func _buy_block(kind: String) -> String:
	var item: Dictionary = Catalog.FISH[kind]
	if not Catalog.is_fish_ready(kind):
		return "아직 준비 중이에요"
	if Game.fish_count() >= Game.MAX_FISH:
		return "물고기가 가득 찼어요 (%d/%d)" % [Game.MAX_FISH, Game.MAX_FISH]
	if Game.pearls < item["price"]:
		return "진주가 %d개 부족해요" % (item["price"] - Game.pearls)
	return ""


# 어항이 비지 않도록 마지막 한 마리는 팔 수 없다.
func _sell_block(kind: String) -> String:
	if Game.count_fish(kind) == 0:
		return "가지고 있지 않아요"
	if Game.fish_count() <= 1:
		return "마지막 한 마리는 팔 수 없어요"
	return ""


func _sell_price_of(item: Dictionary) -> int:
	return item["price"] / 2


# 받침이 있으면 「을」, 없으면 「를」을 붙인다.
func _with_object_particle(word: String) -> String:
	var code := word.unicode_at(word.length() - 1)
	var has_final := code >= 0xAC00 and code <= 0xD7A3 and (code - 0xAC00) % 28 != 0
	return word + ("을" if has_final else "를")


func _refresh() -> void:
	_amount.text = str(Game.pearls)
	var full := Game.fish_count() >= Game.MAX_FISH
	_fish_count.text = "%d/%d" % [Game.fish_count(), Game.MAX_FISH]
	_fish_count.add_theme_color_override("font_color", WidgetTheme.WARN if full else WidgetTheme.MUTED)

	for i in kinds.size():
		_cards[i].theme_type_variation = &"ShopCardSelected" if i == selected else &"ShopCard"
		var owned := Game.count_fish(kinds[i])
		_badges[i].text = "×%d" % owned
		_badges[i].get_parent().visible = owned > 0

	var kind: String = kinds[selected]
	var item: Dictionary = Catalog.FISH[kind]
	if _detail_thumb_index != selected:
		# replace_by()는 이전 그림의 자식까지 옮겨 오므로 직접 바꿔 끼운다.
		var thumb := _thumb(item, 84, 68)
		_detail_thumb.add_sibling(thumb)
		_detail_thumb.queue_free()
		_detail_thumb = thumb
		_detail_thumb_index = selected
	_detail_name.text = item["name"]
	_description.text = _keep_words(item["description"])
	_buy_price.text = str(item["price"])
	_sell_price.text = str(_sell_price_of(item))
	_owned.text = "%d마리" % Game.count_fish(kind)

	var buy_block := _buy_block(kind)
	var sell_block := _sell_block(kind)
	_buy_button.disabled = buy_block != ""
	_sell_button.disabled = sell_block != ""
	_buy_button.tooltip_text = buy_block
	_sell_button.tooltip_text = sell_block
	# 구매를 막는 이유 → 방금 사고판 결과 → 판매를 막는 이유 순서로 한 줄만 보여 준다.
	var showing_note := buy_block == "" and note != ""
	if buy_block != "":
		_reason.text = _keep_words(buy_block)
	elif note != "":
		_reason.text = _keep_words(note)
	else:
		_reason.text = _keep_words(sell_block) if Game.count_fish(kind) > 0 else ""
	_reason.add_theme_color_override("font_color", WidgetTheme.OK if showing_note else WidgetTheme.WARN)


# 한글은 글자마다 줄을 바꿀 수 있어서, 단어 안 글자 사이에 단어 결합자(U+2060)를 넣어 띄어쓰기에서만 줄을 바꾼다.
func _keep_words(text: String) -> String:
	var joined := ""
	for i in text.length():
		if i > 0 and text[i] != " " and text[i - 1] != " ":
			joined += "\u2060"
		joined += text[i]
	return joined


# 진주 칩 왼쪽에 바뀐 양을 잠깐 띄운다. 쓰면 연보라, 받으면 초록.
# 시안은 칩 위에 띄우지만 그 자리는 패널 테두리와 겹쳐 칩 왼쪽 빈자리에 둔다.
func _flash(amount: int) -> void:
	_delta.text = ("+%d" if amount > 0 else "−%d") % absi(amount)
	_delta.add_theme_color_override("font_color", WidgetTheme.OK if amount > 0 else WidgetTheme.ACCENT)
	_delta.reset_size()
	var chip := _wallet.get_global_rect()
	var top := chip.get_center().y - global_position.y - _delta.size.y / 2.0
	_delta.position = Vector2(chip.position.x - global_position.x - 10.0 - _delta.size.x, top + 8.0)
	_delta.modulate.a = 0.0
	if _delta_tween:
		_delta_tween.kill()
	_delta_tween = create_tween()
	_delta_tween.tween_property(_delta, "modulate:a", 1.0, 0.15)
	_delta_tween.parallel().tween_property(_delta, "position:y", top, 0.15)
	_delta_tween.tween_interval(0.65)
	_delta_tween.tween_property(_delta, "modulate:a", 0.0, 0.3)
	_delta_tween.parallel().tween_property(_delta, "position:y", top - 6.0, 0.3)


# ── 화면 구성 ──────────────────────────────────────────────

func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, PADDING)
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	root.add_child(_build_header())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root.add_child(body)
	body.add_child(_build_list())
	body.add_child(_build_detail())

	_delta = _label("", &"DeltaLabel")
	_delta.modulate.a = 0.0
	add_child(_delta)


# 제목 · 진주 칩 · 닫기
func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 52
	header.add_theme_constant_override("separation", 8)
	header.add_child(Control.new())  # 제목 왼쪽 들여쓰기 8
	header.add_child(_label("상점", &"PanelTitle"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var wallet := PanelContainer.new()
	wallet.theme_type_variation = &"WalletChip"
	wallet.custom_minimum_size.y = 48
	_wallet = wallet
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	wallet.add_child(row)
	row.add_child(_pearl(24))
	row.add_child(_label("진주", &"MutedLabel"))
	_amount = _label("0", &"WalletAmount")
	_amount.custom_minimum_size.x = 64
	_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_amount)
	header.add_child(wallet)

	var close := Button.new()
	close.theme_type_variation = &"PanelIconButton"
	close.custom_minimum_size = Vector2(48, 48)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.focus_mode = Control.FOCUS_NONE
	close.icon = CLOSE_ICON
	close.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close.tooltip_text = "닫기"
	close.pressed.connect(func() -> void:
		hide()
		closed.emit())
	header.add_child(close)
	return header


# 탭 + 상품 목록(3열)
func _build_list() -> Control:
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 330
	left.add_theme_constant_override("separation", 12)

	var tabs := PanelContainer.new()
	tabs.theme_type_variation = &"ShopTabs"
	tabs.custom_minimum_size.y = 52
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	tabs.add_child(tab_row)
	var fish_tab := PanelContainer.new()
	fish_tab.theme_type_variation = &"SelectedTab"
	fish_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fish_tab.size_flags_stretch_ratio = 1.45
	var fish_tab_row := HBoxContainer.new()
	fish_tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	fish_tab_row.add_theme_constant_override("separation", 8)
	fish_tab.add_child(fish_tab_row)
	fish_tab_row.add_child(_label("물고기", &"TabLabel"))
	_fish_count = _label("", &"TabCount")
	fish_tab_row.add_child(_fish_count)
	tab_row.add_child(fish_tab)
	for title in ["수초", "어항"]:
		var tab := Button.new()
		tab.theme_type_variation = &"TabButton"
		tab.text = title
		tab.disabled = true
		tab.focus_mode = Control.FOCUS_NONE
		tab.tooltip_text = "%s 준비 중이에요" % ("수초는" if title == "수초" else "어항은")
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_row.add_child(tab)
	left.add_child(tabs)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	for i in kinds.size():
		grid.add_child(_build_card(i))
	left.add_child(scroll)
	return left


# 상품 칸: 그림 · 이름 · 가격, 보유하면 오른쪽 위에 ×수량
func _build_card(index: int) -> Button:
	var item: Dictionary = Catalog.FISH[kinds[index]]
	var card := Button.new()
	card.theme_type_variation = &"ShopCard"
	card.custom_minimum_size.y = 146
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_NONE
	card.pressed.connect(_select.bind(index))

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 6
	column.offset_top = 6
	column.offset_right = -6
	column.offset_bottom = -8
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)
	column.add_child(_thumb(item, 70, 54))
	var name_label := _label(item["name"], &"CardName")
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(name_label)
	var price := HBoxContainer.new()
	price.add_theme_constant_override("separation", 6)
	price.add_child(_pearl(16))
	price.add_child(_label(str(item["price"]), &"CardPrice"))
	column.add_child(price)

	var badge := PanelContainer.new()
	badge.theme_type_variation = &"OwnedBadge"
	badge.custom_minimum_size.y = 26
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var badge_label := _label("", &"BadgeLabel")
	badge.add_child(badge_label)
	card.add_child(badge)

	_ignore_mouse(column)
	_ignore_mouse(badge)
	_cards.append(card)
	_badges.append(badge_label)
	return card


# 그림 · 이름 · 설명 · 구매가/판매가/보유 · 안내 문구 · 구매/판매
func _build_detail() -> Control:
	var detail := PanelContainer.new()
	detail.theme_type_variation = &"DetailBox"
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	detail.add_child(column)

	_detail_thumb = Control.new()  # _refresh()에서 고른 상품의 그림으로 바꾼다
	column.add_child(_detail_thumb)
	_detail_name = _label("", &"DetailName")
	column.add_child(_detail_name)
	_description = _label("", &"Description")
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_description)

	var stats_box := PanelContainer.new()
	stats_box.theme_type_variation = &"StatsLine"
	var stats := HBoxContainer.new()
	stats_box.add_child(stats)
	_buy_price = _stat(stats, "구매가")
	_sell_price = _stat(stats, "판매가")
	_owned = _stat(stats, "보유")
	column.add_child(stats_box)

	_reason = _label("", &"Reason")
	_reason.custom_minimum_size.y = 28
	_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	column.add_child(_reason)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	_buy_button = _action_button("구매", &"BuyButton", 1.35, _buy)
	_sell_button = _action_button("판매", &"SellButton", 1.0, _sell)
	actions.add_child(_buy_button)
	actions.add_child(_sell_button)
	column.add_child(actions)
	return detail


func _stat(parent: HBoxContainer, title: String) -> Label:
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation", 2)
	cell.add_child(_label(title, &"StatName"))
	var value := _label("", &"StatValue")
	cell.add_child(value)
	parent.add_child(cell)
	return value


func _action_button(text: String, type: StringName, ratio: float, action: Callable) -> Button:
	var button := Button.new()
	button.theme_type_variation = type
	button.text = text
	button.custom_minimum_size.y = 50
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_stretch_ratio = ratio
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	return button


# 물빛 칸 가운데에 상품 그림. 그림이 없으면 「준비 중」 칸.
func _thumb(item: Dictionary, height: int, image_height: int) -> Control:
	var thumb := PanelContainer.new()
	thumb.custom_minimum_size.y = height
	if item["texture"] == null:
		thumb.theme_type_variation = &"ThumbEmpty"
		var label := _label("준비 중", &"ThumbLabel")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		thumb.add_child(label)
	else:
		thumb.theme_type_variation = &"Thumb"
		var image := TextureRect.new()
		image.texture = item["texture"]
		# 어항 속 금붕어(fish.tscn)와 같은 필터로 그려 외형을 맞춘다.
		image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size.y = image_height
		image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		thumb.add_child(image)
	_ignore_mouse(thumb)
	return thumb


func _label(text: String, type: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = type
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _pearl(diameter: int) -> Control:
	var pearl := Pearl.new()
	pearl.custom_minimum_size = Vector2(diameter, diameter)
	pearl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return pearl


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


# 진주 아이콘: 단색 원과 오른쪽 아래 그늘 한 겹. 광택·반짝이는 쓰지 않는다.
class Pearl extends Control:
	func _draw() -> void:
		var radius := size.x / 2.0
		var center := size / 2.0
		var offset := radius * 0.2
		draw_circle(center, radius, WidgetTheme.PEARL_EDGE, true, -1.0, true)
		draw_circle(center, radius - 2.0, WidgetTheme.PEARL_SHADE, true, -1.0, true)
		draw_circle(center - Vector2(offset, offset), radius - 2.0 - offset, WidgetTheme.PEARL, true, -1.0, true)
