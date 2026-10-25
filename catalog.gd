class_name Catalog
extends RefCounted

# 물고기 종류 데이터를 한곳에 모은다. 상점·저장·장면이 모두 여기서 읽는다.
# 종류 id를 키로 쓰고, 상점에 보이는 순서는 사전에 적은 순서를 따른다.
# texture가 null이면 아직 에셋이 없어 상점에 「준비 중」으로 보이고 살 수 없다.
# 가격·순서는 PRD.md의 「수중 생물 목록과 가격·보상」을 따르고, 판매가는 구매가의 절반(내림)이다.

const FISH: Dictionary[String, Dictionary] = {
	"goldfish": {"name": "금붕어", "price": 120, "texture": preload("res://assets/fish/goldfish.png"),
		"description": "잘 먹고 잘 크는 어항의 터줏대감."},
	"puffer": {"name": "미니 복어", "price": 80, "texture": null, "description": "깜짝 놀라면 동그랗게 부풀어요."},
	"jellyfish": {"name": "해파리", "price": 160, "texture": null, "description": "물결을 따라 느긋하게 떠다녀요."},
	"axolotl": {"name": "우파루파", "price": 240, "texture": null, "description": "늘 웃는 얼굴로 바닥을 거닐어요."},
}
const START_FISH := "goldfish"  # 새로 시작하거나 물고기가 하나도 없을 때 넣는 종류


# 에셋이 있어 어항에 넣을 수 있는 종류인지. 저장 파일 검사도 이 기준을 쓴다.
static func is_fish_ready(kind: String) -> bool:
	return FISH.has(kind) and FISH[kind]["texture"] != null
