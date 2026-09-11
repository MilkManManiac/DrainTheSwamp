"""Bake the v3 prop art (pumps, camels, mansion, politicians, helicopter, wanted
poster) from assets/gen/prop-*.{jpg,png} into assets/art/drainsville/prop_*.png.

Same recipe as bake.py (key magenta, trim, LANCZOS to the art grid, quantize,
x2 NEAREST) with one addition for strips: frames are registered on the centre
of their *base* (the bottom rows) instead of the whole-frame centre, so a pump
handle or a swung leg never shifts the body between frames.

    python tools/bake/bake_props.py            # bake everything that has a source
    python tools/bake/bake_props.py camel      # only the entries whose name contains "camel"
"""
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent.parent
GEN = ROOT / "assets" / "gen"
ART = ROOT / "assets" / "art" / "drainsville"

# name -> (source stem, mode, row, height in art px, colors, frames)
JOBS = {
    "prop_pump_small": ("prop-pump-small-v2", "sheet", 0, 34, 28, 3),
    "prop_pump_big": ("prop-pump-big-v2", "sheet", 0, 40, 32, 2),
    "prop_camel": ("prop-camel-sheet", "sheet", 0, 44, 24, 4),
    "prop_camel_loaded": ("prop-camel-sheet", "sheet", 1, 44, 28, 4),
    "prop_mansion": ("prop-mansion", "sprite", 0, 96, 32, 1),
    "prop_politicians_a": ("prop-politicians-v2", "sheet", 0, 36, 32, 5),
    "prop_politicians_b": ("prop-politicians-v2", "sheet", 1, 36, 32, 5),
    # row 1 (not 0): row 0's second pose has a stray rotor-strut fragment that
    # the connected-component frame split merges in at the wrong angle; row 1
    # gives a clean "blade" -> "spinning X" pair instead.
    "prop_helicopter": ("prop-helicopter", "sheet", 1, 28, 24, 2),
    "prop_wanted": ("prop-wanted", "sprite", 0, 26, 16, 1),
}


def find_src(stem: str):
    for ext in (".png", ".jpg", ".jpeg"):
        p = GEN / (stem + ext)
        if p.exists():
            return p
    return None


