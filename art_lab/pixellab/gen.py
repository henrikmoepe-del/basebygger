"""Makes the art lab's PixelLab pictures with the PixelLab API (pixellab.ai).

    PIXELLAB_API_KEY=... python3 art_lab/pixellab/gen.py [name ...]

Each entry in ASSETS becomes art_lab/pixellab/<name>.png (animations:
<name>_0.png ... <name>_3.png). A picture that already exists is skipped, so
running it again only costs generations for new or deleted pictures.
The key is never written anywhere.
"""
import base64
import io
import json
import os
import sys
import time
import urllib.request

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
API = "https://api.pixellab.ai/v2"
STYLE = {"outline": "selective outline", "shading": "medium shading", "detail": "highly detailed"}
LOOK = "pixel art like a cozy 16-bit castle valley, cream stone, blue slate roofs, bright daylight"

# The style samples are cut from castle-valley-loop-1080p60.mp4 (see README.md).
ASSETS = {
    "tower": {
        "endpoint": "/create-image-pixflux",
        "body": {
            "description": "one single round castle tower standing alone, centered, whole tower from the ground up: "
                           "cream stone brick walls, two arched windows, a pointed blue slate cone roof, a small red flag on top. " + LOOK,
            "image_size": {"width": 96, "height": 192}, "no_background": True, "view": "side", **STYLE,
        },
    },
    "keep": {
        "endpoint": "/create-image-pixflux",
        "body": {
            "description": "one single square castle keep standing alone, centered, whole building from the ground up: "
                           "a big tall block of cream stone bricks, battlements along the flat top, six arched dark windows in two columns, "
                           "an arched wooden door at the bottom middle. " + LOOK,
            "image_size": {"width": 128, "height": 192}, "no_background": True, "view": "side", **STYLE,
        },
    },
    "gatehouse": {
        "endpoint": "/create-image-pixflux",
        "body": {
            "description": "one single square stone gatehouse tower, centered, from the ground up: cream stone bricks, battlements on top, "
                           "a big arched gate with a wooden door at the bottom, one narrow window. " + LOOK,
            "image_size": {"width": 80, "height": 128}, "no_background": True, "view": "side", **STYLE,
        },
    },
    "wall": {
        "endpoint": "/create-image-pixflux",
        "body": {
            "description": "a straight piece of castle curtain wall seen from the side, cream stone bricks, a row of battlements along the top, "
                           "filling the whole width. " + LOOK,
            "image_size": {"width": 128, "height": 64}, "no_background": True, "view": "side", **STYLE,
        },
    },
    "house": {
        "endpoint": "/create-image-pixflux",
        "body": {
            "description": "one small medieval half-timbered cottage seen from the front, white plaster with dark wooden beams, "
                           "a steep red-orange tiled roof, a chimney, small windows and a wooden door. " + LOOK,
            "image_size": {"width": 96, "height": 96}, "no_background": True, "view": "side", **STYLE,
        },
    },
    "house2": {
        "endpoint": "/create-image-pixflux",
        "body": {
            "description": "one tiny medieval half-timbered hut seen from the front, white plaster, dark wooden beams, "
                           "a pointed red-orange tiled roof, a wooden door. " + LOOK,
            "image_size": {"width": 64, "height": 80}, "no_background": True, "view": "side", **STYLE,
        },
    },
    "well": {
        "endpoint": "/create-image-pixflux",
        "body": {
            "description": "a small medieval village stone well with a little red tiled roof on two wooden posts and a bucket. " + LOOK,
            "image_size": {"width": 48, "height": 48}, "no_background": True, "view": "side", **STYLE,
        },
    },
    "pine": {
        "endpoint": "/create-image-pixflux",
        "body": {
            "description": "one green pine tree, side view. " + LOOK,
            "image_size": {"width": 48, "height": 64}, "no_background": True, "view": "side", **STYLE,
        },
    },
    "oak": {
        "endpoint": "/create-image-pixflux",
        "body": {
            "description": "one round leafy green oak tree, side view. " + LOOK,
            "image_size": {"width": 64, "height": 64}, "no_background": True, "view": "side", **STYLE,
        },
    },
    "block": {
        "endpoint": "/create-image-pixflux",
        "body": {
            "description": "one single cut rectangular cream limestone building block, wide and low, side view. " + LOOK,
            "image_size": {"width": 32, "height": 32}, "no_background": True, "view": "side", **STYLE,
        },
    },
    "stone_pile": {
        "endpoint": "/create-image-pixflux",
        "body": {
            "description": "a neat stacked pile of cut cream limestone building blocks, side view. " + LOOK,
            "image_size": {"width": 64, "height": 48}, "no_background": True, "view": "side", **STYLE,
        },
    },
    "log_pile": {
        "endpoint": "/create-image-pixflux",
        "body": {
            "description": "a small stacked pile of cut wooden logs, seen from the side with the round log ends showing. " + LOOK,
            "image_size": {"width": 48, "height": 32}, "no_background": True, "view": "side", **STYLE,
        },
    },
    "bench": {
        "endpoint": "/create-image-pixflux",
        "body": {
            "description": "a simple wooden stonemason workbench with four legs, side view, empty top. " + LOOK,
            "image_size": {"width": 48, "height": 32}, "no_background": True, "view": "side", **STYLE,
        },
    },
    "backdrop": {
        "endpoint": "/create-image-pixflux",
        "body": {
            "description": "wide landscape background for a side-scrolling game, no buildings: bright blue sky with big fluffy white clouds, "
                           "a sun on the left, snowy purple-blue mountains in the distance, a blue lake, rolling green hills with small trees, "
                           "flat green meadow with tiny flowers in the foreground. " + LOOK,
            "image_size": {"width": 320, "height": 180}, "view": "side", **STYLE,
        },
    },
    "peasant": {
        "endpoint": "/create-image-pixflux",
        "body": {
            "description": "a medieval peasant builder, full body, standing, side view facing right, brown hair, "
                           "simple blue tunic with a belt, brown trousers, leather boots. " + LOOK,
            "image_size": {"width": 32, "height": 32}, "no_background": True, "view": "side", "direction": "east", **STYLE,
        },
    },
}


