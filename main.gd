extends Node2D

const CLICK_ARC_STEPS := 8  # 클릭 영역의 둥근 모서리 하나를 나누는 선분 수
const PIN_ICON := preload("res://assets/ui/pin.svg")
const PIN_FILLED_ICON := preload("res://assets/ui/pin_filled.svg")
const WINDOW_CHECK_INTERVAL := 1.0  # 창을 옮겼는지 살피는 간격(초)

@onready var aquarium: Aquarium = $Aquarium
@onready var ui: Control = $UI
@onready var drag_handle: Panel = $UI/DragHandle
@onready var always_on_top_button: Button = $UI/AlwaysOnTopButton
@onready var close_button: Button = $UI/CloseButton
@onready var dock: HBoxContainer = $UI/Dock
@onready var shop_button: Button = $UI/Dock/ShopButton
@onready var shop_panel: ShopPanel = $UI/ShopPanel

var saved_window_position := Vector2i.ZERO  # 마지막으로 저장한 창 위치
var checked_window_position := Vector2i.ZERO  # 직전에 살펴본 창 위치
var save_pending := false  # 마지막 저장이 실패해 다시 시도해야 하는지


func _ready() -> void:
	var data := SaveData.load_data()
	for fish: Dictionary in data["fish"]:
		aquarium.add_fish(Vector2(fish["x"], fish["y"]))
	always_on_top_button.set_pressed_no_signal(data["always_on_top"])
	shop_panel.setup(aquarium, data["pearls"])

	ui.theme = WidgetTheme.build()
	close_button.pressed.connect(_on_close_button_pressed)
	shop_button.pressed.connect(_set_shop_open.bind(true))
	shop_panel.closed.connect(_set_shop_open.bind(false))
	always_on_top_button.toggled.connect(_set_always_on_top)
	_set_always_on_top(always_on_top_button.button_pressed)
	drag_handle.gui_input.connect(_on_drag_handle_gui_input)
	drag_handle.mouse_entered.connect(_set_drag_handle_hover.bind(true))
	drag_handle.mouse_exited.connect(_set_drag_handle_hover.bind(false))
	# 아래 버튼 묶음은 글자 폭에 따라 크기가 정해지므로, 배치가 끝날 때마다 클릭 영역을 다시 잡는다.
	dock.sort_children.connect(_update_click_area)
	_place_window(data["window"])
	saved_window_position = DisplayServer.window_get_position()
	checked_window_position = saved_window_position

	# 불러오기가 끝난 뒤에 연결해서, 복원 중에는 저장하지 않는다.
	shop_panel.changed.connect(_save)
	always_on_top_button.toggled.connect(_save.unbind(1))
	var window_check := Timer.new()
	window_check.wait_time = WINDOW_CHECK_INTERVAL
	window_check.timeout.connect(_check_window_moved)
	add_child(window_check)
	window_check.start()


# Cmd+Q 등으로 창을 닫을 때도 저장한다.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()


func _save() -> void:
	var window_position := DisplayServer.window_get_position()
	var saved := SaveData.save({
		"pearls": shop_panel.pearls,
		"always_on_top": always_on_top_button.button_pressed,
		"window": {"x": window_position.x, "y": window_position.y},
		"fish": aquarium.fish_states(),
	})
	# 실패하면 창 위치와 상관없이 다음 위치 검사에서 다시 시도한다.
	# 매번 현재 상태 전체를 쓰므로 한 번 성공하면 밀린 변경이 모두 반영된다.
	save_pending = not saved
	if saved:
		saved_window_position = window_position


# 창 끌기는 macOS가 처리해서 끝났다는 신호가 없다. 위치가 바뀐 뒤 한 번 더 살폈을 때도
# 그대로이면 끌기를 마친 것으로 보고 저장한다. 직전 저장이 실패했으면 여기서 다시 시도한다.
func _check_window_moved() -> void:
	var window_position := DisplayServer.window_get_position()
	var moved := window_position != saved_window_position and window_position == checked_window_position
	if save_pending or moved:
		_save()
	checked_window_position = window_position


