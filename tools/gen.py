"""Serialized wrapper around Wes's Gemini imagegen tool.

Several agents may want pictures at once but there is exactly ONE Chrome
profile, so calls must not overlap. This takes a machine-wide lock file,
then runs C:/Users/weshu/CodeProjects/imagegen/gen.py with the same args.

    python tools/gen.py "<prompt>" --out assets/gen --name swamp-pump

Every flag gen.py accepts passes straight through. Prints gen.py's output.
"""
import os
import subprocess
import sys
import time

GEN = r"C:\Users\weshu\CodeProjects\imagegen\gen.py"
LOCK = r"C:\Users\weshu\CodeProjects\imagegen\.gen.lock"
STALE_S = 240  # a run never takes this long; treat older locks as dead


def acquire() -> None:
    t0 = time.time()
    while True:
        try:
            fd = os.open(LOCK, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            os.write(fd, str(os.getpid()).encode())
            os.close(fd)
            return
        except FileExistsError:
            try:
                if time.time() - os.path.getmtime(LOCK) > STALE_S:
                    os.remove(LOCK)
                    continue
            except OSError:
                pass
            if time.time() - t0 > 1800:
                print("FAILED at lock: waited 30 min for the imagegen lock", flush=True)
                sys.exit(2)
            time.sleep(3)


def release() -> None:
    try:
        os.remove(LOCK)
    except OSError:
        pass


def main() -> int:
    acquire()
    try:
        r = subprocess.run([sys.executable, GEN] + sys.argv[1:])
        return r.returncode
    finally:
        release()


if __name__ == "__main__":
    sys.exit(main())
