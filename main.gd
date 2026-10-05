extends Node2D

@onready var close_button: Button = $CloseButton
@onready var add_button: Button = $AddButton
@onready var aquarium: Aquarium = $Aquarium


func _ready() -> void:
	close_button.pressed.connect(_on_close_button_pressed)
	add_button.pressed.connect(_on_add_button_pressed)
	aquarium.fish_count_changed.connect(_update_add_button)
	_update_add_button(aquarium.fish_count)
	_set_click_area(Aquarium.TANK_RECT)
	_move_to_bottom_right()


# 창을 현재 디스플레이의 오른쪽 아래로 옮긴다.
# usable rect는 Dock과 메뉴 막대를 뺀 영역이라 위젯이 Dock에 가려지지 않는다.
func _move_to_bottom_right() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var window_size := DisplayServer.window_get_size()
	DisplayServer.window_set_position(usable.end - window_size)


# 지정한 영역만 클릭을 받고, 바깥 투명 여백의 클릭은 뒤쪽 앱으로 넘긴다.
# 투명 창에서는 이 영역을 지정하지 않으면 어항 위의 클릭도 뒤로 빠진다(macOS에서 확인).
func _set_click_area(rect: Rect2) -> void:
	var polygon := PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	DisplayServer.window_set_mouse_passthrough(polygon)


func _on_close_button_pressed() -> void:
	get_tree().quit()


func _on_add_button_pressed() -> void:
	aquarium.add_fish()


func _update_add_button(count: int) -> void:
	add_button.text = "추가 %d/%d" % [count, Aquarium.MAX_FISH]
	add_button.disabled = count >= Aquarium.MAX_FISH
