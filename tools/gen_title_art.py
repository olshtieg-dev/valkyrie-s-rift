#!/usr/bin/env python3
"""Generate the boot splash / intro / title screen pixel art.

Writes assets/sprites/title/*.png, all 1:1 pixel art for a 384x216 stage (the game view at zoom 3):
  studio_mark.png   olshtieg-dev emblem (generic hex monogram, 32x32)
  claude_mark.png   Claude AI credit mark (generic orange starburst, 17x17)
  village_girl.png  the death-reveal girl without her wings (mortal, pre-death)
  intro_backdrop.png  storm over a village edge, 768x216 (pans), opaque
  warlord.png       the Hel warlord who cuts her down (6 frames, 30x44)
  yggdrasil.png     the world tree, transparent, roots down into Hel's glow

Deterministic: same seeds -> same images.
Usage (from the repo root):  python3 tools/gen_title_art.py
Needs Pillow.
"""
from __future__ import annotations

import math
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "sprites", "title")
OUTLINE = (34, 24, 38, 255)  # same ink as the death-reveal girl


def outline(img: Image.Image, color=OUTLINE) -> Image.Image:
	"""Adds a 1px outline around every opaque pixel (4-neighbourhood)."""
	src = img.load()
	out = img.copy()
	dst = out.load()
	w, h = img.size
	for y in range(h):
		for x in range(w):
			if src[x, y][3]:
				continue
			for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
				nx, ny = x + dx, y + dy
				if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] and src[nx, ny] != color:
					dst[x, y] = color
					break
	return out


def disc(d: ImageDraw.ImageDraw, cx: float, cy: float, r: float, col) -> None:
	d.ellipse((round(cx - r), round(cy - r), round(cx + r), round(cy + r)), fill=col)


# --------------------------------------------------------------------------- marks

def studio_mark() -> Image.Image:
	"""A flat-topped hexagon with an 'o' monogram and a code caret: generic dev badge."""
	S = 32
	img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	c = (S - 1) / 2
	def hexagon(r: float):
		return [(c + r * math.cos(math.radians(a)), c + r * math.sin(math.radians(a))) for a in range(0, 360, 60)]
	d.polygon(hexagon(15), fill=(46, 64, 110, 255))
	d.polygon(hexagon(13), fill=(70, 110, 190, 255))
	# top-left light
	d.polygon([(c - 13, c), (c - 6.5, c - 11.3), (c + 6.5, c - 11.3), (c + 2, c - 6), (c - 8, c)], fill=(104, 150, 222, 255))
	# monogram: thick 'o' ring
	disc(d, c, c, 8, (246, 246, 252, 255))
	disc(d, c, c, 4.5, (70, 110, 190, 255))
	# gold rune-tick through the ring (a valkyrie spear / cursor)
	d.rectangle((c + 5, c - 10, c + 7, c + 10), fill=(244, 186, 56, 255))
	d.rectangle((c + 5, c - 10, c + 6, c + 10), fill=(255, 220, 120, 255))
	img = img.quantize(colors=16).convert("RGBA")
	return outline(img)


def claude_mark() -> Image.Image:
	"""Eight tapered rays around a bright core, in a warm clay orange."""
	S = 19
	img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	c = S // 2
	body = (217, 119, 87, 255)
	light = (240, 156, 120, 255)
	for i in range(8):
		a = i * math.pi / 4
		length = 9.0 if i % 2 == 0 else 7.0
		n = (-math.sin(a), math.cos(a))
		tip = (c + math.cos(a) * length, c + math.sin(a) * length)
		w = 1.7
		d.polygon([(c + n[0] * w, c + n[1] * w), tip, (c - n[0] * w, c - n[1] * w)], fill=body)
	disc(d, c, c, 2.4, body)
	disc(d, c - 0.5, c - 0.5, 1.2, light)
	return img


