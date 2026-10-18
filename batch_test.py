import argparse
import time
from pathlib import Path

import numpy as np
import serial
from PIL import Image, ImageOps


PORT = "/dev/ttyUSB1"
BAUD = 115200
IMG_SIZE = 28
SHIFT = 8
MODEL = Path(__file__).with_name("cat_dog_model_quantized.npz")


def image_to_int8(path):
    img = Image.open(path).convert("RGB")
    img = ImageOps.fit(img, (IMG_SIZE, IMG_SIZE), method=Image.Resampling.LANCZOS)
    arr = np.asarray(img, dtype=np.int16).reshape(-1) - 128
    return arr.astype(np.int64)


def image_to_fpga_bytes(path):
    x = image_to_int8(path)
    return bytes((int(v) & 0xFF) for v in x)


def pi_classify(path, q):
    x = image_to_int8(path)
    h1 = x @ q["w1"].astype(np.int64) + q["b1"].astype(np.int64)
    h1 = np.clip(h1 >> SHIFT, 0, 127)
    h2 = h1 @ q["w2"].astype(np.int64) + q["b2"].astype(np.int64)
    h2 = np.clip(h2 >> SHIFT, 0, 127)
    out = h2 @ q["w3"].astype(np.int64) + q["b3"].astype(np.int64)
    return int(out[0] > 0)


def expected_from_name(path):
    name = path.name.lower()
    if "cat" in name:
        return 0
    if "dog" in name:
        return 1
    return None


def label(v):
    return "Dog" if v == 1 else "Cat"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fpga", action="store_true", help="Also test the Basys3 FPGA over USB-UART")
    parser.add_argument("--port", default=PORT)
    parser.add_argument("images", nargs="*", default=[])
    args = parser.parse_args()

    images = [Path(p) for p in args.images]
    if not images:
        images = sorted(Path(".").glob("*.jpg"))

    q = np.load(MODEL)
    ser = None
    if args.fpga:
        ser = serial.Serial(args.port, BAUD, timeout=10, write_timeout=10)
        time.sleep(0.2)

    correct_pi = total_expected = 0
    correct_fpga = 0

    for path in images:
        exp = expected_from_name(path)
        pi_result = pi_classify(path, q)
        fpga_result = None
        fpga_time = None

        if ser is not None:
            data = image_to_fpga_bytes(path)
            start = time.perf_counter()
            ser.write(data)
            ser.flush()
            reply = ser.read(1)
            fpga_time = (time.perf_counter() - start) * 1000
            if reply:
                fpga_result = int(reply[0])

        if exp is not None:
            total_expected += 1
            correct_pi += int(pi_result == exp)
            if fpga_result is not None:
                correct_fpga += int(fpga_result == exp)

        expected_text = label(exp) if exp is not None else "Unknown"
        line = f"{path.name:20s} expected={expected_text:3s} pi={label(pi_result):3s}"
        if fpga_result is not None:
            line += f" fpga={label(fpga_result):3s} fpga_time={fpga_time:.1f}ms"
        elif ser is not None:
            line += " fpga=NoReply"
        print(line)

    if ser is not None:
        ser.close()

    if total_expected:
        print(f"Pi-only correct: {correct_pi}/{total_expected}")
        if args.fpga:
            print(f"FPGA correct: {correct_fpga}/{total_expected}")


if __name__ == "__main__":
    main()
