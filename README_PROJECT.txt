Cat/Dog Raspberry Pi + Basys3 FPGA Project
===========================================

Project summary
---------------
This project classifies a cat/dog image using two implementations:
1. Raspberry Pi only: Pi preprocesses the image and runs the quantized neural network in Python/NumPy.
2. Raspberry Pi + FPGA: Pi preprocesses the image, sends 2352 bytes over USB-UART to Basys3, FPGA runs the neural network, FPGA returns one byte.

Class output:
0x00 = Cat
0x01 = Dog

Model/input format
------------------
Image preprocessing:
- Resize/crop image to 28 x 28 RGB.
- Flatten to 2352 values: 28 * 28 * 3.
- Convert each pixel from 0..255 to signed int8 by subtracting 128.

Neural network shape:
2352 inputs -> 64 hidden neurons -> 32 hidden neurons -> 1 output

Current measured quantized validation accuracy:
72.5% on the 40-image validation split.

Important Vivado details
------------------------
Vivado version used: 2016.4
FPGA part: xc7a35tcpg236-1
Top module: top_level
Board style: Basys3 / Artix-7
UART baud: 115200
Input byte count: 2352

Important files/folders
-----------------------
project_1.xpr                         Vivado project file
project_1.srcs/                       VHDL sources and constraints
trained_model/                        Quantized weights and ROM .mem files
raspberry_pi/                         Pi scripts for testing/demo
tools/train_export_weights.py         Training and VHDL/ROM export script
dataset_extracted/dataset/cat         Cat training images
dataset_extracted/dataset/dog         Dog training images
selected_test_images/                 Small named demo image set
generated_bitstreams/top_level.bit    Generated FPGA bitstream
generated_bitstreams/top_level.mcs    Flash programming file

Raspberry Pi setup
------------------
Copy raspberry_pi/ files and selected test images to one folder on the Pi, for example:
~/catdog_fpga

Install dependencies:
sudo apt install python3-serial python3-pil python3-numpy -y

Pi-only tests:
python3 pi_only_classify.py cat_test_01.jpg
python3 pi_only_classify.py dog_test_01.jpg

FPGA tests:
Make sure Basys3 is plugged into the Pi by USB, powered on, and DONE LED is on.
Press Basys3 btnC once before testing.
python3 pi_fpga_classify.py cat_test_01.jpg
python3 pi_fpga_classify.py dog_test_01.jpg

Batch tests:
python3 batch_test.py
python3 batch_test.py --fpga

Vivado rebuild flow
-------------------
1. Open project_1.xpr in Vivado 2016.4.
2. Run Synthesis.
3. Run Implementation.
4. Generate Bitstream.
5. Program Device with project_1.runs/impl_1/top_level.bit.
6. Generate Memory Configuration File:
   - Format: MCS
   - Custom Memory Size: 4 MB
   - Interface: SPIx1
   - Load bitstream file: top_level.bit
   - Output: top_level.mcs
7. Program configuration memory device s25fl032p-spi-x1_x2_x4 with top_level.mcs.
8. Power-cycle Basys3 and confirm DONE LED turns on.

Windows driver warning
----------------------
The original development PC had crashes when using Vivado Hardware Manager with Basys3. This is likely a Digilent/Xilinx USB driver issue, not a VHDL issue. If this happens:
- Do not repeatedly retry Auto Connect.
- Reinstall Digilent/Xilinx cable drivers.
- Memory Integrity may need to be off for old Vivado 2016.4 drivers.
- Prefer using a stable lab PC for programming.

Report/demo notes
-----------------
Explain that FPGA time includes USB-UART communication plus FPGA inference. Pi-only time measures software inference on the Pi. The model is intentionally small and quantized for FPGA implementation, so it is a demonstration classifier rather than a modern high-accuracy model.