def base_center(fr: Image.Image) -> float:
    """x centre of the opaque pixels in the bottom 12% of the frame."""
    a = fr.getchannel("A")
    h = fr.height
    band = a.crop((0, max(0, h - max(2, h // 8)), fr.width, h))
    bb = band.getbbox()
    if bb is None:
        return fr.width / 2.0
    return (bb[0] + bb[2]) / 2.0


def components(img: Image.Image):
    """Connected components (8-way) of the alpha mask as bboxes, via row runs + union-find."""
    a = img.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    w, h = a.size
    px = a.load()
    parent = []

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    def union(i, j):
        ri, rj = find(i), find(j)
        if ri != rj:
            parent[rj] = ri

    runs = []          # (y, x0, x1, id)
    prev = []
    for y in range(h):
        cur = []
        x = 0
        while x < w:
            if px[x, y]:
                x0 = x
                while x < w and px[x, y]:
                    x += 1
                rid = len(parent)
                parent.append(rid)
                cur.append((y, x0, x, rid))
                for (_, px0, px1, pid) in prev:
                    if px0 <= x and px1 >= x0:          # touches incl. diagonals
                        union(pid, rid)
            else:
                x += 1
        runs.extend(cur)
        prev = cur
    boxes = {}
    for (y, x0, x1, rid) in runs:
        r = find(rid)
        b = boxes.get(r)
        if b is None:
            boxes[r] = [x0, y, x1, y + 1, (x1 - x0), [(y, x0, x1)]]
        else:
            b[0] = min(b[0], x0); b[1] = min(b[1], y); b[2] = max(b[2], x1); b[3] = max(b[3], y + 1); b[4] += x1 - x0
            b[5].append((y, x0, x1))
    return [tuple(b) for b in boxes.values()]


def erase(img: Image.Image, runs) -> None:
    px = img.load()
    for (y, x0, x1) in runs:
        for x in range(x0, x1):
            r, g, b, _ = px[x, y]
            px[x, y] = (r, g, b, 0)


def split_frames_cc(row_img: Image.Image, expected: int):
    """Frames = big connected blobs; small detached bits (a rotor tip, a hat) are
    merged into the blob whose x-range they overlap. Sorted left to right."""
    boxes = components(row_img)
    if not boxes:
        return []
    big_area = max(b[4] for b in boxes)
    main = sorted([b for b in boxes if b[4] >= big_area * 0.08], key=lambda b: b[0])
    bits = [b for b in boxes if b[4] < big_area * 0.08]
    merged = [list(b[:5]) for b in main]
    extra_runs = [[] for _ in main]
    # detached bits that sit within GAP px of a blob's pixels (rotor tip, hat)
    # join that blob; everything else is key noise and is erased.
    GAP = 10
    for b in bits:
        joined = False
        if b[4] >= big_area * 0.004:
            for m, src in zip(merged, main):
                if b[0] > src[2] + GAP or b[2] < src[0] - GAP:
                    continue
                near = any(abs(y - by) <= GAP and x0 <= b[2] + GAP and x1 >= b[0] - GAP
                           for (y, x0, x1) in src[5] for by in (b[1], b[3] - 1))
                if near:
                    m[0] = min(m[0], b[0]); m[1] = min(m[1], b[1]); m[2] = max(m[2], b[2]); m[3] = max(m[3], b[3])
                    extra_runs[merged.index(m)].extend(b[5])
                    joined = True
                    break
        if not joined:
            erase(row_img, b[5])
    if len(merged) != expected:
        print(f"[bake_props]   WARNING expected {expected} frames, found {len(merged)}")
    # copy each frame through its own component mask so a neighbour's overhang
    # (bboxes may overlap by a few px) never leaks into the cell
    out = []
    src_px = row_img.load()
    for m, src, runs in zip(merged, main, extra_runs):
        fr = Image.new("RGBA", (m[2] - m[0], m[3] - m[1]), (0, 0, 0, 0))
        fp = fr.load()
        for (y, x0, x1) in src[5] + runs:
            for x in range(x0, x1):
                fp[x - m[0], y - m[1]] = src_px[x, y]
        out.append(fr)
    return out


def bake_sheet(src: Path, row: int, height: int, colors: int, nframes: int) -> Image.Image:
    img = bake.key_out(Image.open(src), "magenta", 70, True)
    rows = bake.split_rows(img)
    if row >= len(rows):
        sys.exit(f"{src.name}: row {row} missing ({len(rows)} rows found)")
    frames = split_frames_cc(rows[row], nframes)
    if not frames:
        sys.exit(f"{src.name}: no frames in row {row}")
    tallest = max(f.height for f in frames)
    k = height / tallest
    scaled = [f.resize((max(1, round(f.width * k)), max(1, round(f.height * k))), Image.Resampling.LANCZOS) for f in frames]
    # register on the base centre; cell wide enough for the widest overhang either side
    centers = [base_center(f) for f in scaled]
    left = max(c for c in centers)
    right = max(f.width - c for f, c in zip(scaled, centers))
    cw = int(round(left + right)) + 2
    ch = height
    strip = Image.new("RGBA", (cw * len(scaled), ch), (0, 0, 0, 0))
    for i, (f, c) in enumerate(zip(scaled, centers)):
        x = i * cw + int(round(cw / 2.0 - c))
        strip.paste(f, (x, ch - f.height), f)
    print(f"[bake_props] {src.name} row {row}: {len(scaled)} frames, cell {cw}x{ch}")
    return bake.finish(strip, colors, True)


def bake_sprite(src: Path, height: int, colors: int) -> Image.Image:
    img = bake.key_out(Image.open(src), "magenta", 70, True)
    img = bake.trim(img, 0)
    img = bake.resize_to(img, None, height)
    return bake.finish(img, colors, True)


def main() -> None:
    only = sys.argv[1:]
    for name, (stem, mode, row, height, colors, nframes) in JOBS.items():
        if only and not any(o in name for o in only):
            continue
        src = find_src(stem)
        if src is None:
            print(f"[bake_props] skip {name}: no assets/gen/{stem}.*")
            continue
        out = bake_sheet(src, row, height, colors, nframes) if mode == "sheet" else bake_sprite(src, height, colors)
        ART.mkdir(parents=True, exist_ok=True)
        dst = ART / f"{name}.png"
        out.save(dst)
        print(f"[bake_props] wrote {dst.relative_to(ROOT)} {out.width}x{out.height}")


if __name__ == "__main__":
    main()
