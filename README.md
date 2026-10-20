# Edge AI FPGA Neural Network Accelerator

A compact **cat-versus-dog image classifier** with two inference paths: Raspberry Pi software inference and Raspberry Pi + Basys 3 FPGA inference over UART. The project demonstrates quantized neural-network deployment, FPGA control logic, hardware/software co-design, and a repeatable test workflow.

## Project at a glance

- **Task:** classify an image as Cat (`0x00`) or Dog (`0x01`)
- **Model:** 2,352 inputs → 64 hidden neurons → 32 hidden neurons → 1 output
- **Input:** 28 × 28 RGB image; 2,352 signed 8-bit pixel values (pixel value minus 128)
- **Hardware:** Raspberry Pi and Digilent Basys 3 (Artix-7 `xc7a35tcpg236-1`)
- **FPGA interface:** USB-UART, 115200 baud
- **Toolchain used:** Xilinx Vivado 2016.4
- **Reported quantized validation accuracy:** 72.5% on a 40-image validation split (see [metrics](trained_model/metrics.json))

This is an educational prototype, not a production-grade image-recognition system.

## How it works

```text
                         ┌──────────────────────────┐
                         │   Input image (JPG/PNG)  │
                         └─────────────┬────────────┘
                                       │
                         Resize/crop to 28 × 28 RGB
                                       │
                         Convert pixels to signed int8
                                       │
                  ┌────────────────────┴────────────────────┐
                  │                                         │
           Raspberry Pi only                       Raspberry Pi + FPGA
           NumPy inference                         Send 2,352 bytes over UART
                  │                                         │
                  │                                Basys 3 VHDL inference
                  │                                         │
                  └────────────────────┬────────────────────┘
                                       │
                              Cat (0) or Dog (1)
```

## Repository layout

- `project_1.xpr` — Vivado project file
- `project_1.srcs/sources_1/new/` — VHDL design sources
- `project_1.srcs/constrs_1/new/constraint.xdc` — Basys 3 pin constraints
- `project_1.srcs/sim_1/new/testbench.vhd` — simulation testbench
- `raspberry_pi/` — Pi-only, FPGA, and batch classification scripts plus the quantized model
- `trained_model/` — quantized model, metrics, and ROM memory initialization files
- `tools/train_export_weights.py` — training and weight/ROM export script
- `tools/check_synth.tcl` — synthesis status helper
- `generated_bitstreams/` — previously generated `.bit` and `.mcs` files
- Root-level copies of earlier files are retained for backward compatibility.

Training images and selected demo images are **not included** in this repository. Add data only when you have permission to redistribute it.

## Raspberry Pi setup

Install the Python dependencies:

```bash
python3 -m pip install numpy pillow pyserial
```

Run software-only inference with a local image:

```bash
cd raspberry_pi
python3 pi_only_classify.py /path/to/image.jpg
```

Run inference through the FPGA (connect the Basys 3 via USB and check the serial port first):

```bash
python3 pi_fpga_classify.py /path/to/image.jpg
```

The FPGA script defaults to `/dev/ttyUSB1`. Update `PORT` in `pi_fpga_classify.py` if your device appears under a different port. The batch script accepts an optional port argument:

```bash
python3 batch_test.py /path/to/cat.jpg /path/to/dog.jpg
python3 batch_test.py --fpga --port /dev/ttyUSB1 /path/to/cat.jpg /path/to/dog.jpg
```

## Rebuild the FPGA design

1. Open `project_1.xpr` in Vivado 2016.4.
2. Confirm the selected part is `xc7a35tcpg236-1` (Basys 3).
3. Run synthesis and implementation, then generate the bitstream.
4. Review the UART and pin constraints before programming the board.
5. Test with known input images and compare the FPGA and Pi-only outputs.

The checked-in bitstream and MCS files are prior generated artifacts; rebuild them if you change the HDL, constraints, or model weights.

## Training and exporting weights

The training script expects a local dataset in:

```text
dataset_extracted/dataset/cat/
dataset_extracted/dataset/dog/
```

The image dataset is intentionally excluded from Git. After providing a dataset you are permitted to use, run:

```bash
python3 -m pip install numpy pillow
python3 tools/train_export_weights.py
```

Check the script output and review `trained_model/metrics.json` before describing results. The reported accuracy is specific to the current small validation split and should not be generalized to all images.

## Limitations

- The model is deliberately small and quantized for an FPGA demonstration.
- Validation data is limited; reported accuracy is not a general benchmark.
- FPGA round-trip time includes serial communication as well as inference.
- Verify hardware pin assignments, serial-port name, and toolchain version for your own setup.

## License

See [LICENSE](LICENSE).
