#!/usr/bin/env python3
"""Generates the player's alternate armor skins.

Reads the original sheets (assets/sprites/knight.png and flutterfall.png, never
modified) and writes recoloured, re-detailed copies with the exact same frame
layout to assets/sprites/valkyrie/skins/<id>.png and <id>_flutter.png, so the
player can swap the atlas texture without touching her animations.

Every pixel of the original is sorted into a role (outline, armor light/dark/
highlight, plume, trim, cloak, visor slit, wing), and each skin paints the roles
its own way. On upright frames some skins add small details: a blonde braid,
horns, a leaf sprig.

Run from the project root:  python3 tools/gen_player_skins.py
Needs Pillow. Writes only into assets/sprites/valkyrie/skins/.
"""
from __future__ import annotations

import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC_KNIGHT = os.path.join(ROOT, "assets", "sprites", "knight.png")
SRC_FLUTTER = os.path.join(ROOT, "assets", "sprites", "flutterfall.png")
OUT = os.path.join(ROOT, "assets", "sprites", "valkyrie", "skins")
CELL = 32

# The original knight palette, by role.
ROLES = {
	"O": (14, 13, 14),     # outline
	"L": (179, 170, 161),  # armor
	"D": (124, 119, 111),  # armor shade
	"H": (234, 223, 209),  # armor highlight
	"R": (210, 32, 44),    # plume
	"G": (235, 167, 36),   # trim
	"T": (10, 112, 48),    # cloak
}

# Each skin: colours per role (missing roles keep the original), plus
#   plume: list of colours top -> bottom (a gradient down the plume)
#   slit: visor slit colour (None = outline)
#   wing: (light, shade) for the flutter wings
#   extra: details added on upright frames
SKINS = {
	"shieldmaiden": {
		"L": (196, 206, 222), "D": (110, 122, 150), "H": (242, 248, 255),
		"G": (244, 196, 72), "T": (48, 104, 186), "O": (18, 18, 30),
		"plume": [(255, 236, 150), (246, 210, 104), (214, 164, 64)],
		"slit": (40, 54, 92),
		"wing": ((250, 252, 255), (170, 184, 210)),
		"extra": "braid",
	},
	"hel_forged": {
		"L": (92, 84, 96), "D": (54, 46, 60), "H": (140, 126, 136),
		"G": (255, 112, 40), "T": (122, 20, 34), "O": (10, 6, 10),
		"plume": [(255, 240, 150), (255, 170, 50), (232, 84, 30), (160, 34, 26)],
		"slit": (255, 96, 40),
		"wing": ((176, 164, 164), (92, 82, 86)),
		"extra": "horns",
	},
	"rootwarden": {
		"L": (186, 144, 92), "D": (122, 86, 54), "H": (232, 202, 146),
		"G": (150, 204, 92), "T": (52, 84, 42), "O": (20, 14, 10),
		"plume": [(170, 228, 110), (108, 186, 76), (56, 128, 60)],
		"slit": (30, 48, 26),
		"wing": ((226, 240, 206), (138, 166, 116)),
		"extra": "sprig",
	},
	"einherjar": {
		"L": (240, 198, 92), "D": (178, 122, 46), "H": (255, 244, 186),
		"G": (110, 200, 255), "T": (94, 46, 146), "O": (28, 16, 10),
		"plume": [(255, 255, 255), (236, 238, 248), (196, 202, 226)],
		"slit": (120, 64, 24),
		"wing": ((255, 248, 220), (214, 186, 120)),
		"extra": None,
	},
}


def classify(px, x, y, w, h) -> str | None:
	"""Role of a pixel, or None to leave it alone (shadows, labels)."""
	r, g, b, a = px[x, y]
	if a < 40:
		return None
	if r + g + b < 30 and a < 255:
		return None  # soft drop shadow
	if r + g + b < 6:
		return None  # pure black: sheet labels
	warm = r - b
	if r + g + b > 330 and abs(warm) <= 6:
		return "W"  # wing feather, light
	if 300 < r + g + b <= 330 and abs(warm) <= 4:
		return "w"
	if 330 >= r + g + b > 260 and abs(warm) <= 4 and abs(r - g) <= 4:
		return "w"  # wing feather, shade
	best, dist = None, 1e9
	for role, (cr, cg, cb) in ROLES.items():
		d = (r - cr) ** 2 + (g - cg) ** 2 + (b - cb) ** 2
		if d < dist:
			best, dist = role, d
	if best == "O":
		# visor slit: an outline pixel walled in by armor left and right
		def role_at(xx):
			if 0 <= xx < w:
				c = px[xx, y]
				if c[3] > 40:
					return min(ROLES, key=lambda k: sum((c[i] - ROLES[k][i]) ** 2 for i in range(3)))
			return None
		if role_at(x - 1) in ("L", "H") and role_at(x + 1) in ("L", "H"):
			return "S"
	return best


