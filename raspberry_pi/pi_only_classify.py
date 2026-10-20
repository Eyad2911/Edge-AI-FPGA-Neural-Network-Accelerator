import sys
import time
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps


IMG_SIZE = 28
SHIFT = 8
MODEL = Path(__file__).with_name("cat_dog_model_quantized.npz")


def image_to_int8(path):
    img = Image.open(path).convert("RGB")
    img = ImageOps.fit(img, (IMG_SIZE, IMG_SIZE), method=Image.Resampling.LANCZOS)
    arr = np.asarray(img, dtype=np.int16).reshape(-1) - 128
    return arr.astype(np.int64)


def classify(x, q):
    h1 = x @ q["w1"].astype(np.int64) + q["b1"].astype(np.int64)
    h1 = np.clip(h1 >> SHIFT, 0, 127)
    h2 = h1 @ q["w2"].astype(np.int64) + q["b2"].astype(np.int64)
    h2 = np.clip(h2 >> SHIFT, 0, 127)
    out = h2 @ q["w3"].astype(np.int64) + q["b3"].astype(np.int64)
    return int(out[0] > 0)


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 pi_only_classify.py image.jpg")
        sys.exit(1)

    start = time.perf_counter()
    q = np.load(MODEL)
    x = image_to_int8(sys.argv[1])
    result = classify(x, q)
    elapsed_ms = (time.perf_counter() - start) * 1000

    label = "Dog" if result == 1 else "Cat"
    print(f"Pi-only result: {label} (0x{result:02X})")
    print(f"Pi-only inference time: {elapsed_ms:.2f} ms")


if __name__ == "__main__":
    main()
