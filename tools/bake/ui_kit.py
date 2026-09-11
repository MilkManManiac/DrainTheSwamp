"""Draw the pixel UI kit (9-slice panels, buttons, bars, icons, touch buttons).

    python tools/bake/ui_kit.py            # writes assets/art/ui/*.png

The UI viewport is 640x360 stretched x2 to 1280x720, so 1 UI px = 1 art px =
2 screen px: these textures are used at scale 1 in Control nodes (no x2 pass).
Palette is sampled from the town sprites (boardwalk / house wood) so the HUD
sits next to the pack art. Deterministic; re-run after editing.
"""
import random
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent.parent / "assets" / "art" / "ui"

# wood (boardwalk.png / house_a.png)
OUTLINE = (30, 20, 14)
W_DARK = (60, 40, 24)
W_MID = (88, 60, 36)
W_BASE = (112, 78, 46)
W_LIGHT = (150, 110, 70)
W_HI = (176, 136, 90)
# inset slot (dark, warm)
S_BASE = (44, 32, 26)
S_DARK = (34, 24, 20)
S_LIGHT = (66, 48, 38)
# parchment
P_BASE = (214, 190, 142)
P_DARK = (190, 164, 116)
P_LIGHT = (232, 212, 168)
P_LINE = (156, 126, 84)


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def rect(d, x0, y0, x1, y1, c):
    d.rectangle((x0, y0, x1, y1), fill=c)


