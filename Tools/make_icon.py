#!/usr/bin/env python3
"""
Generates the FocusGlobe app icon as a 1024x1024 PNG using only the Python
standard library (zlib + struct). No external imaging dependencies required.

The icon is original artwork: a calm night-sky gradient, a soft dotted route
arc, a destination glow, and a glowing balloon drifting upward — capturing
"turn focus into a sky journey".

Run:  python3 Tools/make_icon.py
Out:  FocusGlobe/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
"""

import math
import os
import struct
import zlib

W = H = 1024


def clamp(x, lo=0.0, hi=1.0):
    return max(lo, min(hi, x))


def smoothstep(e0, e1, x):
    if e0 == e1:
        return 0.0 if x < e0 else 1.0
    t = clamp((x - e0) / (e1 - e0))
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def lerp3(c0, c1, t):
    return (lerp(c0[0], c1[0], t), lerp(c0[1], c1[1], t), lerp(c0[2], c1[2], t))


# Flat RGB buffer
buf = [0.0] * (W * H * 3)


def idx(x, y):
    return (y * W + x) * 3


def set_px(x, y, rgb):
    i = idx(x, y)
    buf[i], buf[i + 1], buf[i + 2] = rgb


def get_px(x, y):
    i = idx(x, y)
    return (buf[i], buf[i + 1], buf[i + 2])


def blend(x, y, rgb, a):
    if a <= 0:
        return
    a = clamp(a)
    i = idx(x, y)
    buf[i] = lerp(buf[i], rgb[0], a)
    buf[i + 1] = lerp(buf[i + 1], rgb[1], a)
    buf[i + 2] = lerp(buf[i + 2], rgb[2], a)


# ---- Background: deep calm night sky with a soft horizon glow ------------
TOP = (14, 21, 46)        # deep navy
MID = (28, 40, 84)        # indigo
BOT = (9, 13, 28)         # near-black navy
GLOW = (86, 132, 232)     # subtle blue glow

glow_cx, glow_cy, glow_r = W * 0.42, H * 0.40, W * 0.62
for y in range(H):
    ty = y / (H - 1)
    if ty < 0.55:
        base = lerp3(TOP, MID, smoothstep(0.0, 0.55, ty))
    else:
        base = lerp3(MID, BOT, smoothstep(0.55, 1.0, ty))
    row = y * W * 3
    for x in range(W):
        d = math.hypot(x - glow_cx, y - glow_cy) / glow_r
        g = (1.0 - clamp(d)) ** 2 * 0.35
        i = row + x * 3
        buf[i] = lerp(base[0], GLOW[0], g)
        buf[i + 1] = lerp(base[1], GLOW[1], g)
        buf[i + 2] = lerp(base[2], GLOW[2], g)


def soft_circle(cx, cy, r, color, feather=2.0, max_a=1.0):
    x0 = max(0, int(cx - r - feather - 2))
    x1 = min(W - 1, int(cx + r + feather + 2))
    y0 = max(0, int(cy - r - feather - 2))
    y1 = min(H - 1, int(cy + r + feather + 2))
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            dist = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            a = (1.0 - smoothstep(r - feather, r + feather, dist)) * max_a
            if a > 0:
                blend(x, y, color, a)


def radial_glow(cx, cy, r, color, strength):
    x0 = max(0, int(cx - r)); x1 = min(W - 1, int(cx + r))
    y0 = max(0, int(cy - r)); y1 = min(H - 1, int(cy + r))
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy) / r
            if d < 1.0:
                a = (1.0 - d) ** 2 * strength
                blend(x, y, color, a)


def seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    if dx == 0 and dy == 0:
        return math.hypot(px - ax, py - ay)
    t = clamp(((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


# ---- Route arc (quadratic bezier), drawn as soft dots --------------------
def bezier(t, p0, p1, p2):
    u = 1 - t
    x = u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0]
    y = u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1]
    return x, y


# A few faint stars in the calm night sky
for sx, sy, sr, sa in [
    (760, 250, 4, 0.7), (835, 330, 3, 0.5), (690, 180, 3, 0.55),
    (610, 300, 2.5, 0.45), (880, 470, 2.5, 0.4), (300, 230, 3, 0.5),
    (210, 360, 2.5, 0.4), (560, 200, 2, 0.4),
]:
    soft_circle(sx, sy, sr, (235, 242, 255), feather=1.5, max_a=sa)

P0 = (W * 0.175, H * 0.695)
P1 = (W * 0.475, H * 0.245)
P2 = (W * 0.838, H * 0.475)

dot_color = (150, 185, 250)
n_dots = 13
for k in range(n_dots):
    t = k / (n_dots - 1)
    bx, by = bezier(t, P0, P1, P2)
    r = lerp(6, 11, t)
    soft_circle(bx, by, r, dot_color, feather=2.0, max_a=lerp(0.28, 0.82, t))

# Origin marker at the arc start (balances the destination)
soft_circle(P0[0], P0[1], 19, (120, 160, 240), feather=3, max_a=0.30)
soft_circle(P0[0], P0[1], 9, (210, 224, 252), feather=2, max_a=0.70)

# Destination marker at the arc end
soft_circle(P2[0], P2[1], 26, (120, 160, 240), feather=3, max_a=0.45)
soft_circle(P2[0], P2[1], 15, (220, 232, 255), feather=2, max_a=0.95)

# ---- Balloon, drifting near the top of the arc ---------------------------
bx, by = bezier(0.34, P0, P1, P2)
bx -= 4
env_r = 122

# Glow halo behind the balloon
radial_glow(bx, by - 6, env_r * 2.1, (130, 170, 245), 0.30)

# Envelope: vertical cream gradient sphere with rim light
ex0, ex1 = int(bx - env_r - 3), int(bx + env_r + 3)
ey0, ey1 = int(by - env_r - 3), int(by + env_r * 1.18 + 3)
for y in range(max(0, ey0), min(H - 1, ey1) + 1):
    for x in range(max(0, ex0), min(W - 1, ex1) + 1):
        # Teardrop: stretch vertically below center for a balloon-like base
        ny = (y + 0.5 - by)
        nx = (x + 0.5 - bx)
        sy = ny / 1.12 if ny > 0 else ny
        dist = math.hypot(nx, sy)
        a = 1.0 - smoothstep(env_r - 2.0, env_r + 2.0, dist)
        if a <= 0:
            continue
        tv = clamp((y - (by - env_r)) / (env_r * 2.1))
        col = lerp3((255, 252, 246), (214, 224, 244), tv)
        # rim light upper-left
        rim = clamp(1.0 - math.hypot(nx + env_r * 0.32, ny + env_r * 0.34) / (env_r * 1.25))
        col = lerp3(col, (255, 255, 255), rim * 0.5)
        # soft inner shading lower-right
        sh = clamp(math.hypot(nx - env_r * 0.30, ny - env_r * 0.30) / (env_r * 1.3))
        col = lerp3(col, (188, 200, 224), sh * 0.30)
        blend(x, y, col, a)

# Subtle vertical seam lines on the envelope
for off in (-0.55, -0.28, 0.0, 0.28, 0.55):
    for yy in range(int(by - env_r), int(by + env_r * 1.05)):
        ny = yy + 0.5 - by
        sy = ny / 1.12 if ny > 0 else ny
        half = env_r * math.sqrt(max(0.0, 1 - (sy / env_r) ** 2))
        if half <= 1:
            continue
        sx = bx + off * half
        d = abs(0)  # draw a thin soft vertical mark
        soft = 1.0
        xx = int(round(sx))
        if 0 <= xx < W and 0 <= yy < H:
            blend(xx, yy, (190, 201, 226), 0.18 * soft)

# Cords from envelope base to basket
base_y = by + env_r * 1.05
basket_w, basket_h = 46, 40
basket_cx, basket_cy = bx, base_y + 70
cord_color = (120, 132, 158)
for cx_off in (-basket_w * 0.5, basket_w * 0.5):
    ax, ay = bx + cx_off * 0.7, base_y - 6
    bx2, by2 = basket_cx + cx_off, basket_cy - basket_h * 0.5
    x0 = int(min(ax, bx2) - 3); x1 = int(max(ax, bx2) + 3)
    y0 = int(min(ay, by2) - 3); y1 = int(max(ay, by2) + 3)
    for y in range(max(0, y0), min(H - 1, y1) + 1):
        for x in range(max(0, x0), min(W - 1, x1) + 1):
            dd = seg_dist(x + 0.5, y + 0.5, ax, ay, bx2, by2)
            a = (1.0 - smoothstep(1.2, 2.6, dd)) * 0.65
            if a > 0:
                blend(x, y, cord_color, a)

# Basket (rounded rectangle, warm tone)
bk = (171, 124, 76)
bk_dark = (138, 96, 54)
bx0, bx1 = basket_cx - basket_w / 2, basket_cx + basket_w / 2
by0, by1 = basket_cy - basket_h / 2, basket_cy + basket_h / 2
rad = 12
for y in range(int(by0 - 3), int(by1 + 3)):
    for x in range(int(bx0 - 3), int(bx1 + 3)):
        if not (0 <= x < W and 0 <= y < H):
            continue
        dx = max(bx0 + rad - (x + 0.5), (x + 0.5) - (bx1 - rad), 0)
        dy = max(by0 + rad - (y + 0.5), (y + 0.5) - (by1 - rad), 0)
        d = math.hypot(dx, dy) if (dx > 0 and dy > 0) else max(
            (bx0 - (x + 0.5)), ((x + 0.5) - bx1),
            (by0 - (y + 0.5)), ((y + 0.5) - by1), -rad) + rad
        # simpler coverage: inside rounded rect
        inside_x = bx0 - 1.5 <= x + 0.5 <= bx1 + 1.5
        inside_y = by0 - 1.5 <= y + 0.5 <= by1 + 1.5
        if inside_x and inside_y:
            tv = clamp((y - by0) / basket_h)
            col = lerp3(bk, bk_dark, tv)
            blend(x, y, col, 0.96)


def encode_png(path, width, height, flat):
    out = bytearray()
    for y in range(height):
        out.append(0)  # filter type 0 (None)
        base = y * width * 3
        for x in range(width * 3):
            v = flat[base + x]
            out.append(int(clamp(v, 0, 255) + 0.5))
    compressed = zlib.compress(bytes(out), 9)

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        crc = zlib.crc32(tag + data) & 0xffffffff
        return c + struct.pack(">I", crc)

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)  # 8-bit RGB
    with open(path, "wb") as f:
        f.write(sig)
        f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", compressed))
        f.write(chunk(b"IEND", b""))


out_path = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "FocusGlobe/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png",
)
encode_png(out_path, W, H, buf)
print("Wrote", out_path)
