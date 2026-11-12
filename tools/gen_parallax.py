#!/usr/bin/env python3
"""Generate the per-realm parallax background layers (pixel art PNGs).

Writes assets/sprites/parallax/<realm>/<layer>.png. Every layer tiles seamlessly
on both axes (the game climbs vertically), is drawn at 1:1 world pixels (16 px
tile grid, no scaling) and keeps to dark, low-contrast palettes so the gameplay
tiles stay readable. Deterministic: same seeds -> same images.

Usage (from the repo root):  python3 tools/gen_parallax.py
Needs numpy and Pillow.
"""
from __future__ import annotations

import math
import os
import sys

import numpy as np
from PIL import Image

W, H = 384, 432  # one tile of every layer; 384 = viewport width at zoom 3
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites", "parallax")

BAYER4 = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16.0


def bayer(w: int, h: int) -> np.ndarray:
	return np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w]


def tnoise(w: int, h: int, cx: int, cy: int, seed: int) -> np.ndarray:
	"""Tileable value noise in [0, 1]; w % cx == 0 and h % cy == 0."""
	rng = np.random.default_rng(seed)
	gw, gh = w // cx, h // cy
	grid = rng.random((gh, gw))
	ys = np.arange(h) / cy
	xs = np.arange(w) / cx
	y0 = np.floor(ys).astype(int)
	x0 = np.floor(xs).astype(int)
	fy = ys - y0
	fx = xs - x0
	fy = fy * fy * (3 - 2 * fy)
	fx = fx * fx * (3 - 2 * fx)
	y1 = (y0 + 1) % gh
	x1 = (x0 + 1) % gw
	y0 %= gh
	x0 %= gw
	a = grid[np.ix_(y0, x0)]
	b = grid[np.ix_(y0, x1)]
	c = grid[np.ix_(y1, x0)]
	d = grid[np.ix_(y1, x1)]
	fx2 = fx[None, :]
	fy2 = fy[:, None]
	return (a * (1 - fx2) + b * fx2) * (1 - fy2) + (c * (1 - fx2) + d * fx2) * fy2


def fbm(w: int, h: int, cx: int, cy: int, seed: int, octaves: int = 3) -> np.ndarray:
	total = np.zeros((h, w))
	amp, norm = 1.0, 0.0
	for o in range(octaves):
		sx, sy = max(cx >> o, 1), max(cy >> o, 1)
		while w % sx:
			sx -= 1
		while h % sy:
			sy -= 1
		total += tnoise(w, h, sx, sy, seed + o * 101) * amp
		norm += amp
		amp *= 0.5
	return total / norm


def blank() -> np.ndarray:
	return np.zeros((H, W, 4), dtype=np.uint8)


def paint(img: np.ndarray, mask: np.ndarray, color: tuple) -> None:
	rgba = color if len(color) == 4 else (*color, 255)
	img[mask] = rgba


def wrap_disc(img: np.ndarray, cx: float, cy: float, r: float, color: tuple) -> None:
	"""Filled circle that wraps around the tile edges."""
	ys, xs = np.ogrid[:H, :W]
	dx = np.minimum(np.abs(xs - cx), W - np.abs(xs - cx))
	dy = np.minimum(np.abs(ys - cy), H - np.abs(ys - cy))
	paint(img, dx * dx + dy * dy <= r * r, color)


def wrap_rect(img: np.ndarray, x: int, y: int, w: int, h: int, color: tuple) -> None:
	rgba = color if len(color) == 4 else (*color, 255)
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			img[yy % H, xx % W] = rgba


def thick_line(img: np.ndarray, x0: float, y0: float, x1: float, y1: float, r0: float, r1: float, color: tuple) -> None:
	steps = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
	for i in range(steps + 1):
		t = i / steps
		x = x0 + (x1 - x0) * t
		y = y0 + (y1 - y0) * t
		r = r0 + (r1 - r0) * t
		ri = int(math.ceil(r))
		for dy in range(-ri, ri + 1):
			for dx in range(-ri, ri + 1):
				if dx * dx + dy * dy <= r * r + 0.3:
					img[int(round(y + dy)) % H, int(round(x + dx)) % W] = (*color, 255)


