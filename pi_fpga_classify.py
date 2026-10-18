import sys
import time
from pathlib import Path

import serial
from PIL import Image, ImageOps


PORT = "/dev/ttyUSB1"
BAUD = 115200
IMG_SIZE = 28


def image_to_fpga_bytes(path):
    img = Image.open(path).convert("RGB")
    img = ImageOps.fit(img, (IMG_SIZE, IMG_SIZE), method=Image.Resampling.LANCZOS)
    pixels = img.tobytes()
    return bytes(((p - 128) & 0xFF) for p in pixels)


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 pi_fpga_classify.py image.jpg")
        sys.exit(1)

    image_path = Path(sys.argv[1])
    data = image_to_fpga_bytes(image_path)
    if len(data) != 2352:
        raise RuntimeError(f"Expected 2352 bytes, got {len(data)}")

    start = time.perf_counter()
    ser = serial.Serial(PORT, BAUD, timeout=10, write_timeout=10)
    ser.write(data)
    ser.flush()
    reply = ser.read(1)
    ser.close()
    elapsed_ms = (time.perf_counter() - start) * 1000

    if not reply:
        print("No reply from FPGA")
        sys.exit(2)

    label = "Dog" if reply[0] == 1 else "Cat"
    print(f"FPGA result: {label} (0x{reply[0]:02X})")
    print(f"FPGA round-trip time: {elapsed_ms:.2f} ms")


if __name__ == "__main__":
    main()
