"""Bake Gemini pictures (JPG/PNG, magenta or white background) into game pixel art.

The game's art grid: 1 art px = 1 world unit = 2 screen px at 720p. Sprites are
placed at world scale 0.5, so a baked texture must be (art px) x 2 in size.
Recipe (same as the 2026-09-10 bakes): key the background, crop to content,
LANCZOS down to the art grid, quantize to a small palette, x2 NEAREST.

  sprite  one picture -> one sprite
      python tools/bake/bake.py sprite assets/gen/pump.jpg assets/art/drainsville/pump.png --height 48 --key magenta
  sheet   a row/grid of poses on magenta -> one horizontal strip, frames bottom-aligned
      python tools/bake/bake.py sheet assets/gen/char-sheet.png assets/art/drainsville/player_walk.png --height 40 --colors 28 --row 1
  plate   a flat backdrop (sky, cave wall) -> pixel plate at a given art width, no keying
      python tools/bake/bake.py plate assets/gen/sky-day.jpg assets/art/drainsville/sky_day.png --width 640
  tile    a seamless-ish texture -> tile at art size (no keying, edges blended)
      python tools/bake/bake.py tile assets/gen/rock.jpg assets/art/caves/rock.png --width 64 --height 64

Common flags: --colors N (palette size, default 32), --key magenta|white|black|none,
--tol T (key tolerance 0-255, default 70), --no-x2 (keep art-grid size), --pad P.
Gemini JPGs blur the magenta edge; --tol 70 plus --despill cleans the halo.
"""
import argparse
import sys
from pathlib import Path

from PIL import Image, ImageFilter

KEYS = {"magenta": (255, 0, 255), "white": (255, 255, 255), "black": (0, 0, 0)}


def key_out(img: Image.Image, key: str, tol: int, despill: bool) -> Image.Image:
    img = img.convert("RGBA")
    if key == "none":
        return img
    kr, kg, kb = KEYS[key]
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if key == "magenta":
                # hue test, not distance: Gemini draws darker magenta grid lines and
                # JPG-blurred pink fringes that a plain colour distance misses.
                mn = min(r, b)
                pinkness = mn - g            # how far the pixel leans magenta
                if mn > 60 and abs(r - b) < 90 and pinkness > 60:
                    px[x, y] = (r, g, b, 0)
                elif despill and mn > 60 and pinkness > 25 and abs(r - b) < 110:
                    px[x, y] = (min(r, g + 40), g, min(b, g + 40), 255)
                continue
            d = max(abs(r - kr), abs(g - kg), abs(b - kb))
            if d <= tol:
                px[x, y] = (r, g, b, 0)
    return img


def trim(img: Image.Image, pad: int = 0) -> Image.Image:
    bbox = img.getchannel("A").getbbox()
    if bbox is None:
        return img
    l, t, r, b = bbox
    return img.crop((max(0, l - pad), max(0, t - pad), min(img.width, r + pad), min(img.height, b + pad)))


def quantize(img: Image.Image, colors: int) -> Image.Image:
    """Palette-reduce RGB while keeping a hard alpha mask."""
    alpha = img.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    rgb = img.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def finish(img: Image.Image, colors: int, x2: bool) -> Image.Image:
    img = quantize(img, colors)
    if x2:
        img = img.resize((img.width * 2, img.height * 2), Image.Resampling.NEAREST)
    return img


def resize_to(img: Image.Image, width, height) -> Image.Image:
    if width and height:
        return img.resize((width, height), Image.Resampling.LANCZOS)
    if height:
        w = max(1, round(img.width * height / img.height))
        return img.resize((w, height), Image.Resampling.LANCZOS)
    if width:
        h = max(1, round(img.height * width / img.width))
        return img.resize((width, h), Image.Resampling.LANCZOS)
    return img


def cmd_sprite(a) -> Image.Image:
    img = Image.open(a.src)
    img = key_out(img, a.key, a.tol, a.despill)
    img = trim(img, a.pad)
    img = resize_to(img, a.width, a.height)
    return finish(img, a.colors, not a.no_x2)


def cmd_plate(a) -> Image.Image:
    img = Image.open(a.src).convert("RGBA")
    if a.crop:
        l, t, r, b = [int(v) for v in a.crop.split(",")]
        img = img.crop((l, t, r, b))
    img = resize_to(img, a.width, a.height)
    return finish(img, a.colors, not a.no_x2)


