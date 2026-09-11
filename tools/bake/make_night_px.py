"""Hand-baked night pixel textures (stars, firefly core, soft glow disc).

These are too small for Gemini (1-3 art px); drawn here so the grid and palette
are exact. Output is x2 NEAREST like every other bake (1 art px = 2 texels).

    python tools/bake/make_night_px.py
"""
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parents[2] / "assets" / "art" / "drainsville"


def px_image(rows, palette):
    h, w = len(rows), len(rows[0])
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    p = im.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                p[x, y] = palette[ch]
    return im.resize((w * 2, h * 2), Image.NEAREST)


WHITE = (255, 250, 235, 255)
WARM = (255, 232, 190, 255)
COOL = (205, 225, 255, 255)
DIM = (255, 250, 235, 150)

# star_1: one pixel; star_2: 2x2 block; star_3: 3px cross with dim arms.
px_image(["#"], {"#": WHITE}).save(OUT / "star_1.png")
px_image(["##", "##"], {"#": COOL}).save(OUT / "star_2.png")
px_image([".d.", "d#d", ".d."], {"#": WHITE, "d": DIM}).save(OUT / "star_3.png")
px_image([".d.", "d#d", ".d."], {"#": WARM, "d": (255, 232, 190, 140)}).save(OUT / "star_3w.png")

# firefly core: 2x2 pale yellow-green with a brighter centre pixel top-left.
FF = (230, 255, 150, 255)
FF2 = (170, 230, 90, 255)
px_image(["#c", "cc"], {"#": FF, "c": FF2}).save(OUT / "firefly.png")

# cricket chirp pixel (used by critters.gd for the chirp flash)
px_image(["#"], {"#": (255, 245, 140, 255)}).save(OUT / "chirp_px.png")

# soft glow disc, 16 art px, radial falloff, drawn on the art grid (no bilinear)
size = 16
im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
p = im.load()
c = (size - 1) / 2.0
for y in range(size):
    for x in range(size):
        d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5 / (size / 2.0)
        a = max(0.0, 1.0 - d) ** 2
        # stepped alpha so the glow reads as pixel rings, not a smooth blur
        a = round(a * 6) / 6.0
        p[x, y] = (255, 255, 255, int(a * 255))
im.resize((size * 2, size * 2), Image.NEAREST).save(OUT / "glow_16.png")

# tadpole: 2-frame strip, round body + curved tail wagging left/right
TAD = (35, 38, 20, 255)
TAD_HL = (70, 78, 40, 220)
tad_a = px_image([
    "..##...",
    ".####..",
    ".####t.",
    "..##.tt",
], {"#": TAD, "t": TAD_HL})
tad_b = px_image([
    "..##...",
    ".####..",
    ".t####.",
    "tt##...",
], {"#": TAD, "t": TAD_HL})
strip = Image.new("RGBA", (tad_a.width + tad_b.width, tad_a.height), (0, 0, 0, 0))
strip.paste(tad_a, (0, 0))
strip.paste(tad_b, (tad_a.width, 0))
strip.save(OUT / "tadpole.png")

print("wrote star_1/2/3/3w, firefly, chirp_px, glow_16, tadpole to", OUT)
