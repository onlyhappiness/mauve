extends Node2D

const CLICK_ARC_STEPS := 8  # 클릭 영역의 둥근 모서리 하나를 나누는 선분 수

@onready var close_button: Button = $CloseButton
@onready var add_button: Button = $AddButton
@onready var aquarium: Aquarium = $Aquarium
@onready var always_on_top_button: Button = $AlwaysOnTopButton
@onready var drag_handle: Control = $DragHandle


func _ready() -> void:
	close_button.pressed.connect(_on_close_button_pressed)
	add_button.pressed.connect(_on_add_button_pressed)
	aquarium.fish_count_changed.connect(_update_add_button)
	_update_add_button(aquarium.fish_count)
	always_on_top_button.toggled.connect(_set_always_on_top)
	_set_always_on_top(always_on_top_button.button_pressed)  # 기본값: 꺼짐
	drag_handle.gui_input.connect(_on_drag_handle_gui_input)
	_set_click_area(Aquarium.TANK_RECT, Aquarium.CORNER_RADIUS, drag_handle.get_rect())
	_move_to_bottom_right()


# 창을 현재 디스플레이의 오른쪽 아래로 옮긴다.
# usable rect는 Dock과 메뉴 막대를 뺀 영역이라 위젯이 Dock에 가려지지 않는다.
func _move_to_bottom_right() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var window_size := DisplayServer.window_get_size()
	DisplayServer.window_set_position(usable.end - window_size)


# 어항과 그 위쪽 손잡이만 클릭을 받고, 바깥 투명 여백의 클릭은 뒤쪽 앱으로 넘긴다.
# 투명 창에서는 이 영역을 지정하지 않으면 어항 위의 클릭도 뒤로 빠진다(macOS에서 확인).
# 다각형은 하나만 지정할 수 있어서, 둥근 어항 외곽 위쪽 가운데에 손잡이 탭이 튀어나온 모양으로 잇는다.
func _set_click_area(tank: Rect2, radius: float, handle: Rect2) -> void:
	var polygon := PackedVector2Array()
	_append_arc(polygon, tank.position + Vector2(radius, radius), radius, 180.0)  # 왼쪽 위
	polygon.append(Vector2(handle.position.x, tank.position.y))
	polygon.append(handle.position)
	polygon.append(Vector2(handle.end.x, handle.position.y))
	polygon.append(Vector2(handle.end.x, tank.position.y))
	_append_arc(polygon, Vector2(tank.end.x - radius, tank.position.y + radius), radius, 270.0)  # 오른쪽 위
	_append_arc(polygon, tank.end - Vector2(radius, radius), radius, 0.0)  # 오른쪽 아래
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


func _set_always_on_top(enabled: bool) -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, enabled)
	always_on_top_button.text = "항상 위: 켬" if enabled else "항상 위: 끔"


func _on_close_button_pressed() -> void:
	get_tree().quit()


func _on_add_button_pressed() -> void:
	aquarium.add_fish()


func _update_add_button(count: int) -> void:
	add_button.text = "추가 %d/%d" % [count, Aquarium.MAX_FISH]
	add_button.disabled = count >= Aquarium.MAX_FISH
