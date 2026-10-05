extends Node2D

# 꼬리를 포함한 전체 크기. 원점(0, 0)이 물고기의 중심이고 오른쪽을 바라본다.
const SIZE := Vector2(72, 44)

const BODY_COLOR := Color("ffb38a")  # 살구색 몸통
const TAIL_COLOR := Color("f59a72")  # 조금 진한 꼬리
const EYE_COLOR := Color("3d2c2e")
const EYE_HIGHLIGHT_COLOR := Color.WHITE

const BODY_CENTER := Vector2(9, 0)
const BODY_RADIUS := Vector2(27, 22)  # 몸통 가로 54, 세로 44

# 헤엄 설정. 길이는 픽셀, 시간은 초 단위.
const SPEED_MIN := 35.0
const SPEED_MAX := 65.0
const SLOW_DOWN_DISTANCE := 40.0  # 목적지에 이만큼 가까워지면 서서히 느려진다
const MIN_TRAVEL := 80.0  # 너무 가까운 목적지는 고르지 않는다
const MAX_RISE := 90.0  # 한 번에 위아래로 움직이는 최대 거리
const REST_CHANCE := 0.35
const REST_TIME_MIN := 1.0
const REST_TIME_MAX := 3.0
const TURN_SPEED := 5.0  # 방향을 바꿀 때 scale.x가 1초에 변하는 양
const EDGE_MARGIN := 4.0  # 테두리에 딱 붙지 않게 두는 여유

# 개체마다 따로 갖는 이동 상태
var target := Vector2.ZERO
var speed := 0.0
var rest_left := 0.0
var facing := 1.0  # 1이면 오른쪽, -1이면 왼쪽


func _ready() -> void:
	_pick_target()


func _process(delta: float) -> void:
	if rest_left > 0.0:
		rest_left -= delta
		if rest_left <= 0.0:
			_pick_target()
	else:
		_swim(delta)

	# scale.x가 1과 -1 사이를 천천히 오가며 몸을 돌리는 것처럼 보이게 한다.
	# 정확히 0이 되면 변환을 되돌릴 수 없으므로 0은 건너뛴다.
	var next_scale := move_toward(scale.x, facing, TURN_SPEED * delta)
	if is_zero_approx(next_scale):
		next_scale = facing * 0.01
	scale.x = next_scale


func _swim(delta: float) -> void:
	var distance := position.distance_to(target)
	var slow := clampf(distance / SLOW_DOWN_DISTANCE, 0.25, 1.0)
	position = position.move_toward(target, speed * slow * delta)

	if position.distance_to(target) < 1.0:
		if randf() < REST_CHANCE:
			rest_left = randf_range(REST_TIME_MIN, REST_TIME_MAX)
		else:
			_pick_target()


func _pick_target() -> void:
	# 후보가 모두 탈락하면 현재 위치에 머문다.
	target = position
	var water := _water_rect()
	var half := SIZE / 2
	# 위아래 이동은 현재 높이에서 MAX_RISE 이내로 제한해 수평에 가깝게 헤엄치게 한다.
	var y_min := maxf(water.position.y + half.y, position.y - MAX_RISE)
	var y_max := minf(water.end.y - half.y, position.y + MAX_RISE)
	# 조건에 맞는 목적지를 몇 번 뽑아 본다. 모두 실패하면 제자리에서 다시 고른다.
	for i in 10:
		var candidate := Vector2(
			randf_range(water.position.x + half.x, water.end.x - half.x),
			randf_range(y_min, y_max)
		)
		if candidate.distance_to(position) >= MIN_TRAVEL and _fits_in_water(candidate):
			target = candidate
			break

	speed = randf_range(SPEED_MIN, SPEED_MAX)
	if absf(target.x - position.x) > 1.0:
		facing = signf(target.x - position.x)


# 테두리 안쪽의 물 영역
func _water_rect() -> Rect2:
	return Aquarium.TANK_RECT.grow(-(Aquarium.BORDER_WIDTH + EDGE_MARGIN))


# 물고기 중심이 point일 때 몸 전체가 둥근 모서리까지 포함한 물 영역 안에 들어가는지 확인한다.
# 물 영역은 볼록한 모양이라, 들어가는 두 지점 사이를 직선으로 헤엄쳐도 밖으로 나가지 않는다.
func _fits_in_water(point: Vector2) -> bool:
	var water := _water_rect()
	var body := Rect2(point - SIZE / 2, SIZE)
	if not water.encloses(body):
		return false

	# 둥근 모서리 원의 중심들이 이루는 사각형에서 radius 이내인 점만 물 영역이다.
	var radius := Aquarium.CORNER_RADIUS - Aquarium.BORDER_WIDTH - EDGE_MARGIN
	var centers := water.grow(-radius)
	var corners := [body.position, Vector2(body.end.x, body.position.y), body.end, Vector2(body.position.x, body.end.y)]
	for corner: Vector2 in corners:
		if corner.distance_to(corner.clamp(centers.position, centers.end)) > radius:
			return false
	return true


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
