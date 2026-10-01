"""Build the scoop bend strip from the APPROVED idle frame, not from the
Gemini scoop-sheet source (2026-09-11 round 3: the Gemini-sourced bend
frame read as a different character — different lighting/palette, a red
blob eating the head/shoulder, no hat/face — because it came from a
separate generation. Same pixels + same palette as idle guarantees the
same character.)

Takes player_a_idle.png frame 0 at ART resolution (post /2 of the x2 bake)
and produces 3 frames: upright (unchanged, transition), bend, low — each a
pixel-shifted copy of idle: the head/torso/arm block moves down + forward
(toward the direction the sheet faces, i.e. -x) while the lower legs/boots
stay planted, and the front arm/hand shifts an extra amount beyond the
torso so it reads as reaching down. No new colours are introduced — every
pixel is a translated idle pixel — so the palette matches exactly.

    python tools/bake/build_scoop_from_idle.py

Writes assets/art/drainsville/player_a_scoop.png (3 frames, x2 NEAREST,
same cell height as idle/walk).
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets" / "art" / "drainsville"
IDLE = ART / "player_a_idle.png"
OUT = ART / "player_a_scoop.png"

# Row (art px, in the un-shifted frame) at/below which legs+boots stay
# planted — everything above this line is "upper body" and moves.
LEG_SPLIT_Y = 30
# Front arm/hand sub-region (art px box, in the un-shifted frame) that gets
# an extra shift on top of the torso shift so the reaching arm leads the
# bend. Left side of the frame — the sheet faces left, HAND["a"]["idle"]
# sits around x=0-6 — matches the tool-holding hand.
ARM_BOX = (0, 11, 8, 28)  # l, t, r, b

# (torso dx, torso dy, extra arm dx, extra arm dy) per generated frame.
# Frame 0 is idle itself (unshifted) — SCOOP_ORDER never plays it, it's a
# clean transition frame. 1 = "bend", 2 = "low", matching SCOOP_ORDER's
# [1, 2, 2, 1] bend/low/low/bend in player_skin.gd.
FRAMES = [
    (0, 0, 0, 0),
    (-2, 3, -1, 2),
    (-3, 5, -2, 3),
]


def shift(img: Image.Image, dx: int, dy: int) -> Image.Image:
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (dx, dy), img)
    return out


def build_frame(art0: Image.Image, torso_dx: int, torso_dy: int, arm_dx: int, arm_dy: int) -> Image.Image:
    if torso_dx == 0 and torso_dy == 0:
        return art0.copy()
    w, h = art0.size
    canvas = art0.copy()  # legs/boots stay exactly where they were

    # Upper body (head, hat, torso, arms) — cut from the ORIGINAL frame,
    # not the legs, so nothing below LEG_SPLIT_Y is duplicated or moved.
    upper = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    upper.paste(art0.crop((0, 0, w, LEG_SPLIT_Y)), (0, 0))
    upper_shifted = shift(upper, torso_dx, torso_dy)
    canvas.alpha_composite(upper_shifted)

    # Front arm/hand: extra shift beyond the torso so it leads the bend
    # (reaches further down/forward than the shoulder it's attached to).
    l, t, r, b = ARM_BOX
    arm = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    arm.paste(art0.crop((l, t, r, b)), (l, t))
    arm_shifted = shift(arm, torso_dx + arm_dx, torso_dy + arm_dy)
    canvas.alpha_composite(arm_shifted)
    return canvas


def main() -> None:
    src = Image.open(IDLE).convert("RGBA")
    art = src.resize((src.width // 2, src.height // 2), Image.Resampling.NEAREST)
    n = 5  # idle frame count
    cw = art.width // n
    art0 = art.crop((0, 0, cw, art.height))

    built = [build_frame(art0, *f) for f in FRAMES]
    cell_w = max(f.getbbox()[2] if f.getbbox() else cw for f in built)
    cell_w = max(cell_w, cw)
    strip = Image.new("RGBA", (cell_w * len(built), art.height), (0, 0, 0, 0))
    for i, f in enumerate(built):
        strip.paste(f, (i * cell_w, 0), f)

    out = strip.resize((strip.width * 2, strip.height * 2), Image.Resampling.NEAREST)
    out.save(OUT)
    print(f"[scoop] wrote {OUT} {out.width}x{out.height} ({len(built)} frames, cell {cell_w}x{art.height} art px)")


if __name__ == "__main__":
    main()
