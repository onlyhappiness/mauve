class_name WidgetTheme
extends RefCounted

# 기본 화면·상점 패널 컨트롤의 색·테두리·글꼴. 수치는 OpenDesign 기본 화면·상점 시안(DESIGN.md)을 따른다(Godot 픽셀 기준).

const SURFACE := Color("f9feff")  # 컨트롤 바탕
const FG := Color("223543")  # 글자·아이콘, 항상 위 켬 바탕, 말풍선 바탕
const FG_HOVER := Color("3a4d5c")
const HOVER := Color("d6edf2")  # 흰 컨트롤 마우스 올림 바탕
const GLASS_LINE := Color("485968")  # 모든 컨트롤 테두리(유리 바깥선과 같은 색)
const ACCENT := Color("7555a8")  # 연보라. 상점의 구매 버튼과 선택한 상품에만 쓴다.
const ACCENT_HOVER := Color("5f3d8e")
const ACCENT_SHADOW := Color("4e2f80")  # 구매 버튼 아래 단단한 그림자
const ACCENT_SOFT := Color("f1ebff")  # 선택한 상품 칸 바탕
const WARN := Color("a8372a")  # 닫기 마우스 올림
const WARN_HOVER := Color("8f2a1f")
const DISABLED_BG := Color("e1e7ea")
const DISABLED_FG := Color("8b979d")
const SHADOW := Color(FG, 0.22)
# 상점 패널
const PANEL_BG := Color("e8f6fa")
const MUTED := Color("536672")  # 설명·가격·보조 라벨
const LINE := Color("c1d5dd")  # 칸 테두리·구분선
const GLASS_HI := Color("edf3fa")  # 패널 안쪽 첫 번째 선
const GLASS_MID := Color("bacddb")  # 패널 안쪽 두 번째 선
const WATER_TOP := Color("d3eff4")  # 상품 그림 칸 바탕
const TAB_BG := Color("bee6ee")
const OK := Color("006f5a")  # 구매·판매 완료 문구, 진주 증가
const PEARL := Color("f0ecf7")
const PEARL_EDGE := Color("a99bbb")
const PEARL_SHADE := Color("d5cbe6")

const BORDER := 2
const RADIUS := 14
const ICON_RADIUS := 12
const SHADOW_OFFSET := 2  # 아래로 2px 그림자. 누르면 내용이 2px 내려가고 그림자가 사라진다.

const DISPLAY_FONT := preload("res://assets/fonts/Jua-Regular.ttf")
const BOLD_FONT := preload("res://assets/fonts/Pretendard-Bold.otf")
const MEDIUM_FONT := preload("res://assets/fonts/Pretendard-Medium.otf")


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = DISPLAY_FONT
	theme.default_font_size = 24

	# 흰 버튼(상점). 다른 버튼 종류의 기본값이기도 하다.
	_set_button_boxes(theme, "Button", SURFACE, HOVER, SURFACE, RADIUS, 12, 16)
	theme.set_stylebox("disabled", "Button", _box(DISABLED_BG, DISABLED_BG, RADIUS, 12, 16, false))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color",
			"icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		theme.set_color(state, "Button", FG)
	theme.set_color("font_disabled_color", "Button", DISABLED_FG)
	theme.set_color("icon_disabled_color", "Button", DISABLED_FG)
	theme.set_constant("h_separation", "Button", 8)
	theme.set_constant("icon_max_width", "Button", 22)

	# 아이콘만 있는 40×40 버튼(항상 위·닫기)
	theme.set_type_variation("IconButton", "Button")
	_set_button_boxes(theme, "IconButton", SURFACE, HOVER, SURFACE, ICON_RADIUS, 0, 0)

	# 항상 위: 켜면 진한 바탕에 채운 핀
	theme.set_type_variation("PinButton", "IconButton")
	theme.set_stylebox("pressed", "PinButton", _box(FG, FG, ICON_RADIUS, 0, 0))
	theme.set_stylebox("hover_pressed", "PinButton", _box(FG_HOVER, FG_HOVER, ICON_RADIUS, 0, 0))
	theme.set_color("icon_pressed_color", "PinButton", SURFACE)
	theme.set_color("icon_hover_pressed_color", "PinButton", SURFACE)

	# 닫기: 마우스를 올리면 빨간 바탕에 흰 ×
	theme.set_type_variation("CloseButton", "IconButton")
	theme.set_stylebox("hover", "CloseButton", _box(WARN, WARN, ICON_RADIUS, 0, 0))
	theme.set_stylebox("pressed", "CloseButton", _pressed(_box(WARN_HOVER, WARN_HOVER, ICON_RADIUS, 0, 0)))
	theme.set_color("icon_hover_color", "CloseButton", SURFACE)
	theme.set_color("icon_pressed_color", "CloseButton", SURFACE)

	# 손잡이(Panel). 마우스 올림은 main.gd에서 종류를 바꿔 표시한다.
	theme.set_type_variation("DragHandle", "Panel")
	theme.set_stylebox("panel", "DragHandle", _box(SURFACE, GLASS_LINE, RADIUS, 0, 0))
	theme.set_type_variation("DragHandleHover", "Panel")
	theme.set_stylebox("panel", "DragHandleHover", _box(HOVER, GLASS_LINE, RADIUS, 0, 0))

	_add_shop_types(theme)

	# 말풍선(아이콘 버튼 설명)
	var tooltip := _box(FG, FG, 10, 12, 12, false)
	tooltip.content_margin_top = 7
	tooltip.content_margin_bottom = 7
	theme.set_stylebox("panel", "TooltipPanel", tooltip)
	theme.set_font("font", "TooltipLabel", MEDIUM_FONT)
	theme.set_font_size("font_size", "TooltipLabel", 18)
	theme.set_color("font_color", "TooltipLabel", SURFACE)
	return theme


