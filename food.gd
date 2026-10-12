class_name Food
extends Node2D

# 먹이 알갱이 하나. 물 위쪽에서 천천히 가라앉아 floor_y에서 멈춘다.
# 물고기 한 마리가 이 알갱이를 맡아 먹으러 온다(Fish.food).

const SINK_SPEED := 18.0
const COLOR := Color("b06a3b")
const SHADE := Color("7d4527")

var floor_y := 0.0  # 물고기가 닿을 수 있는 가장 낮은 높이. Aquarium이 정한다.


func _process(delta: float) -> void:
	position.y = minf(position.y + SINK_SPEED * delta, floor_y)


# 2 게임 픽셀 격자에 맞춘 8×8(4×4칸) 알갱이. 오른쪽 아래 2×2칸을 진하게 칠한다.
func _draw() -> void:
	draw_rect(Rect2(-4, -4, 8, 8), COLOR)
	draw_rect(Rect2(0, 0, 4, 4), SHADE)
