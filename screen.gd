class_name Screen
extends Node2D

# 화면 전체 아쿠아리움. 주 모니터에서 메뉴 막대·Dock을 뺀 영역을 투명 창으로 덮고
# 그 안 전체를 물고기가 헤엄친다. 클릭은 모두 뒤쪽 앱으로 넘긴다.
# 조작은 메뉴 막대 아이콘(StatusIndicator)의 메뉴로 한다.
# 물고기는 저장 파일의 마릿수(최소 1)만큼 넣는다. 저장은 메뉴 설정(SaveData "screen")만 바꿔 쓴다.

enum MenuItem { ALWAYS_ON_TOP, FISH_VISIBLE, QUIT }

@export var fish_scene: PackedScene

var data: Dictionary  # 불러온 저장 내용. 다른 항목은 그대로 두고 "screen"만 바꿔 다시 쓴다.

@onready var fishes: Node2D = $Fishes
@onready var menu: PopupMenu = $StatusIndicator/Menu


func _ready() -> void:
	var window := get_window()
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen())
	if not usable.has_area():  # headless 실행처럼 화면 정보가 없으면 지금 창 크기를 쓴다
		usable = Rect2i(window.position, window.size)
	window.position = usable.position
	window.size = usable.size
	# 창 픽셀과 게임 픽셀을 1:1로 맞춰 물고기가 기존 위젯과 같은 크기로 보이게 한다.
	window.content_scale_size = usable.size
	# 넓이가 없는 다각형이라 어느 점도 안에 들지 않아 모든 클릭이 뒤로 넘어간다.
	# 빈 배열을 주면 반대로 통과가 꺼져 창 전체가 클릭을 받는다.
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]))

	data = SaveData.load_data()
	var water := Rect2(Vector2.ZERO, usable.size)
	for i in maxi(data["fish"].size(), 1):
		_add_fish(water)

	menu.add_check_item("항상 위에 표시", MenuItem.ALWAYS_ON_TOP)
	menu.add_check_item("물고기 보이기", MenuItem.FISH_VISIBLE)
	menu.add_separator()
	menu.add_item("종료", MenuItem.QUIT)
	menu.id_pressed.connect(_on_menu_id_pressed)
	_set_always_on_top(data["screen"]["always_on_top"])
	_set_fish_visible(data["screen"]["fish_visible"])


# Cmd+Q 등으로 창을 닫을 때도 저장한다.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()


func _add_fish(water: Rect2) -> void:
	var fish := fish_scene.instantiate() as Fish
	fish.water = water
	fish.corner_radius = 0.0
	var area := water.grow(-Fish.EDGE_MARGIN).grow_individual(-Fish.SIZE.x / 2, -Fish.SIZE.y / 2, -Fish.SIZE.x / 2, -Fish.SIZE.y / 2)
	fish.position = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y)).floor()
	fishes.add_child(fish)


func _on_menu_id_pressed(id: int) -> void:
	match id:
		MenuItem.ALWAYS_ON_TOP:
			_set_always_on_top(not data["screen"]["always_on_top"])
			_save()
		MenuItem.FISH_VISIBLE:
			_set_fish_visible(not data["screen"]["fish_visible"])
			_save()
		MenuItem.QUIT:
			_save()
			get_tree().quit()


func _set_always_on_top(enabled: bool) -> void:
	data["screen"]["always_on_top"] = enabled
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, enabled)
	menu.set_item_checked(menu.get_item_index(MenuItem.ALWAYS_ON_TOP), enabled)


# 숨기면 물고기 움직임도 멈추고, 바뀌는 것이 없을 때는 다시 그리지 않게 해 CPU를 아낀다.
func _set_fish_visible(shown: bool) -> void:
	data["screen"]["fish_visible"] = shown
	fishes.visible = shown
	fishes.process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED
	OS.low_processor_usage_mode = not shown
	menu.set_item_checked(menu.get_item_index(MenuItem.FISH_VISIBLE), shown)


func _save() -> void:
	SaveData.save(data)