def edge_below(mask: np.ndarray) -> np.ndarray:
	"""Solid pixels whose lower neighbour is empty (wrapping)."""
	return mask & ~np.roll(mask, -1, axis=0)


def edge_above(mask: np.ndarray) -> np.ndarray:
	return mask & ~np.roll(mask, 1, axis=0)


def edge_side(mask: np.ndarray, dx: int) -> np.ndarray:
	return mask & ~np.roll(mask, -dx, axis=1)


def save(img: np.ndarray, realm: str, name: str) -> None:
	d = os.path.join(OUT, realm)
	os.makedirs(d, exist_ok=True)
	Image.fromarray(img, "RGBA").save(os.path.join(d, name + ".png"))


# ---------------------------------------------------------------- Hel
def lavafall(img: np.ndarray, x: int, y0: int, length: int, w: int, b: np.ndarray) -> None:
	"""Thin falling stream of magma with a hot core and a glowing splash pool."""
	for t in range(length):
		y = (y0 + t) % H
		wob = int(round(math.sin((y0 + t) / 9.0) * 0.6))
		for dx in range(-1, w + 1):
			xx = (x + dx + wob) % W
			if dx < 0 or dx >= w:
				if b[y, xx] > 0.5: # dithered heat haze either side
					img[y, xx] = (120, 36, 16, 255)
			elif dx == w // 2 and (t // 3) % 4 != 0:
				img[y, xx] = (214, 116, 40, 255)
			else:
				img[y, xx] = (176, 66, 22, 255)
	pool_y = y0 + length
	for r, col in ((9, (120, 36, 16)), (6, (176, 66, 22)), (3, (214, 116, 40))):
		for dy in range(-2, 3):
			span = int(r * (1 - abs(dy) / 3.0))
			for dx in range(-span, span + w + 1):
				img[(pool_y + dy) % H, (x + dx) % W] = (*col, 255)


def magma_river(img: np.ndarray, y: int, seed: int, b: np.ndarray) -> None:
	"""A wavy band of magma across the tile, crusted with dark plates."""
	crust = fbm(W, 8, 16, 8, seed, 2)
	for x in range(W):
		cy = y + int(round(math.sin(x * 2 * math.pi / W * 2) * 4 + math.sin(x * 2 * math.pi / W * 5) * 1.5))
		for dy in range(-4, 5):
			yy = (cy + dy) % H
			edge = abs(dy)
			if edge == 4:
				if b[yy, x] > 0.5:
					img[yy, x] = (120, 36, 16, 255)
				continue
			col = (214, 116, 40) if edge <= 1 else (176, 66, 22)
			if crust[(dy + 4) % 8, x] > 0.62:
				col = (70, 20, 14)
			img[yy, x] = (*col, 255)


