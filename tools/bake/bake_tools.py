"""Bake the Gemini tools row (assets/gen/tools-row.*) into per-tool hand sprites.

One image holds a 5x2 grid of items on magenta: spoon, cup, bucket, shovel,
wheelbarrow / barrel, barrel(dup), water wagon, hose, lantern (Gemini
repeated the barrel; the dup is dropped). Each is keyed, split by the
magenta gaps (same splitter as bake.py sheet), scaled to its own art
height, brightened/saturated so it separates from dark ground, outlined in
the same dark colour as the player sprite, quantized and written x2
NEAREST to assets/art/drainsville/tool_<id>.png.

    python tools/bake/bake_tools.py [assets/gen/tools-row.png]

Prints the per-tool size and a suggested grip point (art px, including the
1px outline border this script adds) for the TOOLS table in
scripts/player/player_skin.gd. Grip = the point that pins to the anchor:
for hand tools, where the hand holds it (top-centre for things that hang,
a point down the shaft for the shovel/spoon, the handle end for
wagon/hose); for ground tools (wheelbarrow, barrel, water_wagon — sized up
2026-09-11 so they read as ground-set props, not hand props), bottom-centre
so they plant on the ground.
"""
import sys
from pathlib import Path

from PIL import Image, ImageEnhance

sys.path.insert(0, str(Path(__file__).resolve().parent))
from bake import key_out, quantize, split_frames, split_rows  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art" / "drainsville"
PLAYER_REF = OUT / "player_a_idle.png"
# id, art px height, grip as (fx, fy) fraction of the un-padded baked sprite,
# ground=True to plant on the ground beside/in front of the player instead
# of following the hand.
ORDER = [
    ("spoon", 14, (0.5, 0.15), False),   # tall+thin source; needs height to keep width legible
    ("cup", 6, (0.5, 0.1), False),
    ("bucket", 8, (0.5, 0.0), False),
    ("shovel", 16, (0.5, 0.35), False),
    ("wheelbarrow", 20, (0.5, 1.0), True),
    ("barrel", 16, (0.5, 1.0), True),
    ("water_wagon", 20, (0.5, 1.0), True),
    ("hose", 10, (0.4, 0.3), False),
    ("lantern", 9, (0.5, 0.0), False),
]
BRIGHTEN = 1.30   # lift value so tools separate from dark ground/shadow
SATURATE = 1.20


def outline_color() -> tuple:
    if not PLAYER_REF.exists():
        return (10, 8, 10, 255)
    im = Image.open(PLAYER_REF).convert("RGBA")
    px = im.load()
    w, h = im.size
    dark = min((px[x, y] for x in range(w) for y in range(h) if px[x, y][3] >= 128),
               key=lambda p: p[0] + p[1] + p[2])
    return (dark[0], dark[1], dark[2], 255)


def lift(img: Image.Image) -> Image.Image:
    rgb = img.convert("RGB")
    rgb = ImageEnhance.Brightness(rgb).enhance(BRIGHTEN)
    rgb = ImageEnhance.Color(rgb).enhance(SATURATE)
    out = rgb.convert("RGBA")
    out.putalpha(img.getchannel("A"))
    return out


def add_outline(img: Image.Image, color: tuple) -> Image.Image:
    """Pad by 1 art px and stroke every transparent pixel touching an opaque
    one, matching the player sprite's outline weight (1 art px, x2 baked)."""
    w, h = img.size
    padded = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    padded.paste(img, (1, 1))
    src = padded.load()
    out = padded.copy()
    dst = out.load()
    pw, ph = padded.size
    for y in range(ph):
        for x in range(pw):
            if src[x, y][3] >= 128:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < pw and 0 <= ny < ph and src[nx, ny][3] >= 128:
                    dst[x, y] = color
                    break
    return out


def main() -> None:
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else next((ROOT / "assets" / "gen").glob("tools-row.*"))
    img = key_out(Image.open(src), "magenta", 70, True)
    rows = split_rows(img)
    frames = []
    for r in rows:
        frames.extend(split_frames(r, min_gap=6))
    print(f"[tools] {len(frames)} items found in {src.name} across {len(rows)} rows (want {len(ORDER)})")
    if len(rows) == 2 and len(frames) == 10:
        frames = frames[:5] + frames[6:]
        print("[tools] dropped duplicate barrel at row1 slot 0")
    if len(frames) < len(ORDER):
        sys.exit("too few items; check the magenta split")
    frames = frames[: len(ORDER)]
    outline = outline_color()
    print(f"[tools] outline colour {outline[:3]} (sampled from {PLAYER_REF.name})")
    for (tid, h, (fx, fy), ground), fr in zip(ORDER, frames):
        w = max(1, round(fr.width * h / fr.height))
        small = fr.resize((w, h), Image.Resampling.LANCZOS)
        small = lift(small)
        small = quantize(small, 16)
        small = add_outline(small, outline)
        out = small.resize(((w + 2) * 2, (h + 2) * 2), Image.Resampling.NEAREST)
        out.save(OUT / f"tool_{tid}.png")
        # +1,+1 for the padding this script adds around the original w x h art.
        gx, gy = round((w - 1) * fx) + 1, round((h - 1) * fy) + 1
        kind = "ground" if ground else "hand"
        print(f'  "{tid}": {{"tex": "tool_{tid}.png", "grip": Vector2({gx}, {gy})}},   # {kind} {w+2}x{h+2}')


if __name__ == "__main__":
    main()