def godot_mark() -> Image.Image | None:
	"""The Godot logo (res://icon.svg, by Andrea Calabro, CC BY 4.0), without its
	tile background, rasterised small and snapped to hard pixels. Needs
	rsvg-convert; returns None (keep the committed PNG) when it isn't installed."""
	import re
	import shutil
	import subprocess
	if shutil.which("rsvg-convert") is None:
		return None
	svg = open(os.path.join(ROOT, "icon.svg"), encoding="utf-8").read()
	svg = re.sub(r"<rect[^>]*/>", "", svg, count=1)
	svg = svg.replace('width="128" height="128"', 'width="128" height="128" viewBox="12 12 104 104"')
	png = subprocess.run(["rsvg-convert", "-w", "40", "-h", "40"], input=svg.encode(), capture_output=True, check=True).stdout
	import io
	src = Image.open(io.BytesIO(png)).convert("RGBA")
	out = Image.new("RGBA", src.size, (0, 0, 0, 0))
	blue, white, dark = (71, 140, 191, 255), (255, 255, 255, 255), (65, 65, 65, 255)
	for y in range(src.height):
		for x in range(src.width):
			r, g, b, a = src.getpixel((x, y))
			if a < 128:
				continue
			# nearest of the logo's three colours
			out.putpixel((x, y), min((blue, white, dark), key=lambda c: (c[0] - r) ** 2 + (c[1] - g) ** 2 + (c[2] - b) ** 2))
	return outline(out.crop(out.getbbox()))


# --------------------------------------------------------------------------- girl

def village_girl() -> Image.Image:
	"""The death-reveal girl with both wings cut away, cropped to her body."""
	src = Image.open(os.path.join(ROOT, "assets", "sprites", "valkyrie", "fallen_valkyrie.png")).convert("RGBA")
	img = src.copy()
	px = img.load()
	w, h = img.size
	for y in range(h):
		for x in range(w):
			if x <= 4 or x >= 23:
				px[x, y] = (0, 0, 0, 0)
	# The left wing's root joined her hair at x=5 on rows 8-10; close the hair edge.
	return img.crop((5, 0, 23, 24))


# --------------------------------------------------------------------------- intro backdrop