def hel() -> None:
	b = bayer(W, H)
	# Far: a distant cavern wall in deep crimson. Its gaps open on the hot
	# height gradient behind, and glow pockets, lavafalls and a magma river burn
	# through it. The brightest layer: distance in Hel is light.
	img = blank()
	n = fbm(W, H, 96, 72, 11, 3)
	wall = n < 0.5
	paint(img, wall, (54, 14, 16))
	paint(img, wall & (fbm(W, H, 8, 8, 12, 1) > 0.72), (62, 17, 17))
	paint(img, edge_above(wall), (96, 30, 18))
	glow = np.clip((n - 0.6) / 0.2, 0, 1)
	lvl = np.floor(glow * 3 + b * 0.999).astype(int)
	paint(img, ~wall & (lvl == 1), (150, 48, 18))
	paint(img, ~wall & (lvl == 2), (186, 76, 24))
	paint(img, ~wall & (lvl >= 3), (210, 108, 36))
	magma_river(img, 300, 13, b)
	for x, y0, length, w in ((52, 40, 150, 3), (206, 330, 120, 2), (318, 120, 190, 4)):
		lavafall(img, x, y0, length, w, b)
	save(img, "hel", "0_glow")

	# Mid: jagged rock pillars and stalactites, darker than the far wall and
	# lit from below by the lava.
	img = blank()
	n = fbm(W, H, 48, 144, 21, 3) + (fbm(W, H, 16, 8, 22, 1) - 0.5) * 0.1
	rock = n > 0.58
	paint(img, rock, (32, 9, 11))
	paint(img, rock & (fbm(W, H, 16, 48, 23, 2) > 0.6), (27, 7, 9))
	paint(img, edge_side(rock, 1) & ~edge_below(rock), (52, 15, 13))
	paint(img, edge_below(np.roll(rock, 1, axis=0) & rock), (92, 28, 14))
	paint(img, edge_below(rock), (150, 52, 18))
	save(img, "hel", "1_rocks_far")

	# Near: near-black silhouettes with hot rims, the darkest layer.
	img = blank()
	n = fbm(W, H, 64, 216, 31, 3) + (fbm(W, H, 16, 8, 32, 1) - 0.5) * 0.12
	rock = n > 0.64
	paint(img, rock, (12, 3, 5))
	rim = edge_below(np.roll(rock, 1, axis=0) & rock)
	paint(img, rim, (110, 34, 14))
	paint(img, edge_below(rock), (196, 80, 26))
	paint(img, edge_side(rock, -1) & ~edge_below(rock) & ~rim, (34, 9, 9))
	save(img, "hel", "2_rocks_near")


# ---------------------------------------------------------------- Yggdrasil
def trunk(img: np.ndarray, cx: int, half: int, seed: int, body: tuple, groove: tuple, lit: tuple) -> None:
	wob = fbm(1 * 8, H, 8, 48, seed, 2)[:, 0]
	for y in range(H):
		w = half + int((wob[y] - 0.5) * half * 0.5)
		for dx in range(-w, w + 1):
			x = (cx + dx) % W
			col = body
			if (dx + int(wob[y] * 7)) % 7 == 0:
				col = groove
			if dx == w or dx == w - 1:
				col = lit
			img[y, x] = (*col, 255)


def branch(img: np.ndarray, x: float, y: float, dir_x: int, length: float, rise: float, r: float, color: tuple, rng) -> None:
	ex, ey = x + dir_x * length, y - rise
	thick_line(img, x, y, ex, ey, r, max(r * 0.35, 1.0), color)
	if length > 40:
		for _ in range(2):
			t = rng.uniform(0.4, 0.8)
			bx, by = x + (ex - x) * t, y + (ey - y) * t
			thick_line(img, bx, by, bx + dir_x * length * 0.35, by - rng.uniform(-10, 30), r * 0.4, 1.0, color)


def leaf_clump(img: np.ndarray, cx: float, cy: float, r: float, colors: list, rng) -> None:
	for _ in range(int(r * 1.5)):
		ox, oy = rng.normal(0, r * 0.6), rng.normal(0, r * 0.4)
		wrap_disc(img, cx + ox, cy + oy, rng.uniform(r * 0.25, r * 0.5), colors[rng.integers(len(colors))])


