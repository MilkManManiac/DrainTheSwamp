"""Bake the Gemini tools row (assets/gen/tools-row.*) into per-tool hand sprites.

One image holds one row of 9 items on magenta: spoon, cup, bucket, shovel,
wheelbarrow, barrel, water wagon, hose, lantern. Each is keyed, split by the
magenta gaps (same splitter as bake.py sheet), scaled to its own art height,
quantized and written x2 NEAREST to assets/art/drainsville/tool_<id>.png.

    python tools/bake/bake_tools.py [assets/gen/tools-row.png]

Prints the per-tool size and a suggested grip point (art px) for the TOOLS
table in scripts/player/player_skin.gd. Grip = where the hand holds it:
top-centre for things that hang (bucket, cup, barrel, lantern), a point down
the shaft for the shovel/spoon, the handle end for wheelbarrow/wagon/hose.
"""
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from bake import key_out, quantize, split_frames, split_rows  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art" / "drainsville"
# id, art px height, grip as (fx, fy) fraction of the baked sprite
ORDER = [
    ("spoon", 7, (0.5, 0.15)),
    ("cup", 6, (0.5, 0.1)),
    ("bucket", 8, (0.5, 0.0)),
    ("shovel", 16, (0.5, 0.35)),
    ("wheelbarrow", 11, (0.85, 0.25)),
    ("barrel", 11, (0.5, 0.0)),
    ("water_wagon", 12, (0.5, 0.05)),
    ("hose", 8, (0.4, 0.3)),
    ("lantern", 9, (0.5, 0.0)),
]


def main() -> None:
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else next((ROOT / "assets" / "gen").glob("tools-row.*"))
    img = key_out(Image.open(src), "magenta", 70, True)
    rows = split_rows(img)
    row = max(rows, key=lambda r: r.getchannel("A").getbbox()[2] - r.getchannel("A").getbbox()[0])
    frames = split_frames(row, min_gap=6)
    print(f"[tools] {len(frames)} items found in {src.name} (want {len(ORDER)})")
    if len(frames) < len(ORDER):
        sys.exit("too few items; check the magenta split")
    frames = frames[: len(ORDER)]
    for (tid, h, (fx, fy)), fr in zip(ORDER, frames):
        w = max(1, round(fr.width * h / fr.height))
        small = fr.resize((w, h), Image.Resampling.LANCZOS)
        small = quantize(small, 16)
        out = small.resize((w * 2, h * 2), Image.Resampling.NEAREST)
        out.save(OUT / f"tool_{tid}.png")
        gx, gy = round((w - 1) * fx), round((h - 1) * fy)
        print(f'  "{tid}": {{"tex": "tool_{tid}.png", "grip": Vector2({gx}, {gy})}},   # {w}x{h}')


if __name__ == "__main__":
    main()
