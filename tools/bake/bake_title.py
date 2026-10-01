"""Bake the title screen's UI art: pixel wordmark + 9-slice button frames.

    python tools/bake/bake_title.py

Everything is drawn on the art grid (1 art px = 2 screen px at 720p), then the
logo is written x2 NEAREST (placed as a Sprite2D at scale 0.5, like every other
sprite) and the button frames are written at art size (StyleBoxTexture draws in
logical px, and 1 logical px = 1 art px on the 640x360 canvas).
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent.parent
FONT = ROOT / "assets/fonts/Silkscreen-Regular.ttf"
OUT = ROOT / "assets/art/title"
OUT.mkdir(parents=True, exist_ok=True)

OUTLINE = (34, 22, 16, 255)
SHADOW = (12, 8, 6, 255)


def text_mask(text: str, size: int) -> Image.Image:
    f = ImageFont.truetype(str(FONT), size)
    l, t, r, b = f.getbbox(text)
    m = Image.new("L", (r - l, b - t), 0)
    ImageDraw.Draw(m).text((-l, -t), text, font=f, fill=255)
    # Silkscreen is a bitmap-style font; snap any AA to hard pixels
    return m.point(lambda v: 255 if v >= 128 else 0)


def two_tone(mask: Image.Image, top, bottom, split: float, highlight=None) -> Image.Image:
    """Fill a mask with two flat tones split at `split` (0..1 of height)."""
    w, h = mask.size
    fill = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(fill)
    ys = int(h * split)
    d.rectangle((0, 0, w, ys - 1), fill=top)
    d.rectangle((0, ys, w, h), fill=bottom)
    if highlight:
        d.rectangle((0, 0, w, 0), fill=highlight)   # 1px top highlight row
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(fill, (0, 0), mask)
    return out


def outlined(layer: Image.Image, outline=OUTLINE, shadow=SHADOW, shadow_off=(2, 2)) -> Image.Image:
    """1px outline in every direction + a hard drop shadow."""
    w, h = layer.size
    pad = 1 + max(shadow_off)
    canvas = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    a = layer.getchannel("A")
    sol_out = Image.new("RGBA", layer.size, outline)
    sol_sh = Image.new("RGBA", layer.size, shadow)
    # shadow: outline shape offset
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            canvas.paste(sol_sh, (pad + dx + shadow_off[0], pad + dy + shadow_off[1]), a)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            canvas.paste(sol_out, (pad + dx, pad + dy), a)
    canvas.paste(layer, (pad, pad), a)
    return canvas


def bake_logo() -> None:
    line1 = two_tone(text_mask("DRAIN THE", 24), (246, 226, 170, 255), (222, 168, 84, 255), 0.5, (255, 246, 214, 255))
    line2 = two_tone(text_mask("SWAMP", 48), (166, 204, 96, 255), (84, 132, 60, 255), 0.5, (204, 230, 140, 255))
    l1 = outlined(line1)
    l2 = outlined(line2)
    gap = 2
    w = max(l1.width, l2.width)
    h = l1.height + gap + l2.height
    logo = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    logo.paste(l1, ((w - l1.width) // 2, 0), l1)
    logo.paste(l2, ((w - l2.width) // 2, l1.height + gap), l2)
    x2 = logo.resize((logo.width * 2, logo.height * 2), Image.Resampling.NEAREST)
    x2.save(OUT / "logo.png")
    print("logo", logo.size, "-> x2", x2.size)


def plank_frame(size: int, fill, fill2, edge, light, dark, grain: bool = True) -> Image.Image:
    """A wooden 9-slice tile: 1px dark outline, 1px light bevel, plank fill."""
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, size - 1, size - 1), fill=fill, outline=edge)
    d.rectangle((1, 1, size - 2, size - 2), outline=light)
    d.line((1, size - 2, size - 2, size - 2), fill=dark)      # bottom shade
    d.line((size - 2, 1, size - 2, size - 2), fill=dark)      # right shade
    d.rectangle((2, 2, size - 3, size - 3), fill=fill)
    if not grain:
        return im
    # plank grain: horizontal seams every 4px, staggered nail-ish dots
    for y in range(5, size - 3, 4):
        d.line((2, y, size - 3, y), fill=fill2)
    px = im.load()
    for y in range(3, size - 3):
        for x in range(3, size - 3):
            if (x * 7 + y * 13) % 11 == 0:
                px[x, y] = fill2
    return im


def bake_buttons() -> None:
    S = 12
    variants = {
        "btn_normal": ((92, 62, 38), (74, 48, 30), (30, 20, 14), (132, 94, 58), (58, 38, 24)),
        "btn_hover": ((118, 80, 46), (96, 64, 38), (30, 20, 14), (196, 154, 84), (74, 48, 30)),
        "btn_pressed": ((66, 44, 28), (52, 34, 22), (30, 20, 14), (74, 48, 30), (40, 26, 16)),
        "btn_disabled": ((60, 52, 44), (50, 44, 38), (30, 26, 22), (80, 72, 62), (44, 38, 32)),
        "panel_paper": ((228, 214, 176), (214, 198, 158), (58, 44, 32), (244, 234, 204), (186, 168, 128)),
    }
    for name, (fill, fill2, edge, light, dark) in variants.items():
        im = plank_frame(S, fill + (255,), fill2 + (255,), edge + (255,), light + (255,), dark + (255,), grain=not name.startswith("panel"))
        im.save(OUT / f"{name}.png")
        print(name, im.size)


if __name__ == "__main__":
    bake_logo()
    bake_buttons()


# --- key art: split the Gemini plate into sky + foreground ------------------
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from bake import quantize  # noqa: E402

KEY_SRC = ROOT / "assets/gen/title-key-b.jpg"
ART_W, ART_H = 640, 360


def bake_key_art() -> None:
    src = Image.open(KEY_SRC).convert("RGB").resize((ART_W, ART_H), Image.Resampling.LANCZOS)
    px = src.load()
    # The sky is flat horizontal bands; sample a clean column (between the moss
    # and the tower) per row to get the band colour, extend it full width.
    ref_x = 330
    horizon = 224          # art px; below this everything is foreground (town / water)
    band = [px[ref_x, y] for y in range(ART_H)]
    sky = Image.new("RGB", (ART_W, ART_H))
    sp = sky.load()
    for y in range(ART_H):
        c = band[min(y, horizon)]
        for x in range(ART_W):
            sp[x, y] = c
    fg = src.convert("RGBA")
    fp = fg.load()
    # Flood-fill the sky from the top edge through band-coloured (or star) pixels
    # so enclosed patches inside shack walls that happen to match a band stay put.
    def passable(x, y):
        r, g, b, _ = fp[x, y]
        br, bg_, bb = band[y]
        return abs(r - br) + abs(g - bg_) + abs(b - bb) < 60 or min(r, g, b) > 150
    seen = bytearray(ART_W * horizon)
    stack = [(x, 0) for x in range(ART_W) if passable(x, 0)]
    keyed = 0
    while stack:
        x, y = stack.pop()
        i = y * ART_W + x
        if seen[i]:
            continue
        seen[i] = 1
        r, g, b, _ = fp[x, y]
        fp[x, y] = (r, g, b, 0)
        keyed += 1
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < ART_W and 0 <= ny < horizon and not seen[ny * ART_W + nx] and passable(nx, ny):
                stack.append((nx, ny))
    print(f"key art: keyed {keyed} sky px above y={horizon}")
    sky_q = quantize(sky.convert("RGBA"), 16)
    fg_q = quantize(fg, 40)
    # Night version of the same band sky: the game's sky_night plate sampled as a
    # vertical gradient, so the title's slow crossfade lands on the overworld's night.
    night_src = Image.open(ROOT / "assets/art/drainsville/sky_night.png").convert("RGB")
    npx = night_src.load()
    night = Image.new("RGB", (ART_W, ART_H))
    nq = night.load()
    for y in range(ART_H):
        sy = min(night_src.height - 1, int(y * (night_src.height - 1) / (horizon + 12)))
        c = npx[night_src.width // 2, sy]
        for x in range(ART_W):
            nq[x, y] = c
    night_q = quantize(night.convert("RGBA"), 16)
    for name, im in (("key_sky", sky_q), ("key_fg", fg_q), ("key_sky_night", night_q)):
        x2 = im.resize((im.width * 2, im.height * 2), Image.Resampling.NEAREST)
        x2.save(OUT / f"{name}.png")
        print(name, x2.size)
    # preview: sky + fg composited, to check the key
    prev = sky_q.copy()
    prev.alpha_composite(fg_q)
    prev.save(ROOT / "_screenshots/revamp-2026-09-11/title/_bake_preview.png")


if __name__ == "__main__":
    bake_key_art()
