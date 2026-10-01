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
# inset slot (dark, warm) — lightened from the original (44,32,26) base so
# cream/parchment row text has real contrast against it (Wes: "PUDDLE PUMP"
# / "BUY $12.50" were dim blue-grey on near-black)
S_BASE = (70, 52, 40)
S_DARK = (52, 38, 30)
S_LIGHT = (96, 74, 58)
# parchment
P_BASE = (214, 190, 142)
P_DARK = (190, 164, 116)
P_LIGHT = (232, 212, 168)
P_LINE = (156, 126, 84)
# content surface: light warm wood the rows sit on, between S_LIGHT and
# parchment in value — the middle step of frame(dark) > content(light) > row(lighter)
C_BASE = (150, 118, 82)
C_DARK = (124, 96, 64)
C_LIGHT = (176, 144, 104)
# row card: lightest surface, a raised chip each row sits on
R_BASE = (192, 160, 116)
R_DARK = (162, 130, 90)
R_LIGHT = (214, 186, 144)
# brass rivet accent for frame corners
BRASS = (196, 158, 74)
BRASS_HI = (232, 200, 120)


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


def panel_frame(size=28):
    """Darker outer frame than panel_wood, thicker border, brass corner rivets —
    the outermost of the three surfaces (frame > content > row) so a dialog
    reads as layered instead of one flat plank everywhere."""
    img = new(size, size)
    plank_fill(img, 2, 2, size - 3, size - 3, seed=11, base=W_DARK, light=W_MID, dark=(44, 30, 18), line=(24, 16, 10), step=7)
    d = ImageDraw.Draw(img)
    # thick dark border, 2px
    d.rectangle((0, 0, size - 1, size - 1), outline=OUTLINE)
    d.rectangle((1, 1, size - 2, size - 2), outline=(18, 12, 8))
    d.line((2, 2, size - 3, 2), fill=W_MID)
    d.line((2, 2, 2, size - 3), fill=W_MID)
    # brass rivets, one per corner, inset by 4px
    for cx, cy in [(4, 4), (size - 5, 4), (4, size - 5), (size - 5, size - 5)]:
        d.point([(cx, cy), (cx + 1, cy), (cx, cy + 1), (cx + 1, cy + 1)], fill=BRASS)
        d.point([(cx, cy)], fill=BRASS_HI)
    return img


def panel_content(size=16):
    """Lighter content surface (shop scroll area, popup body backdrop) — the
    middle step between the dark frame and the lighter row cards."""
    img = new(size, size)
    d = ImageDraw.Draw(img)
    rect(d, 0, 0, size - 1, size - 1, C_BASE)
    rng = random.Random(21)
    for _ in range(size * 2):
        img.putpixel((rng.randint(1, size - 2), rng.randint(1, size - 2)), C_DARK if rng.random() < 0.6 else C_LIGHT)
    d.rectangle((0, 0, size - 1, size - 1), outline=(40, 28, 18))
    d.line((1, 1, size - 2, 1), fill=C_DARK)
    d.line((1, 1, 1, size - 2), fill=C_DARK)
    return img


def row_card(size=12, active=False, locked=False):
    """A single shop/list row as its own raised chip — lightest of the three
    surfaces. `active` (equipped/selected) gets a bright left accent edge;
    `locked` is desaturated and darker so it visibly recedes."""
    img = new(size, size)
    d = ImageDraw.Draw(img)
    if locked:
        base, light, dark = (108, 96, 84), (128, 114, 100), (86, 76, 66)
    else:
        base, light, dark = R_BASE, R_LIGHT, R_DARK
    rect(d, 0, 0, size - 1, size - 1, base)
    d.line((0, 0, size - 1, 0), fill=light)
    d.line((0, 0, 0, size - 1), fill=light)
    d.line((0, size - 1, size - 1, size - 1), fill=dark)
    d.rectangle((0, 0, size - 1, size - 1), outline=(40, 28, 18))
    if active:
        # bright accent stripe down the left edge
        d.line((0, 0, 0, size - 1), fill=(110, 226, 130))
        d.line((1, 0, 1, size - 1), fill=(70, 180, 95))
    return img