def img_b64(path, size=None):
    """An image for the API. With a size, the image is tiled and cut to that
    size first (a style image must be as big as the picture asked for)."""
    im = Image.open(path).convert("RGBA")
    if size and im.size != size:
        tiled = Image.new("RGBA", size)
        for x in range(0, size[0], im.width):
            for y in range(0, size[1], im.height):
                tiled.paste(im, (x, y))
        im = tiled
    buf = io.BytesIO()
    im.save(buf, "PNG")
    return {"type": "base64", "base64": base64.b64encode(buf.getvalue()).decode(), "format": "png"}


def call(path, body, key):
    req = urllib.request.Request(API + path, data=json.dumps(body).encode(), method="POST",
                                 headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"})
    for attempt in range(10):
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            text = e.read().decode()[:600]
            if e.code == 429 and attempt < 9:
                time.sleep(15)  # the free plan runs one job at a time
                continue
            raise SystemExit("%s %s: %s" % (path, e.code, text))


def get(path, key):
    req = urllib.request.Request(API + path, headers={"Authorization": "Bearer " + key})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.load(r)


def save(b64img, out):
    data = b64img["base64"].split(",")[-1]
    Image.open(io.BytesIO(base64.b64decode(data))).convert("RGBA").save(out)


def wait_job(resp, key):
    """Most v2 calls answer at once; some give a job to poll."""
    job = resp.get("background_job_id")
    if not job:
        return resp
    while True:
        time.sleep(6)
        st = get("/background-jobs/" + job, key)
        if st.get("status") in ("completed", "failed"):
            if st["status"] == "failed":
                raise SystemExit("job failed: %s" % json.dumps(st)[:600])
            return st.get("last_response") or st


def make(name, spec, key):
    body = dict(spec["body"])
    for field, file in spec.get("images", {}).items():
        size = (body["image_size"]["width"], body["image_size"]["height"]) if field == "style_image" else None
        body[field] = img_b64(os.path.join(HERE, file), size)
    resp = wait_job(call(spec["endpoint"], body, key), key)
    if "image" in resp:
        save(resp["image"], os.path.join(HERE, name + ".png"))
    elif "images" in resp:
        for i, im in enumerate(resp["images"]):
            save(im, os.path.join(HERE, "%s_%d.png" % (name, i)))
    else:
        raise SystemExit("no image in answer: %s" % json.dumps(resp)[:600])
    return resp.get("usage")


def done(name):
    return os.path.exists(os.path.join(HERE, name + ".png")) or os.path.exists(os.path.join(HERE, name + "_0.png"))


def main():
    key = os.environ.get("PIXELLAB_API_KEY")
    if not key:
        raise SystemExit("Set PIXELLAB_API_KEY first.")
    names = sys.argv[1:] or list(ASSETS)
    for name in names:
        if done(name):
            print("have", name)
            continue
        usage = make(name, ASSETS[name], key)
        print("made", name, usage, get("/balance", key).get("subscription", {}).get("generations"))


if __name__ == "__main__":
    main()
