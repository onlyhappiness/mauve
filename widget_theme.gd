class_name WidgetTheme
extends RefCounted

# 기본 화면 컨트롤의 색·테두리·글꼴. 수치는 OpenDesign 기본 화면 시안(DESIGN.md)을 따른다(Godot 픽셀 기준).

const SURFACE := Color("f9feff")  # 컨트롤 바탕
const FG := Color("223543")  # 글자·아이콘, 항상 위 켬 바탕, 말풍선 바탕
const FG_HOVER := Color("3a4d5c")
const HOVER := Color("d6edf2")  # 흰 컨트롤 마우스 올림 바탕
const GLASS_LINE := Color("485968")  # 모든 컨트롤 테두리(유리 바깥선과 같은 색)
const ACCENT := Color("7555a8")  # 연보라. 추가 버튼에만 쓴다.
const ACCENT_HOVER := Color("5f3d8e")
const WARN := Color("a8372a")  # 닫기 마우스 올림
const WARN_HOVER := Color("8f2a1f")
const DISABLED_BG := Color("e1e7ea")
const DISABLED_FG := Color("8b979d")
const SHADOW := Color(FG, 0.22)

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

	# 추가: 화면에서 유일한 연보라 버튼. 내용은 자식 노드(Content)로 그린다.
	theme.set_type_variation("AccentButton", "Button")
	_set_button_boxes(theme, "AccentButton", ACCENT, ACCENT_HOVER, ACCENT, RADIUS, 10, 14, ACCENT)
	theme.set_stylebox("disabled", "AccentButton", _box(DISABLED_BG, DISABLED_BG, RADIUS, 10, 14, false))

	# 손잡이(Panel). 마우스 올림은 main.gd에서 종류를 바꿔 표시한다.
	theme.set_type_variation("DragHandle", "Panel")
	theme.set_stylebox("panel", "DragHandle", _box(SURFACE, GLASS_LINE, RADIUS, 0, 0))
	theme.set_type_variation("DragHandleHover", "Panel")
	theme.set_stylebox("panel", "DragHandleHover", _box(HOVER, GLASS_LINE, RADIUS, 0, 0))

	# 추가 버튼 안의 글자: "추가"는 Jua, 수량은 Pretendard Bold 고정폭 숫자
	theme.set_type_variation("ButtonLabel", "Label")
	theme.set_color("font_color", "ButtonLabel", Color.WHITE)
	theme.set_type_variation("CountLabel", "ButtonLabel")
	var count_font := FontVariation.new()
	count_font.base_font = BOLD_FONT
	count_font.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("tnum"): 1}
	theme.set_font("font", "CountLabel", count_font)
	theme.set_font_size("font_size", "CountLabel", 20)

	# 말풍선(아이콘 버튼 설명)
	var tooltip := _box(FG, FG, 10, 12, 12, false)
	tooltip.content_margin_top = 7
	tooltip.content_margin_bottom = 7
	theme.set_stylebox("panel", "TooltipPanel", tooltip)
	theme.set_font("font", "TooltipLabel", MEDIUM_FONT)
	theme.set_font_size("font_size", "TooltipLabel", 18)
	theme.set_color("font_color", "TooltipLabel", SURFACE)
	return theme


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
