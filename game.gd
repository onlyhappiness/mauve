extends Node

# Autoload `Game`. 진주·보유 물고기·메뉴 설정을 가지고, 바뀔 때마다 저장하고 시그널로 알린다.
# 장면(Screen·ShopPanel)은 여기 함수를 불러 바꾸고, 시그널을 받아 화면에 그리기만 한다.
# 사고팔 수 있는지(가격·마지막 한 마리 등)는 부르는 쪽이 확인하고, 여기서는 최대 마릿수만 지킨다.

signal pearls_changed(pearls: int)
signal fish_added(index: int)
signal fish_removed(index: int)
signal screen_setting_changed(key: String, value: bool)
signal about_to_save  # 장면이 저장 직전에 물고기 위치 등을 fish에 적어 넣는다

const MAX_FISH := 5

var pearls := 0
var fish: Array = []  # [{"kind", "x", "y"}]. 화면의 Fish 노드와 같은 순서
var screen_settings: Dictionary = {}  # "always_on_top", "fish_visible"


func _ready() -> void:
	load_saved()


# Cmd+Q 등으로 창을 닫을 때도 저장한다.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()


# 저장 파일을 다시 읽는다. 물고기가 하나도 없으면 시작 물고기 한 마리를 넣는다.
func load_saved() -> void:
	var data := SaveData.load_data()
	pearls = data["pearls"]
	fish = data["fish"]
	screen_settings = data["screen"]
	if fish.is_empty():
		fish.append({"kind": Catalog.START_FISH, "x": 0.0, "y": 0.0})


func fish_count() -> int:
	return fish.size()


func count_fish(kind: String) -> int:
	return fish.filter(func(item: Dictionary) -> bool: return item["kind"] == kind).size()


func add_pearls(amount: int) -> void:
	pearls += amount
	pearls_changed.emit(pearls)
	save()


func spend_pearls(amount: int) -> bool:
	if pearls < amount:
		return false
	add_pearls(-amount)
	return true


# 추가 경로를 한곳으로 모아 최대 마릿수를 지킨다.
func add_fish(kind: String) -> bool:
	if fish.size() >= MAX_FISH or not Catalog.is_fish_ready(kind):
		return false
	fish.append({"kind": kind, "x": 0.0, "y": 0.0})
	fish_added.emit(fish.size() - 1)
	save()
	return true


# 그 종류 중 가장 나중에 넣은 물고기를 뺀다.
func remove_fish(kind: String) -> bool:
	for i in range(fish.size() - 1, -1, -1):
		if fish[i]["kind"] == kind:
			fish.remove_at(i)
			fish_removed.emit(i)
			save()
			return true
	return false


func set_screen_setting(key: String, value: bool) -> void:
	screen_settings[key] = value
	screen_setting_changed.emit(key, value)
	save()


func save() -> void:
	about_to_save.emit()
	SaveData.save({"version": SaveData.VERSION, "pearls": pearls, "screen": screen_settings, "fish": fish})