# 상점 패널(ShopPanel)의 칸·버튼·글자 종류
static func _add_shop_types(theme: Theme) -> void:
	var panel := _box(PANEL_BG, GLASS_LINE, 28, 0, 0)
	panel.set_border_width_all(4)
	panel.shadow_offset = Vector2(0, 14)
	theme.set_stylebox("panel", "ShopPanelBox", panel)
	theme.set_type_variation("ShopPanelBox", "Panel")

	# 진주 칩·상세 영역·탭 묶음·그림 칸·보유 배지
	theme.set_type_variation("WalletChip", "PanelContainer")
	theme.set_stylebox("panel", "WalletChip", _box(SURFACE, LINE, 24, 12, 18, false))
	theme.set_type_variation("DetailBox", "PanelContainer")
	var detail := _box(SURFACE, LINE, 20, 14, 14, false)
	detail.content_margin_top = 14
	detail.content_margin_bottom = 14
	theme.set_stylebox("panel", "DetailBox", detail)
	theme.set_type_variation("ShopTabs", "PanelContainer")
	var tabs := _box(TAB_BG, TAB_BG, 16, 4, 4, false)
	tabs.set_border_width_all(0)
	tabs.content_margin_top = 4
	tabs.content_margin_bottom = 4
	theme.set_stylebox("panel", "ShopTabs", tabs)
	theme.set_type_variation("SelectedTab", "PanelContainer")
	var tab := _box(SURFACE, SURFACE, 12, 0, 0)
	tab.set_border_width_all(0)
	tab.shadow_color = Color(FG, 0.16)
	theme.set_stylebox("panel", "SelectedTab", tab)
	theme.set_type_variation("Thumb", "PanelContainer")
	var thumb := _box(WATER_TOP, WATER_TOP, 11, 0, 0, false)
	thumb.set_border_width_all(0)
	theme.set_stylebox("panel", "Thumb", thumb)
	theme.set_type_variation("ThumbEmpty", "PanelContainer")
	theme.set_stylebox("panel", "ThumbEmpty", _box(SURFACE, LINE, 11, 0, 0, false))
	theme.set_type_variation("OwnedBadge", "PanelContainer")
	var badge := _box(FG, FG, 13, 9, 9)
	theme.set_stylebox("panel", "OwnedBadge", badge)
	theme.set_type_variation("StatsLine", "PanelContainer")
	var stats := StyleBoxFlat.new()
	stats.bg_color = Color.TRANSPARENT
	stats.border_color = LINE
	stats.border_width_top = BORDER
	stats.content_margin_top = 6
	theme.set_stylebox("panel", "StatsLine", stats)

	# 아직 고를 수 없는 탭(수초·어항)
	theme.set_type_variation("TabButton", "Button")
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		theme.set_stylebox(state, "TabButton", StyleBoxEmpty.new())

	# 상품 칸. 선택한 칸은 ShopCardSelected로 바꾼다. 누름 표시는 하지 않는다.
	theme.set_type_variation("ShopCard", "Button")
	theme.set_type_variation("ShopCardSelected", "Button")
	for state in ["normal", "pressed", "hover_pressed"]:
		theme.set_stylebox(state, "ShopCard", _box(SURFACE, LINE, 16, 0, 0, false))
		theme.set_stylebox(state, "ShopCardSelected", _box(ACCENT_SOFT, ACCENT, 16, 0, 0, false))
	theme.set_stylebox("hover", "ShopCard", _box(HOVER, LINE, 16, 0, 0, false))
	theme.set_stylebox("hover", "ShopCardSelected", _box(ACCENT_SOFT, ACCENT, 16, 0, 0, false))

	# 패널 닫기: 48×48, 연한 테두리
	theme.set_type_variation("PanelIconButton", "IconButton")
	_set_button_boxes(theme, "PanelIconButton", SURFACE, HOVER, SURFACE, RADIUS, 0, 0, LINE)

	# 구매: 연보라 바탕, 아래 4px 단단한 그림자. 누르면 3px 내려간다.
	theme.set_type_variation("BuyButton", "Button")
	var buy := _box(ACCENT, ACCENT, RADIUS, 0, 0)
	buy.shadow_color = ACCENT_SHADOW
	buy.shadow_offset = Vector2(0, 4)
	var buy_hover := buy.duplicate() as StyleBoxFlat
	buy_hover.bg_color = ACCENT_HOVER
	buy_hover.border_color = ACCENT_HOVER
	var buy_pressed := buy_hover.duplicate() as StyleBoxFlat
	buy_pressed.expand_margin_top = -3
	buy_pressed.expand_margin_bottom = 3
	buy_pressed.content_margin_top = 6
	buy_pressed.shadow_offset = Vector2(0, 1)
	theme.set_stylebox("normal", "BuyButton", buy)
	theme.set_stylebox("hover", "BuyButton", buy_hover)
	theme.set_stylebox("pressed", "BuyButton", buy_pressed)
	theme.set_stylebox("hover_pressed", "BuyButton", buy_pressed)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(state, "BuyButton", Color.WHITE)
	# 판매: 흰 바탕에 유리선 테두리
	theme.set_type_variation("SellButton", "Button")
	_set_button_boxes(theme, "SellButton", SURFACE, HOVER, SURFACE, RADIUS, 0, 0)
	for type in ["BuyButton", "SellButton"]:
		theme.set_stylebox("disabled", type, _box(DISABLED_BG, DISABLED_BG, RADIUS, 0, 0, false))
		theme.set_font_size("font_size", type, 25)

	# 글자
	var number_font := FontVariation.new()  # 고정폭 숫자
	number_font.base_font = BOLD_FONT
	number_font.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("tnum"): 1}
	_label(theme, "PanelTitle", DISPLAY_FONT, 36, FG)
	_label(theme, "DetailName", DISPLAY_FONT, 32, FG)
	_label(theme, "WalletAmount", DISPLAY_FONT, 28, FG)
	_label(theme, "DeltaLabel", DISPLAY_FONT, 22, OK)
	_label(theme, "TabLabel", DISPLAY_FONT, 24, FG)
	_label(theme, "TabCount", number_font, 18, MUTED)
	_label(theme, "CardName", BOLD_FONT, 20, FG)
	_label(theme, "CardPrice", MEDIUM_FONT, 20, MUTED)
	_label(theme, "MutedLabel", MEDIUM_FONT, 20, MUTED)
	_label(theme, "Description", MEDIUM_FONT, 21, MUTED)
	_label(theme, "StatName", MEDIUM_FONT, 18, MUTED)
	_label(theme, "StatValue", number_font, 23, FG)
	_label(theme, "Reason", MEDIUM_FONT, 19, WARN)
	_label(theme, "BadgeLabel", number_font, 18, SURFACE)
	_label(theme, "ThumbLabel", MEDIUM_FONT, 18, MUTED)
	theme.set_constant("line_spacing", "Description", 6)
	theme.set_color("font_disabled_color", "TabButton", DISABLED_FG)
	theme.set_font_size("font_size", "TabButton", 24)