def yggdrasil() -> None:
	rng = np.random.default_rng(41)
	# Far: colossal world-tree trunks fading into green-gold haze.
	img = blank()
	haze_body, haze_groove, haze_lit = (58, 66, 40), (52, 59, 36), (70, 78, 46)
	for cx, half in ((70, 34), (270, 52)):
		trunk(img, cx, half, int(cx), haze_body, haze_groove, haze_lit)
	for y0 in (60, 200, 330):
		for cx, half in ((70, 34), (270, 52)):
			d = 1 if rng.random() < 0.5 else -1
			branch(img, cx + d * half * 0.8, y0 + rng.integers(-20, 20), d, rng.uniform(60, 110), rng.uniform(20, 50), 6, haze_body, rng)
	save(img, "yggdrasil", "0_trunks_far")

	# Mid: nearer trunk with bark grooves, side branches and leaf clumps.
	img = blank()
	body, groove, lit = (36, 38, 24), (30, 31, 20), (48, 50, 30)
	trunk(img, 180, 30, 77, body, groove, lit)
	for y0 in (40, 150, 260, 370):
		d = -1 if (y0 // 10) % 2 else 1
		x0 = 180 + d * 26
		length = rng.uniform(90, 150)
		rise = rng.uniform(15, 45)
		branch(img, x0, y0, d, length, rise, 7, body, rng)
		leaf_clump(img, x0 + d * length, y0 - rise, 14, [(30, 46, 22), (38, 54, 26), (46, 58, 28)], rng)
	save(img, "yggdrasil", "1_trunk_mid")

	# Near: hanging roots and vines with a few leaves.
	img = blank()
	for i in range(14):
		x = rng.uniform(0, W)
		y = rng.uniform(0, H)
		length = rng.uniform(80, 260)
		thick = 1 if rng.random() < 0.6 else 2
		phase = rng.uniform(0, 6.28)
		col = (22, 20, 13) if i % 3 else (26, 30, 16)
		for t in range(int(length)):
			sx = x + math.sin(phase + t / 23) * 4
			for k in range(thick):
				img[int(y + t) % H, int(round(sx + k)) % W] = (*col, 255)
			if t % 19 == 9 and rng.random() < 0.7:
				lx = int(round(sx)) + (1 if rng.random() < 0.5 else -2)
				wrap_rect(img, lx, int(y + t), 2, 2, (30, 46, 20))
		wrap_rect(img, int(x) - 1, int(y + length), thick + 2, 2, col)
	save(img, "yggdrasil", "2_roots_near")


# ---------------------------------------------------------------- Sky
def cloud(img: np.ndarray, cx: float, cy: float, w: float, light: tuple, shade: tuple, rng) -> None:
	puffs = [(cx + rng.uniform(-w / 2, w / 2), cy + rng.uniform(-w / 10, w / 14), rng.uniform(w / 7, w / 4)) for _ in range(int(w / 9) + 3)]
	for px, py, r in puffs:
		wrap_disc(img, px, py + 2, r, shade)
	for px, py, r in puffs:
		wrap_disc(img, px, py, r * 0.85, light)


def sky() -> None:
	rng = np.random.default_rng(61)
	b = bayer(W, H)
	# Far: soft cloud strata.
	img = blank()
	n = fbm(W, H, 128, 24, 62, 3)
	v = np.clip((n - 0.5) / 0.25, 0, 1)
	lvl = np.floor(v * 3 + b * 0.999).astype(int)
	paint(img, lvl == 1, (150, 172, 205))
	paint(img, lvl == 2, (168, 188, 216))
	paint(img, lvl >= 3, (184, 200, 224))
	save(img, "sky", "0_strata")

	# Mid: distant floating islands, hazed blue.
	img = blank()
	spots = [(40, 70), (230, 30), (320, 190), (120, 250), (260, 360), (20, 380)]
	for cx, cy in spots:
		w = int(rng.uniform(22, 54))
		depth = int(w * rng.uniform(0.6, 0.9))
		for row in range(depth):
			half = int((w / 2) * (1 - row / depth) ** 0.8 + rng.uniform(-1.5, 1.5))
			col = (96, 112, 142) if row > 3 else (112, 128, 156)
			wrap_rect(img, cx - half, cy + row, half * 2 + 1, 1, col)
		wrap_rect(img, cx - w // 2, cy - 2, w + 1, 2, (122, 150, 150))
		for _ in range(w // 10):
			tx = cx + int(rng.uniform(-w / 2 + 3, w / 2 - 3))
			th = int(rng.uniform(4, 9))
			wrap_rect(img, tx, cy - 2 - th, 1, th, (100, 120, 128))
			wrap_rect(img, tx - 2, cy - 2 - th, 5, 3, (110, 138, 138))
	save(img, "sky", "1_islands")

	# Near: puffy clouds drifting with the wind.
	img = blank()
	for cx, cy, w in ((60, 60, 110), (260, 150, 90), (150, 280, 130), (330, 380, 80)):
		cloud(img, cx, cy, w, (192, 206, 228), (166, 184, 214), rng)
	save(img, "sky", "2_clouds_near")


# ---------------------------------------------------------------- Valhalla
def shield_roof(img: np.ndarray, x0: int, x1: int, y_eave: int, y_ridge: int, base: tuple, rim: tuple) -> None:
	"""Gabled roof shingled with round shields (Valhalla's roof is shields)."""
	h = y_eave - y_ridge
	mid = (x0 + x1) / 2
	half = (x1 - x0) / 2
	for row in range(h + 1):
		y = y_ridge + row
		span = half * row / h
		for x in range(int(mid - span), int(mid + span) + 1):
			img[y % H, x % W] = (*base, 255)
	for row in range(2, h, 4):
		y = y_ridge + row
		span = half * row / h
		off = 2 if (row // 4) % 2 else 0
		for x in range(int(mid - span) + off, int(mid + span), 4):
			img[y % H, x % W] = (*rim, 255)
	thick_line(img, x0, y_eave, mid, y_ridge, 0.5, 0.5, rim)
	thick_line(img, mid, y_ridge, x1, y_eave, 0.5, 0.5, rim)


def spire(img: np.ndarray, cx: int, base_y: int, w: int, tall: int, body: tuple, roof: tuple, light: tuple, rng) -> None:
	top = base_y - tall
	wrap_rect(img, cx - w // 2, top, w, tall, body)
	cone = int(w * 1.6)
	shield_roof(img, cx - w // 2 - 2, cx + w // 2 + 2, top, top - cone, body, roof)
	wrap_rect(img, cx, top - cone - 5, 1, 5, roof)
	for wy in range(top + 6, base_y - 6, 14):
		if rng.random() < 0.6:
			wrap_rect(img, cx - 1, wy, 2, 4, light)


def valhalla() -> None:
	rng = np.random.default_rng(81)
	b = bayer(W, H)
	# Far: storm clouds torn by golden light.
	img = blank()
	n = fbm(W, H, 96, 36, 82, 3)
	paint(img, n < 0.45, (46, 34, 54))
	paint(img, (n >= 0.45) & (n < 0.55) & (b > 0.5), (46, 34, 54))
	light = np.clip((n - 0.6) / 0.2, 0, 1)
	lvl = np.floor(light * 3 + b * 0.999).astype(int)
	paint(img, lvl == 1, (84, 64, 56))
	paint(img, lvl == 2, (108, 82, 58))
	paint(img, lvl >= 3, (130, 100, 62))
	save(img, "valhalla", "0_storm")

	# Mid: the long golden halls, a terrace per tile.
	img = blank()
	body, roof, lit = (64, 46, 44), (118, 90, 48), (150, 112, 50)
	ground = H - 24
	wrap_rect(img, 0, ground, W, 24, body)
	x = 0
	while x < W - 30:
		w = int(rng.uniform(60, 110))
		wall_h = int(rng.uniform(16, 26))
		wrap_rect(img, x + 4, ground - wall_h, w - 8, wall_h, body)
		shield_roof(img, x, x + w, ground - wall_h, ground - wall_h - int(w * 0.3), body, roof)
		for wx in range(x + 10, x + w - 10, 9):
			wrap_rect(img, wx, ground - wall_h + 5, 2, 5, lit)
		x += w + int(rng.uniform(6, 16))
	save(img, "valhalla", "1_halls")

	# Near: shield-roofed spires and towers.
	img = blank()
	body, roof, lit = (40, 30, 34), (92, 70, 42), (136, 100, 46)
	ground = H - 12
	wrap_rect(img, 0, ground, W, 12, body)
	for cx in (40, 150, 230, 330):
		spire(img, cx, ground, int(rng.uniform(14, 22)), int(rng.uniform(90, 200)), body, roof, lit, rng)
	save(img, "valhalla", "2_spires")


if __name__ == "__main__":
	hel()
	yggdrasil()
	sky()
	valhalla()
	print("wrote", os.path.normpath(OUT), file=sys.stderr)