def intro_backdrop() -> Image.Image:
	"""A storm over a village's edge, 768 wide so the intro camera can pan.
	Left: the village (some houses burning). Middle: open field. Right:
	standing runestones and a dead tree. Ground line at y=184. Drawn dark: the
	intro tints it further and lightning flashes reveal it."""
	W, H = 768, 216
	rnd = random.Random(7)
	img = Image.new("RGBA", (W, H))
	d = ImageDraw.Draw(img)
	horizon = 164
	bands = [(14, 14, 26), (18, 18, 32), (22, 22, 40), (28, 26, 46), (34, 30, 52), (44, 34, 56), (60, 40, 58)]
	for y in range(horizon):
		t = y / horizon
		i = min(int(t ** 1.2 * len(bands)), len(bands) - 1)
		f = (t ** 1.2 * len(bands)) % 1.0
		for x in range(W):
			j = i + 1 if (f > 0.75 and (x + y) % 2 == 0 and i + 1 < len(bands)) else i
			img.putpixel((x, y), bands[j] + (255,))
	# heavy storm clouds: overlapping blobs, lit a little from below
	for layer, (base, col, lit) in enumerate(((10, (30, 30, 46), (40, 40, 60)), (34, (24, 24, 38), (36, 34, 54)), (60, (20, 20, 32), (30, 28, 46)))):
		for _ in range(34):
			cx, cy = rnd.uniform(-20, W + 20), base + rnd.uniform(-10, 12)
			r = rnd.uniform(10, 26)
			rx, ry = r * 2.2, r * 0.7
			d.ellipse((round(cx - rx), round(cy - ry + 2), round(cx + rx), round(cy + ry + 2)), fill=lit + (255,))
			d.ellipse((round(cx - rx), round(cy - ry), round(cx + rx), round(cy + ry)), fill=col + (255,))
	# far mountains
	def ridge(base: int, amp: float, freq: float, seed: int, col):
		r = random.Random(seed)
		ph = [r.random() * 6.28 for _ in range(3)]
		for x in range(W):
			yy = base - amp * (0.6 * math.sin(x * freq + ph[0]) + 0.3 * math.sin(x * freq * 2.7 + ph[1]) + 0.15 * math.sin(x * freq * 6.1 + ph[2]))
			d.line((x, round(yy), x, horizon + 20), fill=col)
	ridge(138, 18, 0.02, 1, (36, 30, 50, 255))
	ridge(152, 10, 0.035, 2, (26, 22, 36, 255))
	# village on the left; two houses burning (their glow is drawn in code too)
	house = (18, 14, 22, 255)
	x = 4
	for k, (wdt, hgt) in enumerate(((26, 16), (20, 12), (30, 20), (18, 11), (24, 15))):
		top = horizon - hgt
		d.rectangle((x, top, x + wdt, horizon + 4), fill=house)
		d.polygon([(x - 3, top), (x + wdt // 2, top - wdt // 2 + 2), (x + wdt + 3, top)], fill=house)
		burning = k in (0, 2)
		for wx in range(x + 4, x + wdt - 3, 8):
			d.rectangle((wx, top + 4, wx + 2, top + 6), fill=(255, 150, 60, 255) if burning else (200, 150, 70, 255))
		if burning:  # charred, broken roof edge
			for bx in range(x + 2, x + wdt - 2, 3):
				d.point((bx, top - rnd.randint(0, 3)), fill=(120, 40, 20, 255))
		x += wdt + 9
	# pines
	for px0 in (176, 188, 420, 432, 444):
		for k in range(5):
			hw = 2 + k * 2
			yy = horizon - 30 + k * 6
			d.polygon([(px0, yy - 6), (px0 - hw, yy + 4), (px0 + hw, yy + 4)], fill=(14, 12, 20, 255))
		d.rectangle((px0 - 1, horizon - 2, px0 + 1, horizon + 2), fill=(14, 12, 20, 255))
	g = 184
	d.rectangle((0, horizon, W, g), fill=(24, 22, 30, 255))
	# runestones on the right
	for (sx, sw, sh) in ((560, 8, 22), (578, 10, 30), (598, 7, 18), (690, 9, 26)):
		d.rectangle((sx, 184 - sh, sx + sw, 184), fill=(52, 50, 62, 255))
		d.rectangle((sx, 184 - sh, sx + 1, 184), fill=(70, 68, 82, 255))
		d.rectangle((sx + sw // 2, 184 - sh + 4, sx + sw // 2, 184 - sh + 10), fill=(40, 38, 50, 255))
	# dead tree
	tx = 650
	d.line((tx, 184, tx + 2, 120), fill=(22, 18, 24, 255), width=4)
	for (ex, ey) in ((tx - 18, 112), (tx + 20, 106), (tx - 6, 100), (tx + 12, 128)):
		d.line((tx + 1, 140, ex, ey), fill=(22, 18, 24, 255), width=2)
	# ground: wet grass lip, mud with puddles
	g = 184
	d.rectangle((0, g, W, H), fill=(52, 40, 40, 255))
	d.rectangle((0, g + 6, W, H), fill=(40, 30, 34, 255))
	d.rectangle((0, g + 18, W, H), fill=(28, 22, 28, 255))
	d.rectangle((0, g, W, g + 2), fill=(52, 86, 58, 255))
	d.line((0, g, W, g), fill=(78, 120, 80, 255))
	for xx in range(0, W, 3):
		if rnd.random() < 0.6:
			d.point((xx, g - 1), fill=(52, 86, 58, 255))
	for _ in range(14):  # puddles catching the sky
		px0, py0 = rnd.randrange(W), rnd.randrange(g + 5, g + 16)
		wdt = rnd.randint(6, 16)
		d.rectangle((px0, py0, px0 + wdt, py0), fill=(70, 72, 96, 255))
		d.point((px0 + 1, py0), fill=(110, 112, 140, 255))
	for _ in range(120):
		xx, yy = rnd.randrange(W), rnd.randrange(g + 4, H)
		d.point((xx, yy), fill=(66, 50, 48, 255) if yy < g + 18 else (40, 30, 36, 255))
	return img


# --------------------------------------------------------------------------- title scene
# The title screen is a stack of layers (back to front), all 1:1 on the
# 384x216 stage; the sky, aurora, mist and critters are drawn in code
# (scripts/ui/title_backdrop.gd):
#   title_mountains_far, title_mountains_near, title_forest_far, title_hill,
#   yggdrasil (+ yggdrasil_glow), title_frame (framing trees + foreground)

TW, TH = 392, 216  # 4px spare each side for the slow parallax drift
BAYER4 = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))


def _shade(px, w, h, cx, cy, r, palette, light=(-0.55, -0.7, 0.45), rim=None, rim_dir=(1.0, 0.2), sy=1.0, jag=0.0):
	"""Paints a sphere-shaded disc: lit from `light`, quantised to `palette`
	(dark -> light) with a 4x4 ordered dither; optional warm rim on one side."""
	lx, ly, lz = light
	n = math.sqrt(lx * lx + ly * ly + lz * lz)
	lx, ly, lz = lx / n, ly / n, lz / n
	ry = r * sy
	for y in range(max(0, int(cy - ry) - 1), min(h, int(cy + ry) + 2)):
		for x in range(max(0, int(cx - r) - 1), min(w, int(cx + r) + 2)):
			nx, ny = (x + 0.5 - cx) / r, (y + 0.5 - cy) / ry
			d2 = nx * nx + ny * ny
			if jag:
				# leafy edge: the outline wobbles with angle
				a = math.atan2(ny, nx)
				edge = 1.0 - jag * (0.5 + 0.5 * math.sin(a * 9.0 + cx * 0.7) * math.sin(a * 5.0 + cy))
				if d2 > edge * edge:
					continue
				d2 = min(1.0, d2 / (edge * edge))
			if d2 > 1.0:
				continue
			nz = math.sqrt(1.0 - d2)
			lum = max(0.0, nx * lx + ny * ly + nz * lz)
			lum = lum * 0.85 + 0.1
			t = lum * (len(palette) - 1) + (BAYER4[y % 4][x % 4] / 16.0 - 0.5) * 0.45
			i = min(len(palette) - 1, max(0, int(round(t))))
			col = palette[i]
			if rim and nx * rim_dir[0] + ny * rim_dir[1] > 0.9 and d2 > 0.8:
				col = rim
			px[x, y] = col


def _ridge(w, base, amp, rough, seed):
	"""Midpoint-displacement skyline: list of heights (y) per column."""
	rnd = random.Random(seed)
	size = 1
	while size < w + 1:
		size *= 2
	pts = [0.0] * (size + 1)
	pts[0], pts[size] = rnd.uniform(-1, 1), rnd.uniform(-1, 1)
	step, scale = size, 1.0
	while step > 1:
		half = step // 2
		for i in range(half, size, step):
			pts[i] = (pts[i - half] + pts[i + half]) / 2 + rnd.uniform(-1, 1) * scale
		step, scale = half, scale * rough
	return [base - pts[x] * amp for x in range(w)]


def title_mountains_far() -> Image.Image:
	"""Tall snow-capped peaks, hazed toward the sky, sunset light from the right."""
	img = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
	px = img.load()
	hts = _ridge(TW, 96, 40, 0.55, 11)
	# a great massif left of centre, where the title's open sky is
	hts = [h - 42 * math.exp(-((x - 150) / 46.0) ** 2) - 20 * math.exp(-((x - 40) / 30.0) ** 2) for x, h in enumerate(hts)]
	lit, shade, snow_lit, snow_sh = (122, 84, 118, 255), (78, 58, 98, 255), (236, 204, 210, 255), (150, 142, 184, 255)
	base_col = (64, 50, 88, 255)
	for x in range(TW):
		top = int(hts[x])
		slope = hts[min(TW - 1, x + 3)] - hts[max(0, x - 3)]
		facing = slope > 0.5  # descending to the right faces the sunset
		snowline = 78 + 6 * math.sin(x * 0.21) + 4 * math.sin(x * 0.07)
		gully = 10 + 8 * math.sin(x * 0.45) + 5 * math.sin(x * 1.3)
		for y in range(max(0, top), TH):
			depth = y - top
			if y < snowline and depth < 30:
				col = snow_lit if facing else snow_sh
				# rock showing through in gullies running down the face
				if depth > gully or (depth > 3 and (x + y // 2) % 9 == 0):
					col = lit if facing else shade
			elif depth < 3:
				col = lit if facing else shade
			else:
				col = (lit if facing else shade) if depth < 10 and BAYER4[y % 4][x % 4] > 6 + depth else base_col
			px[x, y] = col
	return img


def title_mountains_near() -> Image.Image:
	"""Lower, darker ranges with sparse pines on the ridges."""
	img = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
	px = img.load()
	d = ImageDraw.Draw(img)
	hts = _ridge(TW, 146, 20, 0.5, 23)
	lit, shade, base_col = (70, 50, 82, 255), (44, 34, 62, 255), (36, 28, 52, 255)
	for x in range(TW):
		top = int(hts[x])
		slope = hts[min(TW - 1, x + 1)] - hts[max(0, x - 1)]
		for y in range(max(0, top), TH):
			depth = y - top
			if depth < 2:
				px[x, y] = lit if slope > 0.2 else shade
			else:
				px[x, y] = base_col
	rnd = random.Random(5)
	for x in range(2, TW - 2, 3):
		if rnd.random() < 0.45:
			top = int(hts[x])
			hgt = rnd.randint(3, 6)
			d.polygon([(x, top - hgt), (x - 2, top + 1), (x + 2, top + 1)], fill=(30, 24, 44, 255))
	return img


def title_forest_far() -> Image.Image:
	"""A dense band of pines along the valley floor, cool and dark."""
	img = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	rnd = random.Random(31)
	for layer, (base, col, tip) in enumerate(((168, (28, 34, 54, 255), (44, 52, 76, 255)), (176, (20, 26, 42, 255), (34, 44, 64, 255)))):
		d.rectangle((0, base, TW, TH), fill=col)
		x = -4
		while x < TW + 4:
			hgt = rnd.randint(12, 24) - layer * 2
			wdt = rnd.randint(5, 8)
			for k in range(3):  # three tiers per pine
				ty = base - hgt + k * hgt // 3
				tw = wdt * (k + 1) / 3 + 1
				d.polygon([(x, ty), (x - tw, ty + hgt // 3 + 2), (x + tw, ty + hgt // 3 + 2)], fill=col)
				d.line((x, ty, x - tw, ty + hgt // 3 + 2), fill=tip)  # moonlit edge
			x += rnd.randint(6, 10)
	return img


def title_hill() -> Image.Image:
	"""The rise Yggdrasil stands on, and the meadow floor."""
	img = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
	px = img.load()
	cx = 268
	for x in range(TW):
		# a broad mound under the tree, flattening toward the left
		top = 198 - 16 * math.exp(-((x - cx) / 70.0) ** 2) + 2 * math.sin(x * 0.13)
		top = int(round(top))
		for y in range(max(0, top), TH):
			depth = y - top
			if depth == 0:
				col = (112, 168, 96, 255)
			elif depth < 3:
				col = (62, 112, 72, 255)
			elif depth < 7 and BAYER4[y % 4][x % 4] > depth * 2:
				col = (62, 112, 72, 255)
			else:
				col = (30, 52, 46, 255) if y < 206 else (22, 38, 38, 255)
			px[x, y] = col
		if x % 3 == 0:
			px[x, max(0, top - 1)] = (112, 168, 96, 255)
	return img


def yggdrasil() -> Image.Image:
	"""The world tree, redrawn: a twisted double trunk, buttress roots, a
	vast sphere-shaded crown lit by moonlight from the upper left with a
	warm sunset rim on the right, hanging vines and golden apples."""
	return _yggdrasil()[0]


def yggdrasil_glow() -> Image.Image:
	"""Just the glowing bits (trunk runes, apples), pulsed by the title."""
	return _yggdrasil()[1]


_YGG_CACHE: list = []


def _yggdrasil():
	if _YGG_CACHE:
		return _YGG_CACHE[0]
	W, H = 300, 214
	rnd = random.Random(1337)
	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	px = img.load()
	gx = glow.load()
	BARK = [(40, 24, 30, 255), (66, 42, 42, 255), (98, 66, 56, 255), (138, 98, 74, 255), (180, 136, 96, 255)]
	LEAF = [(18, 44, 46, 255), (28, 70, 58, 255), (44, 104, 70, 255), (76, 146, 82, 255), (138, 196, 108, 255)]
	RIM = (200, 150, 104, 255)
	cx = W // 2

	def bez(p0, p1, p2, n):
		for i in range(n + 1):
			t = i / n
			yield ((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
			       (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1], t)

	def tube(p0, p1, p2, r0, r1, n=60, rim=None):
		for x, y, t in bez(p0, p1, p2, n):
			_shade(px, W, H, x, y, r0 + (r1 - r0) * t, BARK, rim=rim)

	base_y = H - 6
	# roots: buttresses flaring into the hill
	for ex, mx, my, r in ((-110, -50, -2, 6), (-70, -30, -6, 6), (-36, -14, -8, 5), (34, 14, -8, 5), (72, 32, -6, 6), (116, 54, -2, 7)):
		tube((cx + ex * 0.12, base_y - 16), (cx + mx, base_y + my), (cx + ex, base_y + 2), r, 1.5)
	# boughs (behind the crown, some show beneath it)
	bough_ends = []
	for ex, ey, mx, my, r in ((-104, 62, -50, 92, 6), (104, 56, 50, 88, 6), (-70, 30, -30, 66, 5), (70, 26, 30, 62, 5),
	                          (-28, 12, -10, 52, 5), (26, 10, 8, 50, 5), (-122, 92, -66, 108, 4), (124, 88, 68, 104, 4)):
		tube((cx, 114), (cx + mx, my + 12), (cx + ex, ey + 12), r, 2, n=50)
		bough_ends.append((cx + ex, ey + 12))
	# the trunk: two strands twisting round each other
	for strand, phase in ((0, 0.0), (1, math.pi)):
		for i in range(90):
			t = i / 89
			y = base_y - 4 - t * 104
			x = cx + math.sin(t * 5.0 + phase) * (8 - t * 3)
			r = 8.5 - t * 3 + 7 * math.exp(-t * 9)  # flared base
			_shade(px, W, H, x, y, r, BARK)
	# bark grooves
	for _ in range(70):
		x = cx + rnd.randint(-14, 14)
		y0 = rnd.randint(100, base_y - 10)
		for y in range(y0, y0 + rnd.randint(3, 8)):
			if px[x, y][3] and px[x, y] not in (BARK[0], RIM):
				px[x, y] = BARK[1]
	# runes glowing up the trunk
	runes = [((0, 0), (0, 1), (0, 2), (0, 3), (1, 1), (1, 2)),
	         ((0, 0), (0, 1), (0, 2), (0, 3), (1, 0), (-1, 0)),
	         ((0, 0), (0, 1), (0, 2), (0, 3), (1, 1), (-1, 2)),
	         ((0, 0), (1, 1), (0, 2), (-1, 1), (0, 3))]
	for k, rune in enumerate(runes):
		ry = 128 + k * 16
		rx = cx + int(math.sin((base_y - 4 - ry) / 104 * 5.0) * 2)
		for dx, dy in rune:
			px[rx + dx, ry + dy] = (150, 255, 236, 255)
			for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
				if not gx[rx + dx + ox, ry + dy + oy][3]:
					gx[rx + dx + ox, ry + dy + oy] = (90, 230, 210, 140)
			gx[rx + dx, ry + dy] = (210, 255, 248, 255)
	# crown: many leaf spheres, back (top) to front (bottom)
	clusters = []
	for ex, ey in bough_ends:
		for _ in range(6):
			clusters.append((ex + rnd.uniform(-16, 16), ey + rnd.uniform(-12, 8), rnd.uniform(10, 16)))
	for _ in range(46):
		a = rnd.uniform(math.pi * 1.0, math.pi * 2.0)
		rr = rnd.uniform(10, 1.0) * 0 + rnd.uniform(14, 112)
		clusters.append((cx + math.cos(a) * rr * 1.1, 82 + math.sin(a) * rr * 0.5, rnd.uniform(11, 17)))
	clusters.sort(key=lambda c: c[1])
	for x, y, r in clusters:
		_shade(px, W, H, x, y, r, LEAF, rim=RIM, rim_dir=(0.9, 0.45), jag=0.22)
	# leafy texture: scattered single-shade flecks inside the crown
	for _ in range(900):
		x, y = rnd.randrange(W), rnd.randrange(140)
		c = px[x, y]
		if c in LEAF[1:4] and BAYER4[y % 4][x % 4] < 5:
			px[x, y] = LEAF[LEAF.index(c) + 1] if rnd.random() < 0.5 else LEAF[LEAF.index(c) - 1]
	# hanging vines from the crown's underside
	for _ in range(16):
		x = rnd.randrange(30, W - 30)
		y = max((yy for yy in range(0, 140) if px[x, yy][3] and px[x, yy] in LEAF), default=None)
		if y is None or y < 50:
			continue
		for k in range(rnd.randint(6, 18)):
			if y + k >= H:
				break
			px[x + (1 if (k // 4) % 2 else 0), y + k] = LEAF[1] if k % 3 else LEAF[2]
	# golden apples of Idunn (also in the glow layer)
	for _ in range(26):
		x, y = rnd.randrange(8, W - 8), rnd.randrange(10, 120)
		if px[x, y] in LEAF[1:4] and px[x, y - 2][3]:
			px[x, y] = (255, 210, 90, 255)
			px[x + 1, y] = (230, 160, 50, 255)
			px[x, y + 1] = (210, 130, 40, 255)
			gx[x, y] = (255, 230, 140, 255)
			for ox, oy in ((-1, 0), (2, 0), (0, -1), (1, 1), (0, 2)):
				gx[x + ox, y + oy] = (255, 200, 90, 110)
	img = outline(img, (14, 10, 20, 255))
	_YGG_CACHE.append((img, glow))
	return img, glow


def title_frame() -> Image.Image:
	"""Foreground: an old oak on the left whose leaves overhang the top-left
	corner, tall pines on the right, ferns and grass along the bottom. Dark,
	with a faint moonlit edge, so it frames the scene without stealing it."""
	img = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
	px = img.load()
	d = ImageDraw.Draw(img)
	rnd = random.Random(77)
	DARK = [(10, 12, 20, 255), (16, 20, 30, 255), (24, 30, 42, 255), (40, 50, 66, 255)]
	# left oak: trunk at the edge, a bough reaching right, a canopy across the top corner
	for i in range(80):
		t = i / 79
		_shade(px, TW, TH, 4 + t * 3, TH + 4 - t * 200, 9 - t * 3, DARK[:3] + [DARK[3]])
	for i in range(40):
		t = i / 39
		_shade(px, TW, TH, 8 + t * 60, 30 - math.sin(t * 2.6) * 10, 4 - t * 2, DARK)
	for _ in range(18):
		x = rnd.uniform(-8, 80)
		y = rnd.uniform(-8, 14) - x / 16.0
		_shade(px, TW, TH, x, y, rnd.uniform(6, 10), DARK, light=(-0.3, -0.8, 0.5))
	# right pines: two tall, tiered
	for (bx, top, half) in ((382, 6, 22), (360, 34, 16)):
		d.rectangle((bx - 1, top + 10, bx + 1, TH), fill=DARK[1])
		tiers = (TH - top) // 12
		for k in range(tiers):
			y = top + k * 12
			hw = 4 + k * half / tiers
			d.polygon([(bx, y), (bx - hw, y + 14), (bx + hw, y + 14)], fill=DARK[0])
			d.line((bx, y, bx - hw, y + 14), fill=DARK[3])  # moonlit edge (left)
	# ferns, grass and a few glowing flowers along the bottom
	for x in range(0, TW, 2):
		h = rnd.randint(2, 7) + (6 if x < 40 or x > 340 else 0)
		lean = rnd.choice((-1, 0, 1))
		d.line((x, TH, x + lean, TH - h), fill=DARK[1] if rnd.random() < 0.7 else DARK[2])
	for _ in range(9):
		x = rnd.randrange(10, TW - 10)
		y = TH - rnd.randint(4, 9)
		col = rnd.choice(((150, 220, 255, 255), (255, 200, 240, 255), (255, 240, 160, 255)))
		px[x, y] = col
		px[x, y + 1] = DARK[2]
	return img


# --------------------------------------------------------------------------- warlord

WL_W, WL_H = 30, 44
## Where his sword hand is in every frame (the intro draws the greatsword there).
WL_HAND = (22, 25)


def _warlord_frame(leg_a: int, leg_b: int, bob: int) -> Image.Image:
	"""One frame of the Hel warlord, facing right, feet on the bottom row.
	leg_a / leg_b shift the back / front leg forward (+) or back (-)."""
	img = Image.new("RGBA", (WL_W, WL_H), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	K = (20, 14, 22, 255)
	D, M, L = (40, 36, 50, 255), (66, 62, 80, 255), (104, 100, 124, 255)
	CAPE, CAPE_D = (110, 18, 26, 255), (66, 10, 18, 255)
	GOLD = (170, 118, 40, 255)
	RED, RED_D = (255, 60, 40, 255), (170, 24, 24, 255)
	BONE, BONE_D = (214, 204, 172, 255), (150, 140, 112, 255)
	y0 = bob  # upper body bobs, legs don't
	# cape, flaring back and down, tattered hem
	d.polygon([(10, 14 + y0), (14, 14 + y0), (13, 38), (3, 41), (5, 26)], fill=CAPE_D)
	d.polygon([(11, 15 + y0), (14, 15 + y0), (12, 36), (6, 38), (7, 26)], fill=CAPE)
	for x in range(3, 13, 2):
		d.point((x, 41 if x % 4 else 39), fill=CAPE_D)
	# legs: greaves and sabatons
	for lx, shift, shade in ((10, leg_a, D), (18, leg_b, M)):
		x = lx + shift
		d.rectangle((x, 30, x + 3, 41), fill=shade)
		d.rectangle((x, 30, x, 41), fill=L if shade == M else M)
		d.rectangle((x - 1, 35, x + 4, 36), fill=D)        # knee guard
		d.rectangle((x, 42, x + 5, 43), fill=D)            # boot, toe forward
		d.point((x + 5, 42), fill=M)
	# tassets (armored skirt) and belt
	d.polygon([(10, 27 + y0), (22, 27 + y0), (23, 32 + y0), (9, 32 + y0)], fill=D)
	d.line((11, 31 + y0, 21, 31 + y0), fill=M)
	d.rectangle((10, 26 + y0, 22, 27 + y0), fill=GOLD)
	d.point((16, 26 + y0), fill=(230, 180, 70, 255))
	# torso: breastplate with a glowing rune
	d.rectangle((10, 15 + y0, 22, 25 + y0), fill=D)
	d.rectangle((12, 16 + y0, 21, 25 + y0), fill=M)
	d.rectangle((13, 16 + y0, 14, 24 + y0), fill=L)
	d.line((16, 18 + y0, 16, 23 + y0), fill=RED_D)
	d.point((17, 19 + y0), fill=RED)
	d.point((15, 21 + y0), fill=RED)
	d.point((16, 20 + y0), fill=RED)
	# back arm (behind the body) and front arm down to the sword hand
	d.rectangle((8, 17 + y0, 10, 24 + y0), fill=D)
	d.rectangle((20, 17 + y0, 23, 23 + y0), fill=M)
	d.rectangle((21, 23 + y0, 24, 26 + y0), fill=D)            # gauntlet
	d.point((21, 23 + y0), fill=L)
	# pauldrons, spiked
	disc(d, 10, 15 + y0, 3.5, D)
	disc(d, 21, 15 + y0, 4.2, M)
	disc(d, 20, 14 + y0, 2.0, L)
	for sx, sy in ((19, 10), (22, 10), (9, 11)):
		d.line((sx, sy + y0, sx, sy + 2 + y0), fill=BONE_D)
		d.point((sx, sy + y0), fill=BONE)
	# helm, with a T-shaped visor glowing red
	d.rectangle((13, 4 + y0, 20, 13 + y0), fill=D)
	d.rectangle((14, 4 + y0, 20, 12 + y0), fill=M)
	d.rectangle((14, 5 + y0, 15, 11 + y0), fill=L)
	d.rectangle((16, 8 + y0, 20, 8 + y0), fill=RED)
	d.rectangle((18, 8 + y0, 18, 11 + y0), fill=RED_D)
	d.point((19, 8 + y0), fill=(255, 200, 160, 255))
	d.rectangle((15, 3 + y0, 18, 3 + y0), fill=D)            # crest ridge
	# horns: from the helm's sides, curling up and back
	for pts in (((13, 7), (11, 5), (10, 2), (11, 0)), ((20, 6), (22, 4), (23, 1), (22, 0))):
		pts = [(x, y + y0) for x, y in pts]
		d.line(pts, fill=BONE, width=1)
		d.point(pts[0], fill=BONE_D)
		d.point((pts[1][0], pts[1][1] + 1), fill=BONE_D)
	return outline(img, K)


def warlord() -> Image.Image:
	"""Strip of 6 frames: 2 idle (breathing), 4 walk."""
	frames = [_warlord_frame(0, 0, 0), _warlord_frame(0, 0, 1),
	          _warlord_frame(-3, 3, 0), _warlord_frame(-1, 1, 1), _warlord_frame(3, -3, 0), _warlord_frame(1, -1, 1)]
	strip = Image.new("RGBA", (WL_W * len(frames), WL_H), (0, 0, 0, 0))
	for i, f in enumerate(frames):
		strip.alpha_composite(f, (i * WL_W, 0))
	return strip


def main() -> None:
	os.makedirs(OUT, exist_ok=True)
	for name, fn in (("studio_mark", studio_mark), ("claude_mark", claude_mark), ("village_girl", village_girl),
	                 ("intro_backdrop", intro_backdrop), ("yggdrasil", yggdrasil), ("warlord", warlord),
	                 ("yggdrasil_glow", yggdrasil_glow), ("title_mountains_far", title_mountains_far),
	                 ("title_mountains_near", title_mountains_near), ("title_forest_far", title_forest_far),
	                 ("title_hill", title_hill), ("title_frame", title_frame), ("godot_mark", godot_mark)):
		path = os.path.join(OUT, name + ".png")
		img = fn()
		if img is None:
			print("skipped", name)
			continue
		img.save(path)
		print("wrote", os.path.relpath(path, ROOT))


if __name__ == "__main__":
	main()
