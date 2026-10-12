class_name Aquarium
extends Node2D

signal fish_count_changed(count: int)
signal feeding_finished  # 먹이를 모두 먹었거나 FEEDING_TIMEOUT이 지났다

# 어항이 차지하는 영역(창 기준 논리 픽셀). 이 바깥은 투명하게 남는다.
const TANK_RECT := Rect2(60, 45, 680, 510)
const MAX_FISH := 5

# 픽셀 아트 한 칸이 차지하는 게임 픽셀. 유리·모래 이미지를 이 배율로 표시한다.
const PIXEL_SCALE := 2

# 유리·모래 이미지(assets/tank/)에 맞춘 값. 이미지를 바꾸면 함께 고친다.
const GLASS_WIDTH := 12  # 유리 두께 6칸
const CORNER_RADIUS := 56  # 바깥 모서리 반경 28칸
const SAND_HEIGHT := 26  # 가운데 구간 모래의 가장 높은 곳 13칸. 양 끝은 둥근 모서리 안에 있다.
const SWIM_CORNER_RADIUS := CORNER_RADIUS - GLASS_WIDTH  # 헤엄 영역(swim_area) 모서리 반경

# 물은 코드로 그린다. 위·가운데·아래 세 색 사이를 WATER_STEP마다 조금씩 바꿔
# 층 경계가 보이지 않게 하면서도 픽셀 격자(2칸 단위)에 맞춘다.
const WATER_COLORS: Array[Color] = [Color("d3eff4"), Color("bee6ee"), Color("aadce7")]
const WATER_STEP := 4
# 물 가장자리를 유리 안쪽 선이 아니라 유리 띠 중간에 두어, 계단 모양 모서리 사이로 틈이 보이지 않게 한다.
const WATER_INSET := 6

const FEEDING_TIMEOUT := 20.0  # 이 시간이 지나면 남은 먹이를 치우고 먹기를 끝낸다

@export var fish_scene: PackedScene

var fish_count := 0
var feeding := false
var _feeding_round := 0  # 지난 먹이 주기의 시간 초과 타이머가 새 먹이 주기를 끝내지 않게 구분한다

@onready var sand: Sprite2D = $Sand
@onready var foods: Node2D = $Foods
@onready var fishes: Node2D = $Fishes
@onready var glass: Sprite2D = $Glass


func _ready() -> void:
	# 유리·모래 이미지는 캔버스 전체가 어항 외곽(340×255칸)이다.
	for layer: Sprite2D in [sand, glass]:
		layer.position = TANK_RECT.position
		layer.scale = Vector2.ONE * PIXEL_SCALE


# 물고기가 헤엄칠 수 있는 영역: 유리 안쪽에서 바닥 모래 높이를 뺀 곳. 모서리는 SWIM_CORNER_RADIUS로 둥글다.
static func swim_area() -> Rect2:
	var area := TANK_RECT.grow(-GLASS_WIDTH)
	area.size.y -= SAND_HEIGHT
	return area


# 생성 경로를 한곳으로 모아 버튼 이외의 호출에서도 최대 마릿수를 지킨다.
# start가 헤엄 영역 밖이면(기본값 포함) 어항 가운데에서 시작한다.
func add_fish(start := Vector2.ZERO) -> bool:
	if fish_count >= MAX_FISH:
		return false

	var fish := fish_scene.instantiate() as Node2D
	# _ready()에서 목적지를 고르기 전에 안전한 시작 위치를 설정한다.
	fish.position = start if fish._fits_in_water(start) else TANK_RECT.get_center()
	# 모래(Sand)와 유리(Glass) 사이의 Fishes에 넣어 유리 반사가 물고기 위에 오게 한다.
	fishes.add_child(fish)
	fish_count += 1
	fish_count_changed.emit(fish_count)
	return true


# 가장 나중에 넣은 물고기를 뺀다. 마지막 한 마리를 남기는 규칙은 상점(ShopPanel)이 지킨다.
func remove_fish() -> bool:
	if fish_count == 0:
		return false

	var fish := fishes.get_child(fishes.get_child_count() - 1) as Fish
	if fish.food != null:  # 맡은 먹이를 먹을 물고기가 없으니 함께 치운다
		fish.food.queue_free()
	# queue_free()만 하면 이번 프레임의 저장(fish_states)에 남으므로 먼저 떼어 낸다.
	fishes.remove_child(fish)
	fish.queue_free()
	fish_count -= 1
	fish_count_changed.emit(fish_count)
	return true


# 물고기마다 먹이 알갱이를 하나씩 물 위쪽에 떨어뜨린다. 이미 먹는 중이거나 물고기가 없으면 false.
# 알갱이는 둥근 모서리에 걸리지 않는 가운데 구간에, 물고기 입이 닿는 높이까지만 가라앉는다.
func feed() -> bool:
	if feeding or fish_count == 0:
		return false
	feeding = true
	_feeding_round += 1
	var area := swim_area().grow(-Fish.EDGE_MARGIN)
	var half := Fish.SIZE / 2
	var x_min := area.position.x + half.x + SWIM_CORNER_RADIUS
	var x_max := area.end.x - half.x - SWIM_CORNER_RADIUS
	for fish: Fish in fishes.get_children():
		var food := Food.new()
		food.position = Vector2(randf_range(x_min, x_max), area.position.y + half.y + randf_range(0.0, 30.0)).floor()
		food.floor_y = area.end.y - half.y - 1.0
		food.tree_exited.connect(_check_foods.call_deferred)
		foods.add_child(food)
		fish.food = food
	get_tree().create_timer(FEEDING_TIMEOUT).timeout.connect(_end_feeding.bind(_feeding_round))
	return true


func _check_foods() -> void:
	if feeding and foods.get_child_count() == 0:
		_end_feeding(_feeding_round)


func _end_feeding(feeding_round: int) -> void:
	if not feeding or feeding_round != _feeding_round:
		return
	feeding = false
	for food in foods.get_children():
		food.queue_free()
	feeding_finished.emit()


# 저장용 물고기 목록. 지금은 금붕어 한 종류뿐이다.
func fish_states() -> Array:
	var states := []
	for fish: Node2D in fishes.get_children():
		states.append({"kind": "goldfish", "x": fish.position.x, "y": fish.position.y})
	return states


# 물 → Sand → Foods → Fishes → Glass 순서로 보인다. 물은 노드 자신이 가장 먼저 그린다.
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
