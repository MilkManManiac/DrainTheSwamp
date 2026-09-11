"""Launch the game windowed with the DTS_* debug flags, grab a screenshot, quit.

    python tools/capture.py --out _screenshots/x/town_day.png --camx 900 --tod 0.3
    python tools/capture.py --out shot.png --scene res://scenes/caves/gator_den.tscn --freeze
    python tools/capture.py --out shot.png --check          # headless boot, print script errors only

Flags map 1:1 to the env hooks in game_world.gd / cave_base.gd / player.gd:
  --camx X      park the player at world X        (DTS_CAMX)
  --tod T       0..1 time of day, freezes the day (DTS_TOD)
  --zoom Z      camera zoom                       (DTS_ZOOM)
  --drain D     0..1 heal / drain level           (DTS_DRAIN)
  --char a|b|c  player sprite variant             (DTS_CHAR)
  --freeze      hold the scene (caves auto-exit)  (DTS_FREEZE)
  --wait S      seconds to let the game run before killing it (default 7)
  --interval S  DTS_SHOT_INTERVAL (default 1.0)
  --scene RES   scene to boot (default res://scenes/main.tscn = the game world)
Any other DTS_* var in the environment passes through, e.g. DTS_UI=shop|menu|touch
(main.gd) opens that panel / shows the touch controls for a HUD capture.

Runs `--headless --import` first whenever a PNG under assets/ has no .import
sibling or .godot/ is missing (new art, fresh worktree). Works from any
worktree: the project root is the directory containing project.godot above
this file. Log goes next to the PNG as <name>.log.
"""
import argparse
import os
import subprocess
import sys
import time
from pathlib import Path

GODOT = r"C:\Users\weshu\Tools\Godot\Godot_v4.6.3-stable_win64_console.exe"
ROOT = Path(__file__).resolve().parent.parent
ERR_MARKS = ("SCRIPT ERROR", "Parse Error", "nonexistent", "Invalid", "ERROR:")
# known harmless noise (HDR capture format check from linear_to_srgb)
IGNORE = ("FORMAT_RGB8",)


def needs_import() -> bool:
    if not (ROOT / ".godot" / "imported").exists():
        return True
    for p in (ROOT / "assets").rglob("*.png"):
        imp = p.with_name(p.name + ".import")
        if not imp.exists():
            return True
        # .import's dest_files hash is derived from the resource path/uid, not
        # content, so a `git merge`/checkout that changes a PNG's bytes (a
        # track's art regenerated with the same filename) leaves the old
        # cached .ctex in place with the same name and Godot never notices -
        # the game silently keeps rendering the stale texture. Catch both:
        # (a) the cached file is simply missing (merge into a fresh worktree
        # that never imported this path), and (b) the source PNG is newer
        # than the cached file (content changed since the last import).
        src_mtime = p.stat().st_mtime
        found_dest = False
        for line in imp.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.startswith("path=") and line[5:].strip('"').startswith("res://"):
                dest = ROOT / line[5:].strip('"')[len("res://"):]
                if not dest.exists() or dest.stat().st_mtime < src_mtime:
                    return True
                found_dest = True
                break
            if line.startswith("dest_files=") and not found_dest:
                # multi-file remap (e.g. VRAM variants): any stale/missing dest triggers reimport
                for part in line[len("dest_files="):].strip("[]").split(","):
                    part = part.strip().strip('"')
                    if not part.startswith("res://"):
                        continue
                    dest = ROOT / part[len("res://"):]
                    if not dest.exists() or dest.stat().st_mtime < src_mtime:
                        return True
    return False


def run_import() -> None:
    print("[capture] importing project (new assets or fresh worktree)...", flush=True)
    subprocess.run([GODOT, "--headless", "--path", str(ROOT), "--import"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=600)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--scene", default="res://scenes/main.tscn")
    ap.add_argument("--camx")
    ap.add_argument("--tod")
    ap.add_argument("--zoom")
    ap.add_argument("--drain")
    ap.add_argument("--char")
    ap.add_argument("--freeze", action="store_true")
    ap.add_argument("--wait", type=float, default=7.0)
    ap.add_argument("--interval", default="1.0")
    ap.add_argument("--check", action="store_true", help="headless boot only; print script errors")
    ap.add_argument("--no-import", action="store_true")
    a = ap.parse_args()

    if not a.no_import and needs_import():
        run_import()

    env = dict(os.environ)
    out = Path(a.out).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    if out.exists():
        out.unlink()
    env["DTS_SHOT"] = str(out)
    env["DTS_SHOT_INTERVAL"] = a.interval
    for k, v in (("DTS_CAMX", a.camx), ("DTS_TOD", a.tod), ("DTS_ZOOM", a.zoom),
                 ("DTS_DRAIN", a.drain), ("DTS_CHAR", a.char)):
        if v is not None:
            env[k] = str(v)
    if a.freeze:
        env["DTS_FREEZE"] = "1"

    cmd = [GODOT, "--path", str(ROOT), "--audio-driver", "Dummy", a.scene]
    if a.check:
        cmd = [GODOT, "--headless", "--path", str(ROOT), "--audio-driver", "Dummy",
               a.scene, "--quit-after", "120"]
        r = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=180)
        text = r.stdout + r.stderr
        bad = [ln for ln in text.splitlines() if any(m in ln for m in ERR_MARKS) and not any(i in ln for i in IGNORE)]
        print("\n".join(bad) if bad else "[capture] headless boot clean")
        return 1 if bad else 0

    log = out.with_suffix(".log")
    with open(log, "w", encoding="utf-8") as lf:
        p = subprocess.Popen(cmd, env=env, stdout=lf, stderr=subprocess.STDOUT)
        try:
            p.wait(timeout=a.wait)
        except subprocess.TimeoutExpired:
            p.kill()
            time.sleep(0.5)
    text = log.read_text(encoding="utf-8", errors="replace")
    bad = [ln for ln in text.splitlines() if any(m in ln for m in ERR_MARKS) and not any(i in ln for i in IGNORE)]
    if bad:
        print("[capture] script errors in log:")
        print("\n".join(bad[:30]))
    if out.exists():
        print(f"[capture] saved {out}")
        return 0
    print(f"[capture] NO SCREENSHOT written; see {log}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
