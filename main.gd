extends Node2D

const CLICK_ARC_STEPS := 8  # 클릭 영역의 둥근 모서리 하나를 나누는 선분 수
const PIN_ICON := preload("res://assets/ui/pin.svg")
const PIN_FILLED_ICON := preload("res://assets/ui/pin_filled.svg")
const ADD_MIN_WIDTH := 140.0

@onready var aquarium: Aquarium = $Aquarium
@onready var ui: Control = $UI
@onready var drag_handle: Panel = $UI/DragHandle
@onready var always_on_top_button: Button = $UI/AlwaysOnTopButton
@onready var close_button: Button = $UI/CloseButton
@onready var dock: HBoxContainer = $UI/Dock
@onready var shop_button: Button = $UI/Dock/ShopButton
@onready var add_button: Button = $UI/Dock/AddButton
@onready var add_content: Control = $UI/Dock/AddButton/Content
@onready var add_count: Label = $UI/Dock/AddButton/Content/Count


func _ready() -> void:
	ui.theme = WidgetTheme.build()
	close_button.pressed.connect(_on_close_button_pressed)
	add_button.pressed.connect(_on_add_button_pressed)
	add_button.button_down.connect(_shift_add_content.bind(WidgetTheme.SHADOW_OFFSET))
	add_button.button_up.connect(_shift_add_content.bind(0))
	aquarium.fish_count_changed.connect(_update_add_button)
	_update_add_button(aquarium.fish_count)
	always_on_top_button.toggled.connect(_set_always_on_top)
	_set_always_on_top(always_on_top_button.button_pressed)  # 기본값: 꺼짐
	drag_handle.gui_input.connect(_on_drag_handle_gui_input)
	drag_handle.mouse_entered.connect(_set_drag_handle_hover.bind(true))
	drag_handle.mouse_exited.connect(_set_drag_handle_hover.bind(false))
	# 아래 버튼 묶음은 글자 폭에 따라 크기가 정해지므로, 배치가 끝날 때마다 클릭 영역을 다시 잡는다.
	dock.sort_children.connect(_update_click_area)
	_move_to_bottom_right()


# 창을 현재 디스플레이의 오른쪽 아래로 옮긴다.
# usable rect는 Dock과 메뉴 막대를 뺀 영역이라 위젯이 Dock에 가려지지 않는다.
func _move_to_bottom_right() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var window_size := DisplayServer.window_get_size()
	DisplayServer.window_set_position(usable.end - window_size)


func _update_click_area() -> void:
	var top_buttons := always_on_top_button.get_rect().merge(close_button.get_rect())
	var bottom_buttons := shop_button.get_global_rect().merge(add_button.get_global_rect())
	# 버튼 아래 그림자까지 클릭을 받게 한다.
	top_buttons.size.y += WidgetTheme.SHADOW_OFFSET
	bottom_buttons.size.y += WidgetTheme.SHADOW_OFFSET
	_set_click_area(Aquarium.TANK_RECT, Aquarium.CORNER_RADIUS, drag_handle.get_rect(), top_buttons, bottom_buttons)


# 어항과 바깥 여백의 컨트롤만 클릭을 받고, 나머지 투명 여백의 클릭은 뒤쪽 앱으로 넘긴다.
# 투명 창에서는 이 영역을 지정하지 않으면 어항 위의 클릭도 뒤로 빠진다(macOS에서 확인).
# 다각형은 하나만 지정할 수 있어서, 둥근 어항 외곽에 컨트롤 자리가 탭처럼 튀어나온 모양으로 잇는다.
# 위: 가운데 손잡이, 오른쪽 위 버튼(항상 위·닫기). 아래: 오른쪽 버튼 묶음(상점·추가).
# 오른쪽 탭은 어항 둥근 모서리 위·아래에 걸치므로, 탭 끝에서 모서리 호의 시작·끝점으로 바로 이어
# 모서리 바깥 투명 부분은 클릭을 받지 않게 한다.
func _set_click_area(tank: Rect2, radius: float, handle: Rect2, top_right: Rect2, bottom_right: Rect2) -> void:
	var polygon := PackedVector2Array()
	_append_arc(polygon, tank.position + Vector2(radius, radius), radius, 180.0)  # 왼쪽 위
	polygon.append(Vector2(handle.position.x, tank.position.y))
	polygon.append(handle.position)
	polygon.append(Vector2(handle.end.x, handle.position.y))
	polygon.append(Vector2(handle.end.x, tank.position.y))
	polygon.append(Vector2(top_right.position.x, tank.position.y))
	polygon.append(top_right.position)
	polygon.append(Vector2(top_right.end.x, top_right.position.y))
	polygon.append(top_right.end)
	_append_arc(polygon, Vector2(tank.end.x - radius, tank.position.y + radius), radius, 270.0)  # 오른쪽 위
	_append_arc(polygon, tank.end - Vector2(radius, radius), radius, 0.0)  # 오른쪽 아래
	polygon.append(Vector2(bottom_right.end.x, bottom_right.position.y))
	polygon.append(bottom_right.end)
	polygon.append(Vector2(bottom_right.position.x, bottom_right.end.y))
	polygon.append(bottom_right.position)
	_append_arc(polygon, Vector2(tank.position.x + radius, tank.end.y - radius), radius, 90.0)  # 왼쪽 아래
	DisplayServer.window_set_mouse_passthrough(polygon)


# start_degrees부터 시계 방향으로 90도 호의 점들을 덧붙인다(화면 좌표는 y가 아래로 증가).
func _append_arc(polygon: PackedVector2Array, center: Vector2, radius: float, start_degrees: float) -> void:
	for i in CLICK_ARC_STEPS + 1:
		var angle := deg_to_rad(start_degrees + 90.0 * i / CLICK_ARC_STEPS)
		polygon.append(center + Vector2(cos(angle), sin(angle)) * radius)


# 손잡이를 누르면 macOS 기본 창 끌기로 창을 옮긴다.
func _on_drag_handle_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		DisplayServer.window_start_drag()


func _set_drag_handle_hover(hovered: bool) -> void:
	drag_handle.theme_type_variation = &"DragHandleHover" if hovered else &"DragHandle"


func _set_always_on_top(enabled: bool) -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, enabled)
	always_on_top_button.icon = PIN_FILLED_ICON if enabled else PIN_ICON
	always_on_top_button.tooltip_text = "항상 위: 켬" if enabled else "항상 위: 끔"


func _on_close_button_pressed() -> void:
	get_tree().quit()


func _on_add_button_pressed() -> void:
	aquarium.add_fish()


# 추가 버튼의 글자는 자식 노드라 버튼 누름 모양(2px 내려감)을 직접 따라가게 한다.
func _shift_add_content(offset: float) -> void:
	add_content.position.y = offset


func _update_add_button(count: int) -> void:
	add_count.text = "%d/%d" % [count, Aquarium.MAX_FISH]
	add_button.disabled = count >= Aquarium.MAX_FISH
	add_button.tooltip_text = "어항이 가득 찼어요" if add_button.disabled else ""
	add_content.modulate = WidgetTheme.DISABLED_FG if add_button.disabled else Color.WHITE
	# 버튼은 자식 내용 크기를 따라 커지지 않으므로 폭을 직접 맞춘다(왼쪽 여백 10 + 오른쪽 14).
	add_button.custom_minimum_size.x = maxf(ADD_MIN_WIDTH, add_content.get_combined_minimum_size().x + 24.0)
