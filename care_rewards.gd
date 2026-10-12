class_name CareRewards
extends RefCounted

# 먹이 주기 보상 기회. 30분마다 1회 생기고 최대 3회까지 쌓인다(앱을 꺼 둔 동안 포함).
# 진주는 자동으로 주지 않고, 기회가 있을 때 먹이를 주면 먹는 행동이 끝난 뒤 개체별 보상을 합쳐 준다.
# 시각은 Unix 초로 받는다. 점검에서 시각을 바꿔 넣을 수 있도록 now를 인자로 받는다.

const INTERVAL := 30 * 60  # 기회 하나가 생기는 데 걸리는 시간(초)
const MAX_CHANCES := 3
const START_CHANCES := 1  # 새로 시작할 때
# 개체당 먹이 주기 1회 보상(진주). 값은 PRD.md 「수중 생물 목록과 가격·보상」을 따른다.
const REWARDS := {"goldfish": 8}

var chances := START_CHANCES
var since := 0  # 다음 기회를 세기 시작한 시각. 기회가 가득 찬 동안은 세지 않는다.


static func now() -> int:
	return int(Time.get_unix_time_from_system())


# 지난 시간만큼 기회를 채운다. 시스템 시각이 since보다 과거로 돌아갔으면 기준을 지금으로 다시 잡는다
# (그동안 센 시간은 잃지만 기회 자체는 잃지 않는다).
func update(time: int) -> void:
	if time < since:
		since = time
	if chances >= MAX_CHANCES:
		chances = MAX_CHANCES
		since = time
		return
	var gained := (time - since) / INTERVAL
	if gained <= 0:
		return
	chances = mini(chances + gained, MAX_CHANCES)
	since = time if chances == MAX_CHANCES else since + gained * INTERVAL


# 기회를 하나 쓴다. 없으면 false.
func use(time: int) -> bool:
	update(time)
	if chances == 0:
		return false
	chances -= 1
	return true


# 다음 기회까지 남은 초. 가득 찼으면 0.
func seconds_left(time: int) -> int:
	update(time)
	return 0 if chances >= MAX_CHANCES else INTERVAL - (time - since)


static func reward_for(fish_states: Array) -> int:
	var total := 0
	for fish: Dictionary in fish_states:
		total += REWARDS.get(fish["kind"], 0)
	return total


func to_dict() -> Dictionary:
	return {"chances": chances, "since": since}


# 저장 값이 없거나 이상하면 새로 시작한 것처럼 기회 1회, 지금부터 센다.
static func from_dict(data: Variant, time: int) -> CareRewards:
	var care := CareRewards.new()
	care.since = time
	if data is Dictionary and data.get("chances") is float and data.get("since") is float:
		care.chances = clampi(int(data["chances"]), 0, MAX_CHANCES)
		care.since = int(data["since"])
	care.update(time)
	return care
