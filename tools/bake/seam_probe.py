"""Measure row-to-row luminance jumps in a PNG crop to locate hard seams.

For each row in [y0,y1) average luminance over [x0,x1), then print the
top-N |delta| between consecutive rows (row y -> row y+1), sorted descending.
A real soft gradient has small deltas everywhere; a hard-edged rect/line
shows one big spike at its edge.

    python tools/bake/seam_probe.py IMG.png --x 860,1270 --y 300,420 [--top 3]
"""
import argparse
from pathlib import Path

from PIL import Image


def row_luminance(img: Image.Image, x0: int, x1: int, y: int) -> float:
    row = img.crop((x0, y, x1, y + 1)).convert("L")
    px = list(row.getdata())
    return sum(px) / len(px)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("image")
    ap.add_argument("--x", required=True, help="x0,x1")
    ap.add_argument("--y", required=True, help="y0,y1")
    ap.add_argument("--top", type=int, default=3)
    a = ap.parse_args()
    x0, x1 = [int(v) for v in a.x.split(",")]
    y0, y1 = [int(v) for v in a.y.split(",")]
    img = Image.open(a.image)

    lums = [row_luminance(img, x0, x1, y) for y in range(y0, y1)]
    jumps = []
    for i in range(len(lums) - 1):
        jumps.append((abs(lums[i + 1] - lums[i]), y0 + i, lums[i], lums[i + 1]))
    jumps.sort(reverse=True, key=lambda t: t[0])

    print(f"[seam_probe] {Path(a.image).name} x=[{x0},{x1}) y=[{y0},{y1})")
    for delta, y, lum_a, lum_b in jumps[: a.top]:
        print(f"  y={y}->{y+1}  delta={delta:.1f}  ({lum_a:.1f} -> {lum_b:.1f})")


if __name__ == "__main__":
    main()