static func _label(theme: Theme, type: String, font: Font, size: int, color: Color) -> void:
	theme.set_type_variation(type, "Label")
	theme.set_font("font", type, font)
	theme.set_font_size("font_size", type, size)
	theme.set_color("font_color", type, color)


static func _set_button_boxes(theme: Theme, type: String, normal: Color, hover: Color, pressed: Color,
		radius: int, margin_left: int, margin_right: int, border := GLASS_LINE) -> void:
	theme.set_stylebox("normal", type, _box(normal, border, radius, margin_left, margin_right))
	theme.set_stylebox("hover", type, _box(hover, border, radius, margin_left, margin_right))
	theme.set_stylebox("pressed", type, _pressed(_box(pressed, border, radius, margin_left, margin_right)))
	theme.set_stylebox("hover_pressed", type, _pressed(_box(pressed, border, radius, margin_left, margin_right)))


static func _box(bg: Color, border: Color, radius: int, margin_left: int, margin_right: int, shadow := true) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(BORDER)
	box.set_corner_radius_all(radius)
	box.content_margin_left = margin_left
	box.content_margin_right = margin_right
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	if shadow:
		box.shadow_color = SHADOW
		box.shadow_offset = Vector2(0, SHADOW_OFFSET)
		box.shadow_size = 1
	return box


# 누른 모양: 상자와 글자를 2px 내리고 그림자를 없앤다.
static func _pressed(box: StyleBoxFlat) -> StyleBoxFlat:
	box.expand_margin_top = -SHADOW_OFFSET
	box.expand_margin_bottom = SHADOW_OFFSET
	box.content_margin_top = SHADOW_OFFSET * 2
	box.shadow_size = 0
	box.shadow_color = Color.TRANSPARENT
	return box