def cmd_tile(a) -> Image.Image:
    img = Image.open(a.src).convert("RGBA")
    if a.crop:
        l, t, r, b = [int(v) for v in a.crop.split(",")]
        img = img.crop((l, t, r, b))
    img = resize_to(img, a.width or 64, a.height or a.width or 64)
    # cheap seam soften: blend a wrapped copy at the edges
    w, h = img.size
    wrapped = Image.new("RGBA", (w, h))
    wrapped.paste(img.crop((w // 2, 0, w, h)), (0, 0))
    wrapped.paste(img.crop((0, 0, w // 2, h)), (w // 2, 0))
    wrapped = wrapped.filter(ImageFilter.GaussianBlur(1.0))
    mask = Image.new("L", (w, h), 0)
    mp = mask.load()
    for x in range(w):
        d = min(x, w - 1 - x)
        v = 255 if d < 2 else 0
        for y in range(h):
            mp[x, y] = v
    img = Image.composite(wrapped, img, mask)
    return finish(img, a.colors, not a.no_x2)


def _runs(flags, min_gap):
    """Index ranges where flags are true, merging gaps shorter than min_gap."""
    runs = []
    i, n = 0, len(flags)
    while i < n:
        if not flags[i]:
            i += 1
            continue
        i0 = i
        while i < n and (flags[i] or any(flags[i:i + min_gap])):
            i += 1
        runs.append((i0, i))
    return runs


def split_rows(img: Image.Image, min_gap: int = 6):
    ap = img.getchannel("A").load()
    w, h = img.size
    rows = [any(ap[x, y] for x in range(w)) for y in range(h)]
    return [img.crop((0, y0, w, y1)) for y0, y1 in _runs(rows, min_gap) if y1 - y0 >= 8]


def split_frames(img: Image.Image, min_gap: int = 4):
    """Split one keyed row into frames by transparent columns."""
    ap = img.getchannel("A").load()
    w, h = img.size
    cols = [any(ap[x, y] for y in range(h)) for x in range(w)]
    frames = []
    for x0, x1 in _runs(cols, min_gap):
        fr = img.crop((x0, 0, x1, h))
        fb = fr.getchannel("A").getbbox()
        if fb and (fb[2] - fb[0]) >= 4 and (fb[3] - fb[1]) >= 8:
            frames.append(fr.crop(fb))
    return frames


def cmd_sheet(a) -> Image.Image:
    img = Image.open(a.src)
    img = key_out(img, a.key, a.tol, a.despill)
    if a.crop:
        l, t, r, b = [int(v) for v in a.crop.split(",")]
        img = img.crop((l, t, r, b))
    rows = split_rows(img)
    print(f"[bake] {len(rows)} rows found; using row {a.row}")
    if a.row >= len(rows):
        sys.exit(f"row {a.row} does not exist")
    frames = split_frames(rows[a.row])
    if a.frames:
        frames = frames[: a.frames]
    if not frames:
        sys.exit("no frames found; is the background really the key colour?")
    # normalise: scale every frame by the tallest frame's factor so proportions hold
    tallest = max(f.height for f in frames)
    k = a.height / tallest
    scaled = [f.resize((max(1, round(f.width * k)), max(1, round(f.height * k))), Image.Resampling.LANCZOS) for f in frames]
    cw = max(f.width for f in scaled) + 2 * a.pad
    ch = a.height + a.pad
    strip = Image.new("RGBA", (cw * len(scaled), ch), (0, 0, 0, 0))
    for i, f in enumerate(scaled):
        strip.paste(f, (i * cw + (cw - f.width) // 2, ch - f.height), f)
    print(f"[bake] {len(scaled)} frames, cell {cw}x{ch} art px (x2 -> {cw*2}x{ch*2})")
    return finish(strip, a.colors, not a.no_x2)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("mode", choices=["sprite", "sheet", "plate", "tile"])
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--width", type=int)
    ap.add_argument("--height", type=int)
    ap.add_argument("--colors", type=int, default=32)
    ap.add_argument("--key", default="magenta", choices=list(KEYS) + ["none"])
    ap.add_argument("--tol", type=int, default=70)
    ap.add_argument("--despill", action="store_true")
    ap.add_argument("--pad", type=int, default=0)
    ap.add_argument("--crop", help="l,t,r,b in source px")
    ap.add_argument("--frames", type=int, help="sheet: keep only the first N frames")
    ap.add_argument("--row", type=int, default=0, help="sheet: which row of poses (0 = top)")
    ap.add_argument("--no-x2", action="store_true")
    a = ap.parse_args()
    if a.mode == "sheet" and not a.height:
        sys.exit("sheet needs --height (art px)")
    out = {"sprite": cmd_sprite, "sheet": cmd_sheet, "plate": cmd_plate, "tile": cmd_tile}[a.mode](a)
    Path(a.dst).parent.mkdir(parents=True, exist_ok=True)
    out.save(a.dst)
    print(f"[bake] wrote {a.dst} {out.width}x{out.height}")


if __name__ == "__main__":
    main()
