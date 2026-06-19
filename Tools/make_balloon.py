#!/usr/bin/env python3
"""
Generates the FocusGlobe hero balloon as a transparent RGBA PNG using only the
Python standard library (zlib + struct). No imaging dependencies.

This is the *front-view* brand balloon (white paneled envelope, skirt, warm
burner glow, ropes, tan basket). It populates the BalloonFront imageset so the
app uses a real raster hero asset (and Xcode shows no "unassigned" warning).
Replace BalloonFront.png with the official render anytime — same filename.

Run:  python3 Tools/make_balloon.py
Out:  FocusGlobe/Assets.xcassets/BalloonFront.imageset/BalloonFront.png
"""

import math, os, struct, zlib

W, H = 760, 940


def clamp(x, lo=0.0, hi=1.0): return max(lo, min(hi, x))
def smoothstep(e0, e1, x):
    if e0 == e1: return 0.0 if x < e0 else 1.0
    t = clamp((x - e0) / (e1 - e0)); return t * t * (3 - 2 * t)
def lerp(a, b, t): return a + (b - a) * t
def lerp3(c0, c1, t): return (lerp(c0[0], c1[0], t), lerp(c0[1], c1[1], t), lerp(c0[2], c1[2], t))

# RGBA buffer (premultiplied-free straight alpha)
buf = [0.0] * (W * H * 4)

def blend(x, y, rgb, a):
    if a <= 0: return
    a = clamp(a)
    i = (y * W + x) * 4
    da = buf[i + 3]
    out_a = a + da * (1 - a)
    if out_a <= 0: return
    for k in range(3):
        buf[i + k] = (rgb[k] * a + buf[i + k] * da * (1 - a)) / out_a
    buf[i + 3] = out_a

# Geometry
cx = W / 2
R = 262.0
top = 64.0
cyc = top + R
joinY = cyc + R * 0.33
mouthY = joinY + R * 0.92
mouthHalf = R * 0.17
basketTop = mouthY + 74
bh = 86
basketCY = basketTop + bh / 2
basketHalf = 58

def half_width(y):
    if y < top or y > mouthY: return 0.0
    if y <= joinY:
        v = R * R - (y - cyc) ** 2
        return math.sqrt(v) if v > 0 else 0.0
    u = (y - joinY) / (mouthY - joinY)
    wj = math.sqrt(max(0.0, R * R - (joinY - cyc) ** 2))
    w = lerp(wj, mouthHalf, smoothstep(0, 1, u))
    return w * (1 + 0.04 * math.sin(math.pi * u))  # gentle gather

WHITE = (255, 255, 255)
SOFT = (228, 233, 241)
EDGE = (196, 204, 218)
SEAM = (183, 192, 208)

# ---- Burner glow (drawn first, shows in the mouth gap + spills down) -------
bg_cx, bg_cy, bg_r = cx, mouthY + 14, R * 0.42
gy0, gy1 = int(bg_cy - bg_r), int(bg_cy + bg_r)
gx0, gx1 = int(bg_cx - bg_r), int(bg_cx + bg_r)
for y in range(max(0, gy0), min(H, gy1)):
    for x in range(max(0, gx0), min(W, gx1)):
        d = math.hypot(x + 0.5 - bg_cx, y + 0.5 - bg_cy) / bg_r
        if d >= 1: continue
        warm = lerp3((255, 226, 160), (255, 150, 50), clamp(d * 1.1))
        a = (1 - d) ** 2 * 0.85
        blend(x, y, warm, a)
# bright burner core
for y in range(max(0, int(bg_cy - 60)), min(H, int(bg_cy + 60))):
    for x in range(max(0, int(cx - 60)), min(W, int(cx + 60))):
        d = math.hypot(x + 0.5 - cx, y + 0.5 - (mouthY + 6)) / 46
        if d < 1: blend(x, y, (255, 244, 214), (1 - d) ** 2 * 0.9)