def plank_fill(img, x0, y0, x1, y1, seed=1, base=W_BASE, light=W_LIGHT, dark=W_MID, line=W_DARK, step=6):
    """Horizontal planks with a lighter top edge and a dark seam every `step` px."""
    d = ImageDraw.Draw(img)
    rng = random.Random(seed)
    rect(d, x0, y0, x1, y1, base)
    y = y0
    while y <= y1:
        # plank top highlight
        d.line((x0, y, x1, y), fill=light)
        # seam
        if y + step - 1 <= y1:
            d.line((x0, y + step - 1, x1, y + step - 1), fill=line)
            d.line((x0, y + step - 2, x1, y + step - 2), fill=dark)
        # grain flecks
        for _ in range((x1 - x0) // 5):
            gx = rng.randint(x0, x1)
            gy = rng.randint(y + 1, min(y + step - 3, y1))
            img.putpixel((gx, gy), dark if rng.random() < 0.6 else light)
        y += step


def outline(d, w, h, c=OUTLINE):
    d.rectangle((0, 0, w - 1, h - 1), outline=c)


def panel_wood(size=24):
    img = new(size, size)
    plank_fill(img, 1, 1, size - 2, size - 2, seed=3)
    d = ImageDraw.Draw(img)
    # bevel: light top/left inside the outline, dark bottom/right
    d.line((1, 1, size - 2, 1), fill=W_HI)
    d.line((1, 1, 1, size - 2), fill=W_LIGHT)
    d.line((1, size - 2, size - 2, size - 2), fill=W_DARK)
    d.line((size - 2, 1, size - 2, size - 2), fill=W_DARK)
    outline(d, size, size)
    return img


def panel_inset(size=12):
    img = new(size, size)
    d = ImageDraw.Draw(img)
    rect(d, 0, 0, size - 1, size - 1, S_BASE)
    d.rectangle((0, 0, size - 1, size - 1), outline=OUTLINE)
    d.line((1, 1, size - 2, 1), fill=S_DARK)
    d.line((1, 1, 1, size - 2), fill=S_DARK)
    d.line((1, size - 2, size - 2, size - 2), fill=S_LIGHT)
    d.line((size - 2, 1, size - 2, size - 2), fill=S_LIGHT)
    return img


def panel_parchment(size=16):
    img = new(size, size)
    d = ImageDraw.Draw(img)
    rect(d, 0, 0, size - 1, size - 1, P_BASE)
    rng = random.Random(7)
    for _ in range(size * 2):
        img.putpixel((rng.randint(1, size - 2), rng.randint(1, size - 2)), P_DARK if rng.random() < 0.7 else P_LIGHT)
    d.rectangle((0, 0, size - 1, size - 1), outline=P_LINE)
    d.rectangle((1, 1, size - 2, size - 2), outline=P_LIGHT)
    return img


def button(state, size=16):
    img = new(size, size)
    d = ImageDraw.Draw(img)
    if state == "disabled":
        base, light, dark, hi = (70, 58, 46), (86, 72, 58), (52, 42, 34), (92, 78, 62)
    elif state == "hover":
        base, light, dark, hi = W_LIGHT, W_HI, W_MID, (200, 160, 110)
    elif state == "pressed":
        base, light, dark, hi = W_MID, W_BASE, W_DARK, W_BASE
    else:
        base, light, dark, hi = W_BASE, W_LIGHT, W_MID, W_HI
    rect(d, 1, 1, size - 2, size - 2, base)
    # subtle grain
    for y in range(3, size - 3, 4):
        d.line((3, y, size - 4, y), fill=dark if state != "pressed" else base)
    if state == "pressed":
        # bevel flipped: dark top/left, light bottom
        d.line((1, 1, size - 2, 1), fill=dark)
        d.line((1, 2, size - 2, 2), fill=dark)
        d.line((1, 1, 1, size - 2), fill=dark)
        d.line((1, size - 2, size - 2, size - 2), fill=light)
        d.line((size - 2, 1, size - 2, size - 2), fill=light)
    else:
        d.line((1, 1, size - 2, 1), fill=hi)
        d.line((1, 1, 1, size - 2), fill=light)
        d.line((1, size - 2, size - 2, size - 2), fill=dark)
        d.line((1, size - 3, size - 2, size - 3), fill=dark)
        d.line((size - 2, 1, size - 2, size - 2), fill=dark)
    outline(d, size, size)
    return img


def bar_frame(size=8):
    img = new(size, size)
    d = ImageDraw.Draw(img)
    rect(d, 0, 0, size - 1, size - 1, S_DARK)
    d.rectangle((0, 0, size - 1, size - 1), outline=OUTLINE)
    d.line((1, 1, size - 2, 1), fill=(22, 16, 12))
    d.line((1, 1, 1, size - 2), fill=(22, 16, 12))
    return img


def bar_fill(w=4, h=8):
    """One segment: 3 px of white fill (modulated in-engine) + 1 px divider."""
    img = new(w, h)
    d = ImageDraw.Draw(img)
    rect(d, 0, 0, w - 2, h - 1, (255, 255, 255))
    d.line((0, 0, w - 2, 0), fill=(255, 255, 255))
    d.line((0, h - 1, w - 2, h - 1), fill=(150, 150, 150))
    d.line((0, h - 2, w - 2, h - 2), fill=(190, 190, 190))
    d.line((w - 1, 0, w - 1, h - 1), fill=(70, 70, 70))
    return img


# --- icons (9x9, dark outline, x = outline, letters = colours) ---
ICONS = {
    "coin": (
        "...xxx...",
        ".xxYYYxx.",
        ".xYYyYYx.",
        "xYYyOyYYx",
        "xYyOOOyYx",
        "xYYyOyYYx",
        ".xYYyYYx.",
        ".xxYYYxx.",
        "...xxx...",
    ),
    "bag": (
        "...xxx...",
        "..xBBBx..",
        ".xxBBBxx.",
        "xBbbbbbBx",
        "xBbbbbbBx",
        "xBbbbbbBx",
        "xBbbbbbBx",
        ".xBbbbBx.",
        "..xxxxx..",
    ),
    "sun": (
        "x...x...x",
        ".x.xxx.x.",
        "..xSSSx..",
        ".xSssssSx",
        "xxSsSsSxx",
        ".xSssssSx",
        "..xSSSx..",
        ".x.xxx.x.",
        "x...x...x",
    ),
    "moon": (
        "...xxxx..",
        "..xMMMMx.",
        ".xMMmxxx.",
        ".xMmx....",
        "xMMx.....",
        ".xMmx....",
        ".xMMmxxx.",
        "..xMMMMx.",
        "...xxxx..",
    ),
    "drop": (
        "....x....",
        "...xWx...",
        "...xWx...",
        "..xWwWx..",
        "..xWwWx..",
        ".xWwwWWx.",
        ".xWwwWWx.",
        "..xWWWx..",
        "...xxx...",
    ),
    "bolt": (
        "....xxx..",
        "...xGGx..",
        "..xGGx...",
        ".xGGGxxx.",
        ".xxGGGGx.",
        "...xGGx..",
        "..xGGx...",
        "..xGx....",
        "..xx.....",
    ),
    "air": (
        "...xxx...",
        "..xAAAx..",
        ".xAaAAAx.",
        ".xaAAAAx.",
        ".xAAAAAx.",
        "..xAAAx..",
        "...xxx...",
        ".xx..xx..",
        "xAx.xAx..",
    ),
}
ICON_COL = {
    "x": OUTLINE,
    "Y": (236, 196, 72), "y": (200, 150, 40), "O": (160, 110, 30),
    "B": (150, 100, 56), "b": (118, 76, 40),
    "S": (240, 200, 90), "s": (255, 236, 150),
    "M": (220, 226, 200), "m": (170, 180, 160),
    "W": (90, 160, 220), "w": (170, 220, 250),
    "G": (120, 220, 90),
    "A": (120, 210, 230), "a": (220, 245, 250),
}


def icon(name):
    rows = ICONS[name]
    img = new(len(rows[0]), len(rows))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                img.putpixel((x, y), ICON_COL[ch] + (255,))
    return img


def touch_button(kind, size, pressed):
    img = new(size, size)
    plank_fill(img, 1, 1, size - 2, size - 2, seed=5, base=W_MID if pressed else W_BASE,
               light=W_BASE if pressed else W_LIGHT, dark=W_DARK, line=W_DARK, step=8)
    d = ImageDraw.Draw(img)
    if pressed:
        d.line((1, 1, size - 2, 1), fill=W_DARK)
        d.line((1, 1, 1, size - 2), fill=W_DARK)
    else:
        d.line((1, 1, size - 2, 1), fill=W_HI)
        d.line((1, 1, 1, size - 2), fill=W_LIGHT)
        d.line((1, size - 2, size - 2, size - 2), fill=W_DARK)
        d.line((1, size - 3, size - 2, size - 3), fill=W_DARK)
        d.line((size - 2, 1, size - 2, size - 2), fill=W_DARK)
    outline(d, size, size)
    c = size // 2
    glyph = (240, 226, 190)
    if kind in ("left", "right"):
        # chunky arrow, 5 px wide head + 2 px shaft
        s = 1 if kind == "right" else -1
        for i in range(7):
            x = c + s * (6 - i)
            rect(d, x, c - i, x, c + i, OUTLINE)
        for i in range(6):
            x = c + s * (5 - i)
            rect(d, x, c - i, x, c + i, glyph)
        rect(d, c - 7 if s > 0 else c, c - 2, c if s > 0 else c + 7, c + 2, OUTLINE)
        rect(d, c - 6 if s > 0 else c, c - 1, c if s > 0 else c + 6, c + 1, glyph)
    elif kind == "scoop":
        # bucket silhouette above the SCOOP label (label is a Silkscreen child in-engine)
        bx0, bx1, by0, by1 = c - 10, c + 10, c - 14, c + 2
        d.polygon([(bx0, by0), (bx1, by0), (bx1 - 3, by1), (bx0 + 3, by1)], fill=OUTLINE)
        d.polygon([(bx0 + 1, by0 + 1), (bx1 - 1, by0 + 1), (bx1 - 4, by1 - 1), (bx0 + 4, by1 - 1)], fill=(150, 150, 160))
        d.line((bx0 + 5, by0 + 2, bx0 + 5, by1 - 3), fill=(200, 200, 210))
        d.rectangle((bx0 - 1, by0 - 1, bx1 + 1, by0 + 1), fill=OUTLINE)
        d.line((bx0, by0, bx1, by0), fill=(200, 200, 210))
        d.arc((bx0 + 2, by0 - 9, bx1 - 2, by0 + 3), 180, 360, fill=OUTLINE, width=2)
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    files = {
        "panel_wood.png": panel_wood(24),
        "panel_inset.png": panel_inset(12),
        "panel_parchment.png": panel_parchment(16),
        "btn_normal.png": button("normal"),
        "btn_hover.png": button("hover"),
        "btn_pressed.png": button("pressed"),
        "btn_disabled.png": button("disabled"),
        "bar_frame.png": bar_frame(8),
        "bar_fill.png": bar_fill(),
        "touch_left.png": touch_button("left", 40, False),
        "touch_left_p.png": touch_button("left", 40, True),
        "touch_right.png": touch_button("right", 40, False),
        "touch_right_p.png": touch_button("right", 40, True),
        "touch_scoop.png": touch_button("scoop", 56, False),
        "touch_scoop_p.png": touch_button("scoop", 56, True),
    }
    for n in ICONS:
        files[f"icon_{n}.png"] = icon(n)
    for name, img in files.items():
        img.save(OUT / name)
        print(f"[ui_kit] {name} {img.width}x{img.height}")


if __name__ == "__main__":
    main()
