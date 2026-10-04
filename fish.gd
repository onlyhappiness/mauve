extends Node2D

# 꼬리를 포함한 전체 크기. 원점(0, 0)이 물고기의 중심이고 오른쪽을 바라본다.
const SIZE := Vector2(72, 44)

const BODY_COLOR := Color("ffb38a")  # 살구색 몸통
const TAIL_COLOR := Color("f59a72")  # 조금 진한 꼬리
const EYE_COLOR := Color("3d2c2e")
const EYE_HIGHLIGHT_COLOR := Color.WHITE

const BODY_CENTER := Vector2(9, 0)
const BODY_RADIUS := Vector2(27, 22)  # 몸통 가로 54, 세로 44


func _draw() -> void:
	var half := SIZE / 2

	# 꼬리를 먼저 그려 몸통이 꼬리 뿌리를 덮게 한다.
	var tail := PackedVector2Array([
		Vector2(-14, 0),
		Vector2(-half.x, -16),
		Vector2(-half.x, 16),
	])
	draw_colored_polygon(tail, TAIL_COLOR)

	draw_colored_polygon(_ellipse(BODY_CENTER, BODY_RADIUS), BODY_COLOR)

	draw_circle(Vector2(22, -6), 5, EYE_COLOR)
	draw_circle(Vector2(23.5, -7.5), 1.6, EYE_HIGHLIGHT_COLOR)


func _ellipse(center: Vector2, radius: Vector2, segments: int = 32) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * i / segments
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points