# 저장한 위치가 지금 연결된 화면 안에 있으면 그곳에, 아니면 오른쪽 아래에 둔다.
func _place_window(saved: Variant) -> void:
	if saved is Dictionary:
		var window_position := Vector2i(saved["x"], saved["y"])
		var center := window_position + DisplayServer.window_get_size() / 2
		for screen in DisplayServer.get_screen_count():
			if DisplayServer.screen_get_usable_rect(screen).has_point(center):
				DisplayServer.window_set_position(window_position)
				return
	_move_to_bottom_right()


# 창을 현재 디스플레이의 오른쪽 아래로 옮긴다.
# usable rect는 Dock과 메뉴 막대를 뺀 영역이라 위젯이 Dock에 가려지지 않는다.
func _move_to_bottom_right() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var window_size := DisplayServer.window_get_size()
	DisplayServer.window_set_position(usable.end - window_size)


# 상점 패널은 어항과 아래 버튼 묶음을 덮는다. 손잡이·항상 위·닫기는 패널 위쪽에 그대로 둔다.
func _set_shop_open(open: bool) -> void:
	if open:
		shop_panel.open()
	dock.visible = not open
	_update_click_area()


func _update_click_area() -> void:
	var top_buttons := always_on_top_button.get_rect().merge(close_button.get_rect())
	# 버튼 아래 그림자까지 클릭을 받게 한다.
	top_buttons.size.y += WidgetTheme.SHADOW_OFFSET
	if shop_panel.visible:
		DisplayServer.window_set_mouse_passthrough(_click_area(shop_panel.get_rect(), ShopPanel.RADIUS, drag_handle.get_rect(), top_buttons, Rect2()))
		return
	var bottom_buttons := shop_button.get_global_rect()
	bottom_buttons.size.y += WidgetTheme.SHADOW_OFFSET
	DisplayServer.window_set_mouse_passthrough(_click_area(Aquarium.TANK_RECT, Aquarium.CORNER_RADIUS, drag_handle.get_rect(), top_buttons, bottom_buttons))


# 어항과 바깥 여백의 컨트롤만 클릭을 받고, 나머지 투명 여백의 클릭은 뒤쪽 앱으로 넘긴다.
# 투명 창에서는 이 영역을 지정하지 않으면 어항 위의 클릭도 뒤로 빠진다(macOS에서 확인).
# 다각형은 하나만 지정할 수 있어서, 둥근 어항 외곽에 컨트롤 자리가 탭처럼 튀어나온 모양으로 잇는다.
# 위: 가운데 손잡이, 오른쪽 위 버튼(항상 위·닫기). 아래: 오른쪽 버튼 묶음(상점). 크기가 없으면 아래 탭은 넣지 않는다.
# 상점을 열면 어항 대신 상점 패널 외곽(모서리 28)에 같은 위쪽 탭을 붙인다.
# 오른쪽 탭은 어항 둥근 모서리 위·아래에 걸치므로, 탭 끝에서 모서리 호의 시작·끝점으로 바로 이어
# 모서리 바깥 투명 부분은 클릭을 받지 않게 한다.
# 현재 UI와 Aquarium은 창 좌표와 같은 원점·배율을 쓰며, 손잡이는 어항 위쪽 직선 구간에 있다.
# 오른쪽 버튼 묶음은 각각 어항 위·아래에 있고 오른쪽 끝은 어항 끝 안쪽에 있어야 한다.
# 상점 패널(y 45~525)도 위쪽 컨트롤(y 2~44) 아래에서 시작하고 손잡이는 패널 위쪽 직선 구간에 있다.
# 위치·배율 변경이나 상점 패널 추가 시 이 연결 순서를 재검토하고 실제 창에서 클릭 통과를 확인한다.
func _click_area(tank: Rect2, radius: float, handle: Rect2, top_right: Rect2, bottom_right: Rect2) -> PackedVector2Array:
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
	if bottom_right.has_area():
		polygon.append(Vector2(bottom_right.end.x, bottom_right.position.y))
		polygon.append(bottom_right.end)
		polygon.append(Vector2(bottom_right.position.x, bottom_right.end.y))
		polygon.append(bottom_right.position)
	_append_arc(polygon, Vector2(tank.position.x + radius, tank.end.y - radius), radius, 90.0)  # 왼쪽 아래
	return polygon


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
	_save()
	get_tree().quit()