# ---- Envelope -------------------------------------------------------------
for y in range(int(top - 2), int(mouthY + 2)):
    hw = half_width(y)
    if hw <= 0.5: continue
    ty = clamp((y - top) / (mouthY - top))
    x0 = int(cx - hw - 2); x1 = int(cx + hw + 2)
    for x in range(max(0, x0), min(W, x1)):
        dxn = (x + 0.5 - cx)
        edge_d = abs(dxn) - hw
        cov = 1.0 - smoothstep(-1.2, 1.2, edge_d)
        if cov <= 0: continue
        fx = dxn / hw  # -1..1
        col = lerp3(WHITE, SOFT, ty * 0.7)
        # volume shading toward edges
        col = lerp3(col, EDGE, smoothstep(0.45, 1.0, abs(fx)) * 0.5)
        # subtle panel seams
        seam = 0.0
        for s in (-0.66, -0.33, 0.0, 0.33, 0.66):
            seam = max(seam, math.exp(-((fx - s) / 0.05) ** 2))
        col = lerp3(col, SEAM, seam * 0.16)
        # upper-left highlight
        hl = clamp(1 - math.hypot(x - (cx - R * 0.34), y - (top + R * 0.52)) / (R * 0.95))
        col = lerp3(col, (255, 255, 255), hl * 0.5)
        blend(x, y, col, cov)

# ---- Skirt band at the mouth ---------------------------------------------
for y in range(int(mouthY - 4), int(mouthY + 16)):
    for x in range(int(cx - mouthHalf * 1.15), int(cx + mouthHalf * 1.15)):
        if not (0 <= x < W and 0 <= y < H): continue
        if abs(x + 0.5 - cx) <= mouthHalf * 1.1:
            t = clamp((y - (mouthY - 4)) / 20)
            blend(x, y, lerp3((237, 239, 244), (210, 216, 226), t), 0.9)

# ---- Ropes ----------------------------------------------------------------
def seg(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    if dx == 0 and dy == 0: return math.hypot(px - ax, py - ay)
    t = clamp(((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))

ropes = [(-mouthHalf * 0.8, -basketHalf), (mouthHalf * 0.8, basketHalf),
         (-mouthHalf * 0.3, -basketHalf * 0.4), (mouthHalf * 0.3, basketHalf * 0.4)]
for ax_off, bx_off in ropes:
    ax, ay = cx + ax_off, mouthY + 8
    bx, by = cx + bx_off, basketTop
    for y in range(int(ay - 2), int(by + 2)):
        for x in range(int(min(ax, bx) - 2), int(max(ax, bx) + 2)):
            if not (0 <= x < W and 0 <= y < H): continue
            d = seg(x + 0.5, y + 0.5, ax, ay, bx, by)
            blend(x, y, (150, 130, 96), (1 - smoothstep(1.0, 2.2, d)) * 0.7)

# ---- Basket (rounded rect, tan) ------------------------------------------
bx0, bx1 = cx - basketHalf, cx + basketHalf
by0, by1 = basketTop, basketTop + bh
rad = 16
for y in range(int(by0 - 2), int(by1 + 2)):
    for x in range(int(bx0 - 2), int(bx1 + 2)):
        if not (0 <= x < W and 0 <= y < H): continue
        dx = max(bx0 + rad - (x + 0.5), (x + 0.5) - (bx1 - rad), 0)
        dy = max(by0 + rad - (y + 0.5), (y + 0.5) - (by1 - rad), 0)
        d = math.hypot(dx, dy)
        cov = 1 - smoothstep(rad - 1.2, rad + 1.2, d)
        if cov <= 0: continue
        t = clamp((y - by0) / bh)
        blend(x, y, lerp3((199, 154, 106), (138, 96, 56), t), cov)


def encode_rgba(path, width, height, flat):
    out = bytearray()
    for y in range(height):
        out.append(0)
        base = y * width * 4
        for x in range(width * 4):
            out.append(int(clamp(flat[base + x], 0, 255) + 0.5))
    comp = zlib.compress(bytes(out), 9)
    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))
    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)  # 8-bit RGBA
    with open(path, "wb") as f:
        f.write(sig); f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", comp)); f.write(chunk(b"IEND", b""))


out_path = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "FocusGlobe/Assets.xcassets/BalloonFront.imageset/BalloonFront.png")
encode_rgba(out_path, W, H, buf)
print("Wrote", out_path)

# --- Dark-mode preview (not shipped) ---------------------------------------
def _preview(path, bgtop=(10, 14, 26), bgbot=(16, 22, 44)):
    out = bytearray()
    for y in range(H):
        out.append(0)
        ty = y / (H - 1)
        bg = tuple(lerp(bgtop[k], bgbot[k], ty) for k in range(3))
        for x in range(W):
            i = (y * W + x) * 4
            a = buf[i + 3]
            for k in range(3):
                out.append(int(clamp(buf[i + k] * a + bg[k] * (1 - a), 0, 255) + 0.5))
    comp = zlib.compress(bytes(out), 6)
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n"); f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", comp)); f.write(chunk(b"IEND", b""))
_preview("/tmp/balloon_dark.png")
print("preview /tmp/balloon_dark.png")
