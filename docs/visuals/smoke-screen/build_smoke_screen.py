"""Pack the PixelLab smoke-screen frames into assets/pickups/smoke_tag_bomb (screen_burst / screen_loop / screen_fade).

Raw downloads live in assets/pickups/smoke_tag_bomb/source/screen/<job>/raw_NN.png (fetch with --fetch). The chosen
ranges and the one artifact cleanup are listed in JOBS so the pack is reproducible.
"""
import hashlib
import json
import os
import sys
import urllib.request

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "pickups", "smoke_tag_bomb")
SRC = os.path.join(OUT, "source", "screen")
JOBS = json.load(open(os.path.join(HERE, "jobs.json"), encoding="utf-8"))


def fetch() -> None:
    for job in JOBS["animations"]:
        d = os.path.join(SRC, job["name"])
        os.makedirs(d, exist_ok=True)
        for i in range(job["returned_frames"]):
            urllib.request.urlretrieve(f"https://api.pixellab.ai/mcp/images/{job['job_id']}/download?index={i}", os.path.join(d, f"raw_{i:02d}.png"))


def drop_specks(im: Image.Image, below_y: int, max_px: int) -> Image.Image:
    """Clear small detached alpha islands whose top sits at or below `below_y` (generator debris under the bank)."""
    im = im.copy()
    px = im.load()
    w, h = im.size
    seen = set()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0 or (x, y) in seen:
                continue
            stack, comp = [(x, y)], []
            seen.add((x, y))
            while stack:
                cx, cy = stack.pop()
                comp.append((cx, cy))
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and px[nx, ny][3] > 0:
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            if len(comp) <= max_px and min(p[1] for p in comp) >= below_y:
                for p in comp:
                    px[p] = (0, 0, 0, 0)
    return im


def pack() -> dict:
    layers = {}
    for job in JOBS["animations"]:
        frames = []
        for n, i in enumerate(job["use"]):
            im = Image.open(os.path.join(SRC, job["name"], f"raw_{i:02d}.png")).convert("RGBA")
            for fix in job.get("cleanup", []):
                if fix["frame"] == i:
                    im = drop_specks(im, fix["below_y"], fix["max_px"])
            px = im.load()
            for y in range(im.size[1]):
                for x in range(im.size[0]):
                    r, g, b, a = px[x, y]
                    px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
            name = f"{job['layer']}_{n:02d}.png"
            im.save(os.path.join(OUT, name))
            frames.append((name, hashlib.sha1(im.tobytes()).hexdigest()))
        layers[job["layer"]] = {
            "frames": [f for f, _ in frames], "frame_size": [256, 192], "fps": job["fps"], "loop": job["layer"] == "screen_loop",
            "unique_frames": len({h for _, h in frames}), "anchor": [128, 166], "pixellab_job": job["job_id"],
        }
    return layers


if __name__ == "__main__":
    if "--fetch" in sys.argv:
        fetch()
    art_path = os.path.join(OUT, "smoke_tag_bomb.art.json")
    art = json.load(open(art_path, encoding="utf-8"))
    art["layers"].update(pack())
    art["effects"] = "screen_burst -> screen_loop -> screen_fade, three runtime banks; blocks sight both ways while standing (SmokeTagBomb.first_cover); smoke/billow are the retired first pass"
    json.dump(art, open(art_path, "w", encoding="utf-8", newline="\n"), indent=2)
    print({k: v["unique_frames"] for k, v in art["layers"].items() if k.startswith("screen_")})
