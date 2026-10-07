class_name SaveData
extends RefCounted

# 물고기 목록·창 위치·항상 위 설정을 JSON 파일 하나에 저장하고 불러온다.
# 저장 형식(VERSION 1):
# {"version": 1, "always_on_top": false, "window": {"x": 0, "y": 0}, "fish": [{"kind": "goldfish", "x": 360, "y": 270}]}
# "window"가 없으면 창을 기본 위치(화면 오른쪽 아래)에 둔다.

const VERSION := 1
const FILE_NAME := "save.json"
const BACKUP_NAME := "save.bak.json"  # 직전에 정상이던 파일
const TEMP_NAME := "save.tmp.json"  # 다 쓴 뒤 FILE_NAME으로 바꾼다
const FISH_KINDS: Array[String] = ["goldfish"]

# 저장 폴더. 헤드리스 점검에서만 다른 폴더로 바꾼다.
static var folder := "user://"


# 처음 실행하거나 저장 파일을 쓸 수 없을 때의 상태
static func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"always_on_top": false,
		"window": null,
		"fish": [{"kind": FISH_KINDS[0], "x": 0.0, "y": 0.0}],  # 위치 (0, 0)은 어항 밖이라 가운데에서 시작한다
	}


# 본 파일 → 백업 → 기본값 순서로 읽는다. 읽을 수 없는 본 파일은 지우지 않고 이름을 바꿔 남긴다.
static func load_data() -> Dictionary:
	var path := folder.path_join(FILE_NAME)
	if FileAccess.file_exists(path):
		var data = _read(path)
		if data != null:
			return data
		var kept := folder.path_join("save.corrupt-%s.json" % Time.get_datetime_string_from_system().replace(":", "-"))
		DirAccess.rename_absolute(path, kept)
		push_warning("저장 파일을 읽을 수 없어 %s로 옮겼습니다." % kept)

	var backup := folder.path_join(BACKUP_NAME)
	if FileAccess.file_exists(backup):
		var data = _read(backup)
		if data != null:
			push_warning("백업 파일에서 불러왔습니다.")
			return data
		push_warning("백업 파일도 읽을 수 없어 기본값으로 시작합니다.")
	return defaults()


# 임시 파일에 다 쓴 뒤 본 파일과 바꿔치기해서, 쓰는 도중 꺼져도 기존 파일이 깨지지 않게 한다.
static func save(data: Dictionary) -> bool:
	var path := folder.path_join(FILE_NAME)
	var temp := folder.path_join(TEMP_NAME)
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		push_warning("저장 실패: %s" % error_string(FileAccess.get_open_error()))
		return false
	data["version"] = VERSION
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if file.get_error() != OK:
		push_warning("저장 실패: %s" % error_string(file.get_error()))
		return false

	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, folder.path_join(BACKUP_NAME))
	var error := DirAccess.rename_absolute(temp, path)
	if error != OK:
		push_warning("저장 실패: %s" % error_string(error))
		return false
	return true


# JSON 형식이 아니거나 최상위 구조가 다르면 null. 항목 하나만 이상하면 그 항목만 기본값으로 바꾼다.
static func _read(path: String) -> Variant:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	var parsed = json.data
	if not (parsed is Dictionary) or not (parsed.get("version") is float) or not (parsed.get("fish") is Array):
		return null

	var data := defaults()
	if parsed.get("always_on_top") is bool:
		data["always_on_top"] = parsed["always_on_top"]

	var window = parsed.get("window")
	if window is Dictionary and window.get("x") is float and window.get("y") is float:
		data["window"] = {"x": int(window["x"]), "y": int(window["y"])}

	var fish: Array = []
	for item in parsed["fish"]:
		if fish.size() >= Aquarium.MAX_FISH:
			break
		if item is Dictionary and item.get("kind") in FISH_KINDS:
			# 위치가 없거나 어항 밖이면 Aquarium.add_fish()가 가운데에 둔다.
			var x = item.get("x")
			var y = item.get("y")
			fish.append({"kind": item["kind"], "x": x if x is float else 0.0, "y": y if y is float else 0.0})
	data["fish"] = fish
	return data
