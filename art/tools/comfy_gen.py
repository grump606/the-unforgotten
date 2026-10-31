"""Generate one image through a local ComfyUI server (SDXL base, txt2img) and save it.

  D:/Tools/comfyui/ComfyUI_windows_portable/python_embeded/python.exe art/tools/comfy_gen.py \
      --prompt "..." --out art/work/warden/bg_raw.png --width 1536 --height 512 --seed 11

The server must be running on 127.0.0.1:8188 (see art/COMFYUI.md).
"""
import argparse
import json
import time
import urllib.request

SERVER = "http://127.0.0.1:8188"
CHECKPOINT = "sd_xl_base_1.0.safetensors"


def build(prompt, negative, width, height, seed, steps, cfg):
    return {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": CHECKPOINT}},
        "2": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["1", 1]}},
        "3": {"class_type": "CLIPTextEncode", "inputs": {"text": negative, "clip": ["1", 1]}},
        "4": {"class_type": "EmptyLatentImage", "inputs": {"width": width, "height": height, "batch_size": 1}},
        "5": {"class_type": "KSampler", "inputs": {
            "model": ["1", 0], "positive": ["2", 0], "negative": ["3", 0], "latent_image": ["4", 0],
            "seed": seed, "steps": steps, "cfg": cfg, "sampler_name": "dpmpp_2m",
            "scheduler": "karras", "denoise": 1.0}},
        "6": {"class_type": "VAEDecode", "inputs": {"samples": ["5", 0], "vae": ["1", 2]}},
        "7": {"class_type": "SaveImage", "inputs": {"images": ["6", 0], "filename_prefix": "cardbattle"}},
    }


def post(path, data):
    req = urllib.request.Request(SERVER + path, json.dumps(data).encode(), {"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req))


def get(path):
    return urllib.request.urlopen(SERVER + path).read()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--prompt", required=True)
    ap.add_argument("--negative", default="text, watermark, signature, frame, border, UI, blurry, lowres, deformed, photo, 3d render")
    ap.add_argument("--out", required=True)
    ap.add_argument("--width", type=int, default=1536)
    ap.add_argument("--height", type=int, default=512)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--steps", type=int, default=30)
    ap.add_argument("--cfg", type=float, default=7.0)
    a = ap.parse_args()
    pid = post("/prompt", {"prompt": build(a.prompt, a.negative, a.width, a.height, a.seed, a.steps, a.cfg)})["prompt_id"]
    while True:
        hist = json.loads(get("/history/" + pid))
        if pid in hist:
            break
        time.sleep(1)
    img = hist[pid]["outputs"]["7"]["images"][0]
    data = get("/view?filename=%s&subfolder=%s&type=%s" % (img["filename"], img["subfolder"], img["type"]))
    import os
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    open(a.out, "wb").write(data)
    print("saved", a.out)


main()
