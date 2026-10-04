class_name Aquarium
extends Node2D

# 어항이 차지하는 영역(창 기준 논리 픽셀). 이 바깥은 투명하게 남는다.
const TANK_RECT := Rect2(60, 45, 600, 450)

const BORDER_COLOR := Color("fff4dc")  # 크림색 테두리
const WATER_COLOR := Color("a8e6cf")  # 민트색 물


func _draw() -> void:
	var tank := StyleBoxFlat.new()
	tank.bg_color = WATER_COLOR
	tank.border_color = BORDER_COLOR
	tank.set_border_width_all(15)
	tank.set_corner_radius_all(72)
	draw_style_box(tank, TANK_RECT)
