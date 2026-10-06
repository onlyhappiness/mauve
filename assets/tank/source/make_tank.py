# 어항 유리·모래 이미지를 300×225칸 픽셀 격자로 다시 그린다 (D05-1).
#
# ChatGPT 원본(glass.png·sand.png)은 한 칸이 금붕어의 약 2배이고 외형이 4:3이 아니어서,
# 원본의 띠 색·순서·반사 위치·모래 윤곽을 따라 금붕어와 같은 격자(한 칸 = 2 게임 픽셀)로 새로 그린다.
#
# 실행: uv run --with pillow python assets/tank/source/make_tank.py
# 결과: assets/tank/glass.png, assets/tank/sand.png (300×225, 게임에서 2배·Nearest로 표시)

import math
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
OUT = HERE.parent

W, H = 300, 225  # 어항 외곽 = 캔버스 전체
RADIUS = 28  # 바깥 모서리 반경(칸)
# 유리 띠 두께(칸, 바깥 → 안쪽). 2026-10-06 사용자 요청으로 원본 비율(2·2·2·2)보다 얇게 했다.
# 외곽선은 금붕어 외곽선과 같은 한 칸이다.
BANDS = [1, 2, 2, 1]
RIM = sum(BANDS)  # 유리 전체 두께(칸). 이 안쪽이 물 영역

# 원본에서 뽑은 유리 띠 색 (바깥 → 안쪽)
RIM_COLORS = [
    (72, 89, 104),  # 외곽선
    (237, 243, 250),  # 밝은 유리
    (186, 205, 219),  # 옅은 파랑
    (77, 93, 107),  # 안쪽 선
]
HIGHLIGHT = (248, 252, 254)

SAND_LIGHT = (251, 209, 179)
SAND_DARK = (203, 146, 135)

# 원본에서 어항 외곽이 차지하는 범위와 유리 안쪽 바닥 y
SRC_BOX = (65, 92, 1384, 995)
SRC_INNER_BOTTOM = 959


def inset(x: float, y: float) -> float:
	"""칸 중심이 둥근 사각형 외곽에서 안쪽으로 얼마나 들어와 있는지(칸). 음수면 바깥."""
	cx = min(max(x, RADIUS), W - RADIUS)
	cy = min(max(y, RADIUS), H - RADIUS)
	if (cx, cy) != (x, y):  # 모서리 영역
		return RADIUS - math.hypot(x - cx, y - cy)
	return min(x, y, W - x, H - y)


def band_at(d: float) -> int:
	edge = 0
	for i, width in enumerate(BANDS):
		edge += width
		if d < edge:
			return i
	return len(BANDS) - 1


def make_glass() -> Image.Image:
	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	px = img.load()
	for y in range(H):
		for x in range(W):
			d = inset(x + 0.5, y + 0.5)
			if 0 <= d < RIM:
				px[x, y] = RIM_COLORS[band_at(d)] + (255,)

	# 왼쪽 위 모서리 안쪽의 짧은 대각선 반사 (2×2 블록 계단)
	for t in range(6):
		bx, by = 16 + 2 * t, 26 - 2 * t
		for dy in range(2):
			for dx in range(2):
				px[bx + dx, by + dy] = HIGHLIGHT + (255,)
	# 오른쪽 벽 안쪽의 짧은 세로 반사
	for y in range(49, 63):
		for x in range(W - RIM - 6, W - RIM - 4):
			px[x, y] = HIGHLIGHT + (255,)
	return img


def column_profile(src: Image.Image) -> tuple[list[float], list[float]]:
	"""원본 모래에서 새 격자의 열마다 모래 높이와 진한 층 높이(칸)를 읽는다."""
	sp = src.load()
	x0, y0, x1, y1 = SRC_BOX
	sx_per_cell = (x1 - x0) / W
	sy_per_cell = (y1 - y0) / H
	tops, darks = [], []
	for x in range(W):
		sx = int(x0 + (x + 0.5) * sx_per_cell)
		top = dark = None
		for sy in range(y0, SRC_INNER_BOTTOM):
			r, g, b, a = sp[sx, sy]
			if a < 128:
				continue
			if top is None:
				top = sy
			if dark is None and r < 230:  # 진한 코랄 층
				dark = sy
		tops.append((SRC_INNER_BOTTOM - top) / sy_per_cell if top is not None else 0.0)
		darks.append((SRC_INNER_BOTTOM - dark) / sy_per_cell if dark is not None else 0.0)
	return tops, darks


def smooth(values: list[float], radius: int) -> list[float]:
	out = []
	for i in range(len(values)):
		window = values[max(0, i - radius): i + radius + 1]
		out.append(sum(window) / len(window))
	return out


def make_sand() -> Image.Image:
	src = Image.open(HERE / "sand.png").convert("RGBA")
	tops, darks = column_profile(src)
	# 원본의 두 칸짜리 계단을 부드럽게 펴서 새 격자에서는 한 칸 계단이 되게 한다.
	tops = smooth(tops, 3)
	darks = smooth(darks, 3)

	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	px = img.load()
	bottom = H - RIM  # 유리 안쪽 바닥(이 행부터 유리)
	for x in range(W):
		top_h = round(tops[x])
		dark_h = round(darks[x])
		for h in range(top_h):
			y = bottom - 1 - h
			if inset(x + 0.5, y + 0.5) < RIM:  # 유리 밖·유리 아래로는 그리지 않는다
				continue
			px[x, y] = (SAND_DARK if h < dark_h else SAND_LIGHT) + (255,)
	return img


if __name__ == "__main__":
	make_glass().save(OUT / "glass.png")
	make_sand().save(OUT / "sand.png")
	print("saved", OUT / "glass.png", OUT / "sand.png")
