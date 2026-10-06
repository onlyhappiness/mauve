extends Node2D

# 꼬리를 포함한 최대 크기. 원점(0, 0)이 물고기의 중심이고 오른쪽을 바라본다.
# 이미지는 이 크기 안에 맞춰 표시하고, 어항 이탈 검사도 이 크기를 기준으로 한다.
const SIZE := Vector2(90, 55)

# 헤엄 설정. 길이는 픽셀, 시간은 초 단위.
const SPEED_MIN := 35.0
const SPEED_MAX := 65.0
const SLOW_DOWN_DISTANCE := 40.0  # 목적지에 이만큼 가까워지면 서서히 느려진다
const MIN_TRAVEL := 80.0  # 너무 가까운 목적지는 고르지 않는다
const MAX_RISE := 90.0  # 한 번에 위아래로 움직이는 최대 거리
const REST_CHANCE := 0.35
const REST_TIME_MIN := 1.0
const REST_TIME_MAX := 3.0
const TURN_SPEED := 5.0  # 방향을 바꿀 때 Visual.scale.x가 1초에 변하는 양
const EDGE_MARGIN := 4.0  # 유리·모래에 딱 붙지 않게 두는 여유

# 개체마다 따로 갖는 이동 상태
var target := Vector2.ZERO
var speed := 0.0
var rest_left := 0.0
var facing := 1.0  # 1이면 오른쪽, -1이면 왼쪽

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite2D


func _ready() -> void:
	_fit_sprite_to_size()
	_pick_target()


# 이미지 해상도와 상관없이 비율을 지키며 SIZE 안에 들어가도록 표시 크기를 맞춘다.
func _fit_sprite_to_size() -> void:
	var texture_size := sprite.texture.get_size()
	var fit := minf(SIZE.x / texture_size.x, SIZE.y / texture_size.y)
	sprite.scale = Vector2(fit, fit)


func _process(delta: float) -> void:
	if rest_left > 0.0:
		rest_left -= delta
		if rest_left <= 0.0:
			_pick_target()
	else:
		_swim(delta)

	# Visual.scale.x가 1과 -1 사이를 천천히 오가며 몸을 돌리는 것처럼 보이게 한다.
	# 정확히 0이 되면 변환을 되돌릴 수 없으므로 0은 건너뛴다.
	var next_scale := move_toward(visual.scale.x, facing, TURN_SPEED * delta)
	if is_zero_approx(next_scale):
		next_scale = facing * 0.01
	visual.scale.x = next_scale


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


# 유리 안쪽·모래 위의 헤엄 영역에서 여유만큼 줄인 곳
func _water_rect() -> Rect2:
	return Aquarium.swim_area().grow(-EDGE_MARGIN)


# 물고기 중심이 point일 때 몸 전체가 둥근 모서리까지 포함한 물 영역 안에 들어가는지 확인한다.
# 물 영역은 볼록한 모양이라, 들어가는 두 지점 사이를 직선으로 헤엄쳐도 밖으로 나가지 않는다.
func _fits_in_water(point: Vector2) -> bool:
	var water := _water_rect()
	var body := Rect2(point - SIZE / 2, SIZE)
	if not water.encloses(body):
		return false

	# 둥근 모서리 원의 중심들이 이루는 사각형에서 radius 이내인 점만 물 영역이다.
	var radius := Aquarium.SWIM_CORNER_RADIUS - EDGE_MARGIN
	var centers := water.grow(-radius)
	var corners := [body.position, Vector2(body.end.x, body.position.y), body.end, Vector2(body.position.x, body.end.y)]
	for corner: Vector2 in corners:
		if corner.distance_to(corner.clamp(centers.position, centers.end)) > radius:
			return false
	return true

