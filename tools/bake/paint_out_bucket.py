"""Paint the baked-in bucket out of the player A idle/walk strips (2026-09-11).

The Gemini sheet holds a bucket in every frame. v3 draws tools as a separate
overlay anchored to the hand (player_skin.gd), so the base frames must be
empty-handed. Per frame: clear every non-blue pixel inside the bucket box,
then re-outline any exposed edge with the darkest palette colour.

    python tools/bake/paint_out_bucket.py            # rewrites player_a_idle/walk.png in place

Original (bucket) strips: git show e93d32c:assets/art/drainsville/player_a_walk.png
Boxes are art px (x2 strip / 2), inclusive: (x0, y0, x1, y1) per frame.
"""
from pathlib import Path
from PIL import Image

ART = Path(__file__).resolve().parents[2] / "assets" / "art" / "drainsville"
BOXES = {
    "idle": [(1, 27, 6, 34), (3, 27, 7, 34), (1, 27, 6, 34), (1, 27, 6, 34), (2, 27, 7, 34)],
    "walk": [(3, 28, 10, 35), (9, 28, 14, 35), (5, 28, 11, 35), (7, 29, 13, 34)],
}
FRAMES = {"idle": 5, "walk": 4}
# The bucket also hid the far leg's thigh in the walk frames. Refill it as a
# straight band from (row yt, xt0..xt1) to (row yb, xb0..xb1), far-leg blue,
# only where the pixel is transparent after the clear.
LEGS = {
    "idle": [None] * 5,
    "walk": [(28, 6, 9, 33, 3, 5), (28, 10, 13, 33, 7, 9), (28, 8, 10, 33, 5, 7), (29, 9, 12, 33, 6, 8)],
}


def is_blue(p):
    r, g, b, a = p
    # overalls blue: clearly cooler than grey bucket metal
    return a >= 128 and b > r + 20 and b > g + 6 and (b - min(r, g)) > 30


def paint(name: str) -> None:
    path = ART / f"player_a_{name}.png"
    im = Image.open(path).convert("RGBA")
    art = im.resize((im.width // 2, im.height // 2), Image.NEAREST)
    n = FRAMES[name]
    cw = art.width // n
    px = art.load()
    # darkest opaque colour = outline
    dark = min((px[x, y] for x in range(art.width) for y in range(art.height) if px[x, y][3] >= 128),
               key=lambda p: p[0] + p[1] + p[2])
    for i, (x0, y0, x1, y1) in enumerate(BOXES[name]):
        ox = i * cw
        cleared = set()
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if px[ox + x, y][3] >= 128 and not is_blue(px[ox + x, y]):
                    px[ox + x, y] = (0, 0, 0, 0)
                    cleared.add((x, y))
        leg = LEGS[name][i]
        filled = set()
        if leg:
            yt, xt0, xt1, yb, xb0, xb1 = leg
            # far-leg blue: median blue of the shin rows below the box
            shin = [px[ox + x, y] for y in range(yb, min(art.height, yb + 4)) for x in range(cw) if is_blue(px[ox + x, y])]
            shin.sort(key=lambda p: p[0] + p[1] + p[2])
            col = shin[len(shin) // 2] if shin else (60, 80, 120, 255)
            for y in range(yt, yb + 1):
                t = (y - yt) / max(1, yb - yt)
                xa = round(xt0 + (xb0 - xt0) * t)
                xb = round(xt1 + (xb1 - xt1) * t)
                for x in range(xa, xb + 1):
                    if px[ox + x, y][3] < 128:
                        px[ox + x, y] = col
                        filled.add((x, y))
        # re-outline: a cleared pixel touching blue, or a transparent pixel
        # touching the refilled leg, becomes outline
        for (x, y) in cleared - filled:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < cw and 0 <= ny < art.height and is_blue(px[ox + nx, ny]):
                    px[ox + x, y] = dark
                    break
        for (x, y) in list(filled):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < cw and 0 <= ny < art.height and px[ox + nx, ny][3] < 128:
                    px[ox + nx, ny] = dark
    out = art.resize((art.width * 2, art.height * 2), Image.NEAREST)
    out.save(path)
    print(f"[paint] {path.name} {out.width}x{out.height} outline={dark[:3]}")


if __name__ == "__main__":
    for name in FRAMES:
        paint(name)
