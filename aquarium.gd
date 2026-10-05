class_name Aquarium
extends Node2D

signal fish_count_changed(count: int)

# 어항이 차지하는 영역(창 기준 논리 픽셀). 이 바깥은 투명하게 남는다.
const TANK_RECT := Rect2(60, 45, 600, 450)
const BORDER_WIDTH := 15
const CORNER_RADIUS := 72
const MAX_FISH := 5

const BORDER_COLOR := Color("fff4dc")  # 크림색 테두리
const WATER_COLOR := Color("a8e6cf")  # 민트색 물

@export var fish_scene: PackedScene

var fish_count := 0


func _ready() -> void:
	add_fish()


# 생성 경로를 한곳으로 모아 버튼 이외의 호출에서도 최대 마릿수를 지킨다.
func add_fish() -> bool:
	if fish_count >= MAX_FISH:
		return false

	var fish := fish_scene.instantiate() as Node2D
	# _ready()에서 목적지를 고르기 전에 안전한 시작 위치를 설정한다.
	fish.position = TANK_RECT.get_center()
	add_child(fish)
	fish_count += 1
	fish_count_changed.emit(fish_count)
	return true


func _draw() -> void:
	var tank := StyleBoxFlat.new()
	tank.bg_color = WATER_COLOR
	tank.border_color = BORDER_COLOR
	tank.set_border_width_all(BORDER_WIDTH)
	tank.set_corner_radius_all(CORNER_RADIUS)
	draw_style_box(tank, TANK_RECT)
