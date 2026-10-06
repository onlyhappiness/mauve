class_name Aquarium
extends Node2D

signal fish_count_changed(count: int)

# 어항이 차지하는 영역(창 기준 논리 픽셀). 이 바깥은 투명하게 남는다.
const TANK_RECT := Rect2(60, 45, 600, 450)
const MAX_FISH := 5

# 픽셀 아트 한 칸이 차지하는 게임 픽셀. 유리·모래 이미지를 이 배율로 표시한다.
const PIXEL_SCALE := 2

# 유리·모래 이미지(assets/tank/)에 맞춘 값. 이미지를 바꾸면 함께 고친다.
const GLASS_WIDTH := 12  # 유리 두께 6칸
const CORNER_RADIUS := 56  # 바깥 모서리 반경 28칸
const SAND_HEIGHT := 22  # 가운데 구간 모래의 가장 높은 곳 11칸. 양 끝은 둥근 모서리 안에 있다.
const SWIM_CORNER_RADIUS := CORNER_RADIUS - GLASS_WIDTH  # 헤엄 영역(swim_area) 모서리 반경

# 물은 코드로 그린다. 위·가운데·아래 세 색 사이를 WATER_STEP마다 조금씩 바꿔
# 층 경계가 보이지 않게 하면서도 픽셀 격자(2칸 단위)에 맞춘다.
const WATER_COLORS: Array[Color] = [Color("d3eff4"), Color("bee6ee"), Color("aadce7")]
const WATER_STEP := 4
# 물 가장자리를 유리 안쪽 선이 아니라 유리 띠 중간에 두어, 계단 모양 모서리 사이로 틈이 보이지 않게 한다.
const WATER_INSET := 6

@export var fish_scene: PackedScene

var fish_count := 0

@onready var sand: Sprite2D = $Sand
@onready var fishes: Node2D = $Fishes
@onready var glass: Sprite2D = $Glass


func _ready() -> void:
	# 유리·모래 이미지는 캔버스 전체가 어항 외곽(300×225칸)이다.
	for layer: Sprite2D in [sand, glass]:
		layer.position = TANK_RECT.position
		layer.scale = Vector2.ONE * PIXEL_SCALE
	add_fish()


# 물고기가 헤엄칠 수 있는 영역: 유리 안쪽에서 바닥 모래 높이를 뺀 곳. 모서리는 SWIM_CORNER_RADIUS로 둥글다.
static func swim_area() -> Rect2:
	var area := TANK_RECT.grow(-GLASS_WIDTH)
	area.size.y -= SAND_HEIGHT
	return area


# 생성 경로를 한곳으로 모아 버튼 이외의 호출에서도 최대 마릿수를 지킨다.
func add_fish() -> bool:
	if fish_count >= MAX_FISH:
		return false

	var fish := fish_scene.instantiate() as Node2D
	# _ready()에서 목적지를 고르기 전에 안전한 시작 위치를 설정한다.
	fish.position = TANK_RECT.get_center()
	# 모래(Sand)와 유리(Glass) 사이의 Fishes에 넣어 유리 반사가 물고기 위에 오게 한다.
	fishes.add_child(fish)
	fish_count += 1
	fish_count_changed.emit(fish_count)
	return true


# 물 → Sand → Fishes → Glass 순서로 보인다. 물은 노드 자신이 가장 먼저 그린다.
# 둥근 모서리에 맞춰 한 줄(1 게임 픽셀)씩 폭을 줄여 그린다. 가장자리는 유리 밑에 가려진다.
func _draw() -> void:
	var water := TANK_RECT.grow(-WATER_INSET)
	var radius := float(CORNER_RADIUS - WATER_INSET)
	for y in range(int(water.position.y), int(water.end.y)):
		var row := y + 0.5
		var dy := maxf(water.position.y + radius - row, row - (water.end.y - radius))
		var inset_x := 0.0
		if dy > 0.0:
			inset_x = radius - sqrt(maxf(radius * radius - dy * dy, 0.0))
		var line := Rect2(water.position.x + inset_x, y, water.size.x - inset_x * 2.0, 1)
		draw_rect(line, _water_color(y - TANK_RECT.position.y))


# 어항 위쪽에서 depth만큼 내려간 줄의 물 색. WATER_STEP 단위로 끊어 계단처럼 바뀐다.
func _water_color(depth: float) -> Color:
	var t := floorf(depth / WATER_STEP) * WATER_STEP / TANK_RECT.size.y
	if t < 0.5:
		return WATER_COLORS[0].lerp(WATER_COLORS[1], t / 0.5)
	return WATER_COLORS[1].lerp(WATER_COLORS[2], (t - 0.5) / 0.5)