def paint(src: Image.Image, skin: dict) -> Image.Image:
	src = src.convert("RGBA")
	out = src.copy()
	sp = src.load()
	op = out.load()
	W, H = src.size
	roles = [[None] * H for _ in range(W)]
	for y in range(H):
		for x in range(W):
			roles[x][y] = classify(sp, x, y, W, H)
	for cy in range(0, H, CELL):
		for cx in range(0, W, CELL):
			plume = [(x, y) for y in range(cy, cy + CELL) for x in range(cx, cx + CELL) if roles[x][y] == "R"]
			py0 = min((p[1] for p in plume), default=0)
			py1 = max((p[1] for p in plume), default=0)
			for y in range(cy, cy + CELL):
				for x in range(cx, cx + CELL):
					role = roles[x][y]
					if role is None:
						continue
					a = sp[x, y][3]
					if role == "R":
						grad = skin["plume"]
						t = (y - py0) / max(1, py1 - py0)
						col = grad[min(len(grad) - 1, int(t * len(grad)))]
					elif role == "S":
						col = skin["slit"] or skin.get("O", ROLES["O"])
					elif role == "W":
						col = skin["wing"][0]
					elif role == "w":
						col = skin["wing"][1]
					else:
						col = skin.get(role, ROLES[role])
					op[x, y] = (*col, a)
			if skin["extra"] and plume:
				_extra(op, roles, cx, cy, plume, skin)
	return out


def _put(op, x, y, col, cx, cy):
	if cx <= x < cx + CELL and cy <= y < cy + CELL:
		op[x, y] = (*col, 255)


def _empty(op, x, y, cx, cy) -> bool:
	return cx <= x < cx + CELL and cy <= y < cy + CELL and op[x, y][3] < 40


def _extra(op, roles, cx, cy, plume, skin):
	"""Small details on upright frames (plume above the helmet)."""
	helm = [(x, y) for y in range(cy, cy + CELL) for x in range(cx, cx + CELL) if roles[x][y] in ("H", "L", "D", "S")]
	if not helm:
		return
	hy0 = min(p[1] for p in helm)
	if sum(p[1] for p in plume) / len(plume) >= hy0:
		return  # rolling / upside down: leave it
	outline = skin.get("O", ROLES["O"])
	px0 = min(p[0] for p in plume)
	py1 = max(p[1] for p in plume)
	hx1 = max(p[0] for p in helm if p[1] <= hy0 + 2)
	kind = skin["extra"]
	if kind == "braid":
		# a blonde braid hanging down behind her helmet
		hair, shade = skin["plume"][1], skin["plume"][2]
		bx = px0
		for k in range(1, 6):
			y = py1 + k
			col = hair if k % 2 else shade
			if _empty(op, bx, y, cx, cy) or roles[bx][y] in ("O",):
				_put(op, bx, y, col, cx, cy)
				if _empty(op, bx - 1, y, cx, cy):
					_put(op, bx - 1, y, outline, cx, cy)
		_put(op, bx, py1 + 6, outline, cx, cy)
		_put(op, bx, py1 + 5, (244, 196, 72), cx, cy)  # gold band
	elif kind == "horns":
		# two short bone horns curving up off the helmet's front
		bone, bone_sh = (226, 214, 186), (150, 136, 112)
		for (dx, dy, col) in ((-1, -1, bone_sh), (-1, -2, bone), (0, -3, bone), (-4, -1, bone_sh), (-5, -2, bone), (-5, -3, bone)):
			x, y = hx1 + dx, hy0 + dy
			if _empty(op, x, y, cx, cy):
				_put(op, x, y, col, cx, cy)
		for (dx, dy) in ((0, -1), (0, -2), (1, -3), (0, -4), (-1, -3), (-4, -3), (-6, -2), (-6, -3), (-5, -4), (-4, -2)):
			x, y = hx1 + dx, hy0 + dy
			if _empty(op, x, y, cx, cy):
				_put(op, x, y, outline, cx, cy)
	elif kind == "sprig":
		# a sprouting leaf at the helmet's front
		leaf, leaf_sh = skin["plume"][0], skin["plume"][2]
		x, y = hx1, hy0 - 1
		for (dx, dy, col) in ((0, 0, leaf_sh), (1, -1, leaf), (2, -1, leaf), (1, -2, leaf)):
			if _empty(op, x + dx, y + dy, cx, cy):
				_put(op, x + dx, y + dy, col, cx, cy)
		for (dx, dy) in ((1, 0), (2, 0), (3, -1), (2, -2), (1, -3), (0, -2), (0, -1)):
			if _empty(op, x + dx, y + dy, cx, cy):
				_put(op, x + dx, y + dy, outline, cx, cy)


def main() -> None:
	os.makedirs(OUT, exist_ok=True)
	knight = Image.open(SRC_KNIGHT)
	flutter = Image.open(SRC_FLUTTER)
	for sid, skin in SKINS.items():
		for src, suffix in ((knight, ""), (flutter, "_flutter")):
			path = os.path.join(OUT, sid + suffix + ".png")
			paint(src, skin).save(path)
			print("wrote", os.path.relpath(path, ROOT))


if __name__ == "__main__":
	main()
