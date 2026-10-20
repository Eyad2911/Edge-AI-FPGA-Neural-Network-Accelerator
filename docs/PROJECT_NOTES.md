# Hardware Setup and Demo Notes

## Target Hardware and Toolchain

- FPGA board: Digilent Basys 3
- FPGA part: `xc7a35tcpg236-1` (Artix-7)
- Original project toolchain: Xilinx Vivado 2016.4
- Top-level HDL entity: `top_level`
- UART baud rate: 115200
- UART payload: 2,352 input bytes per image; one-byte classification result

Classification labels:
- `0x00` = Cat
- `0x01` = Dog

## Raspberry Pi Setup

Install dependencies on the Raspberry Pi:

```bash
sudo apt install python3-serial python3-pil python3-numpy -y
```

The runtime scripts and model for copying to the Raspberry Pi are in `raspberry_pi/`. Copy one or more test images to the same working folder on the Pi; sample images are not included in this repository.

Software-only inference:

```bash
python3 pi_only_classify.py /path/to/image.jpg
```

FPGA inference (first check the serial port and update the `PORT` setting in `pi_fpga_classify.py` if needed):

```bash
python3 pi_fpga_classify.py /path/to/image.jpg
```

Batch tests:

```bash
python3 batch_test.py /path/to/cat.jpg /path/to/dog.jpg
python3 batch_test.py --fpga --port /dev/ttyUSB1 /path/to/cat.jpg /path/to/dog.jpg
```

## Rebuild and Program the FPGA

1. Open `project_1.xpr` in Vivado 2016.4.
2. Confirm the target part is `xc7a35tcpg236-1`.
3. Run synthesis and implementation, then generate the bitstream.
4. Review the pin constraints and UART setup before connecting hardware.
5. To produce a flash image, use **Generate Memory Configuration File** with format **MCS**, custom memory size **4 MB**, and interface **SPIx1**. Use the generated `top_level.bit` as input and save the result as `generated_bitstreams/top_level.mcs`.
6. Program configuration memory using the compatible `s25fl032p-spi-x1_x2_x4` device setting, then power-cycle the board and check the DONE LED.

Generated bitstreams in the repository are previous build outputs. Rebuild them whenever HDL, constraints, or model data changes.

## Training Data and Metrics

The training dataset is intentionally not tracked in Git. If you have rights to use the images, place them locally under:

```text
dataset_extracted/dataset/cat/
dataset_extracted/dataset/dog/
```

Then run `python3 tools/train_export_weights.py` after installing NumPy and Pillow. The README-reported 72.5% validation accuracy is from a small 40-image split and should not be interpreted as a general performance guarantee.

## Troubleshooting Note

The original development notes reported crashes in Vivado Hardware Manager on one Windows PC when connecting to the Basys 3. This is a machine-specific observation, not a confirmed diagnosis. If it happens, check the installed Digilent/Xilinx cable drivers and consider programming from a supported lab PC.

## Security and Reproducibility

Do not commit personal credentials, network passwords, private tokens, or private data. Record the exact toolchain, board settings, test images, and test procedure when reporting new measurements.