def scroll_grabber(w=7, h=14):
    """Dedicated vertical scrollbar handle (was reusing the square button
    texture stretched thin, which read as an unskinned/raw scrollbar)."""
    img = new(w, h)
    d = ImageDraw.Draw(img)
    rect(d, 0, 0, w - 1, h - 1, R_BASE)
    d.line((0, 0, w - 1, 0), fill=R_LIGHT)
    d.line((0, 0, 0, h - 1), fill=R_LIGHT)
    d.line((0, h - 1, w - 1, h - 1), fill=R_DARK)
    d.line((w - 1, 0, w - 1, h - 1), fill=R_DARK)
    d.rectangle((0, 0, w - 1, h - 1), outline=OUTLINE)
    for y in range(4, h - 4, 3):
        d.point((w // 2, y), fill=R_DARK)
    return img


def slider_grabber(size=8, highlight=False):
    """Small brass/wood knob for HSlider (replaces the default smooth white
    circle, which read as programmer art next to the baked wood panels)."""
    img = new(size, size)
    d = ImageDraw.Draw(img)
    if highlight:
        base, light, dark = (214, 176, 100), (238, 210, 144), (150, 112, 58)
    else:
        base, light, dark = (176, 140, 70), (206, 172, 102), (110, 82, 40)
    d.ellipse((0, 0, size - 1, size - 1), fill=base, outline=OUTLINE)
    d.point([(2, 2), (3, 2), (2, 3)], fill=light)
    d.point([(size - 3, size - 2), (size - 2, size - 3), (size - 3, size - 3)], fill=dark)
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
        # Deepened vs. "normal" (was W_MID, too close in value to W_BASE) so a
        # pressed/active tab visibly recedes instead of nearly matching raised
        # tabs next to it.
        base, light, dark, hi = W_DARK, W_MID, (28, 18, 10), W_MID
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


SRC = Path(__file__).resolve().parent.parent.parent / "assets" / "art" / "drainsville"

TOOL_ICON_SOURCES = {
    "spoon": "tool_spoon.png",
    "cup": "tool_cup.png",
    "bucket": "tool_bucket.png",
    "shovel": "tool_shovel.png",
    "wheelbarrow": "tool_wheelbarrow.png",
    "barrel": "tool_barrel.png",
    "water_wagon": "tool_water_wagon.png",
    "hose": "tool_hose.png",
}


def tool_icon(tool_id, size=13):
    """Small square UI icon baked from the player track's in-hand tool sprite
    (assets/art/drainsville/tool_*.png — elongated held-tool shapes), scaled
    to fit a square icon slot with a 1px dark outline ring so it reads at
    HUD/shop-row size instead of at in-hand scale."""
    src_path = SRC / TOOL_ICON_SOURCES[tool_id]
    src = Image.open(src_path).convert("RGBA")
    bbox = src.getbbox()
    if bbox:
        src = src.crop(bbox)
    inner = size - 2
    scale = min(inner / src.width, inner / src.height)
    new_w = max(1, round(src.width * scale))
    new_h = max(1, round(src.height * scale))
    scaled = src.resize((new_w, new_h), Image.NEAREST)
    img = new(size, size)
    ox = (size - new_w) // 2
    oy = (size - new_h) // 2
    # 1px outline ring: stamp the alpha mask shifted 4 ways in outline colour first
    mask = scaled.split()[3]
    for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        ring = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        ring.paste(Image.new("RGBA", (new_w, new_h), OUTLINE + (255,)), (ox + dx, oy + dy), mask)
        img.alpha_composite(ring)
    img.alpha_composite(scaled, (ox, oy))
    return img


def hands_icon(size=13):
    """Baked, not baked-from-source: no bare-hands sprite exists on the
    player track (it's the implicit default, no held prop). Small mitten
    silhouette in the same outline language as the tool icons."""
    img = new(size, size)
    d = ImageDraw.Draw(img)
    skin, skin_hi = (198, 150, 110), (222, 178, 136)
    d.ellipse((3, 4, 9, 11), fill=skin, outline=OUTLINE)
    d.ellipse((3, 3, 6, 6), fill=skin_hi)
    for fx in (4, 6, 8):
        d.line((fx, 4, fx, 1), fill=skin, width=2)
    d.rectangle((3, 1, 4, 3), fill=skin)
    d.rectangle((5, 1, 6, 3), fill=skin)
    d.rectangle((7, 1, 8, 3), fill=skin)
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
        "panel_frame.png": panel_frame(28),
        "panel_content.png": panel_content(16),
        "row_card.png": row_card(12, active=False),
        "row_card_active.png": row_card(12, active=True),
        "row_card_locked.png": row_card(12, locked=True),
        "btn_normal.png": button("normal"),
        "btn_hover.png": button("hover"),
        "btn_pressed.png": button("pressed"),
        "btn_disabled.png": button("disabled"),
        "bar_frame.png": bar_frame(8),
        "bar_fill.png": bar_fill(),
        "slider_grabber.png": slider_grabber(8, False),
        "slider_grabber_hi.png": slider_grabber(8, True),
        "scroll_grabber.png": scroll_grabber(),
        "touch_left.png": touch_button("left", 40, False),
        "touch_left_p.png": touch_button("left", 40, True),
        "touch_right.png": touch_button("right", 40, False),
        "touch_right_p.png": touch_button("right", 40, True),
        "touch_scoop.png": touch_button("scoop", 56, False),
        "touch_scoop_p.png": touch_button("scoop", 56, True),
    }
    for n in ICONS:
        files[f"icon_{n}.png"] = icon(n)
    for tid in TOOL_ICON_SOURCES:
        files[f"icon_tool_{tid}.png"] = tool_icon(tid)
    files["icon_tool_hands.png"] = hands_icon()
    for name, img in files.items():
        img.save(OUT / name)
        print(f"[ui_kit] {name} {img.width}x{img.height}")


if __name__ == "__main__":
    main()
