class_name Screen
extends Node2D

# 화면 전체 아쿠아리움. 주 모니터에서 메뉴 막대·Dock을 뺀 영역을 투명 창으로 덮고
# 그 안 전체를 물고기가 헤엄친다. 클릭은 모두 뒤쪽 앱으로 넘긴다.
# 조작은 메뉴 막대 아이콘(StatusIndicator)의 메뉴로 한다.
# 진주·물고기·메뉴 설정은 Game이 가지고, 여기서는 Game 시그널을 받아 Fish 노드와 창 설정에 반영한다.

enum MenuItem { ALWAYS_ON_TOP, FISH_VISIBLE, QUIT }

@export var fish_scene: PackedScene

var water := Rect2()  # 물고기 헤엄 영역(창 전체)

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

	water = Rect2(Vector2.ZERO, usable.size)
	for i in Game.fish_count():
		_spawn_fish(i)
	Game.fish_added.connect(_spawn_fish)
	Game.fish_removed.connect(_despawn_fish)
	Game.about_to_save.connect(_write_fish_positions)

	menu.add_check_item("항상 위에 표시", MenuItem.ALWAYS_ON_TOP)
	menu.add_check_item("물고기 보이기", MenuItem.FISH_VISIBLE)
	menu.add_separator()
	menu.add_item("종료", MenuItem.QUIT)
	menu.id_pressed.connect(_on_menu_id_pressed)
	Game.screen_setting_changed.connect(_apply_screen_setting)
	for key: String in Game.screen_settings:
		_apply_screen_setting(key, Game.screen_settings[key])


# Game.fish의 index번째 물고기를 화면 아무 곳에 넣는다. 위치는 저장해도 시작할 때는 다시 고른다.
func _spawn_fish(index: int) -> void:
	var fish := fish_scene.instantiate() as Fish
	fish.water = water
	var area := water.grow(-Fish.EDGE_MARGIN).grow_individual(-Fish.SIZE.x / 2, -Fish.SIZE.y / 2, -Fish.SIZE.x / 2, -Fish.SIZE.y / 2)
	fish.position = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y)).floor()
	fishes.add_child(fish)
	fishes.move_child(fish, index)


func _despawn_fish(index: int) -> void:
	var fish := fishes.get_child(index)
	# queue_free()만 하면 이번 프레임에는 자식으로 남아 Game.fish와 순서가 어긋나므로 먼저 떼어 낸다.
	fishes.remove_child(fish)
	fish.queue_free()


# 저장 직전에 지금 위치를 Game.fish에 적는다. 지금은 금붕어 한 종류뿐이라 장면도 하나다.
func _write_fish_positions() -> void:
	for i in mini(fishes.get_child_count(), Game.fish_count()):
		var fish := fishes.get_child(i) as Node2D
		Game.fish[i]["x"] = fish.position.x
		Game.fish[i]["y"] = fish.position.y


func _on_menu_id_pressed(id: int) -> void:
	match id:
		MenuItem.ALWAYS_ON_TOP:
			Game.set_screen_setting("always_on_top", not Game.screen_settings["always_on_top"])
		MenuItem.FISH_VISIBLE:
			Game.set_screen_setting("fish_visible", not Game.screen_settings["fish_visible"])
		MenuItem.QUIT:
			Game.save()
			get_tree().quit()


func _apply_screen_setting(key: String, value: bool) -> void:
	match key:
		"always_on_top":
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, value)
			menu.set_item_checked(menu.get_item_index(MenuItem.ALWAYS_ON_TOP), value)
		"fish_visible":
			_set_fish_visible(value)


# 숨기면 물고기 움직임도 멈추고, 바뀌는 것이 없을 때는 다시 그리지 않게 해 CPU를 아낀다.
func _set_fish_visible(shown: bool) -> void:
	fishes.visible = shown
	fishes.process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED
	OS.low_processor_usage_mode = not shown
	menu.set_item_checked(menu.get_item_index(MenuItem.FISH_VISIBLE), shown)
