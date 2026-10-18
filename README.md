# Edge AI System with FPGA-Based Neural Network Acceleration

A hardware-accelerated image classification system that performs Cat vs Dog recognition using a quantized neural network implemented on a Basys3 FPGA.

## Overview

This project demonstrates hardware-software co-design by combining Raspberry Pi image preprocessing with FPGA-accelerated neural network inference.

Two implementations are provided:

1. Raspberry Pi only inference
2. Raspberry Pi + FPGA hardware acceleration

The system classifies images as either:

- Cat (0x00)
- Dog (0x01)

## Features

- Image preprocessing on Raspberry Pi
- Quantized neural network
- FPGA inference engine
- UART communication
- Basys3 FPGA implementation
- Performance comparison between software and hardware inference

## Neural Network Architecture

2352 Inputs
↓
64 Hidden Neurons
↓
32 Hidden Neurons
↓
1 Output

Image Size:
28 × 28 RGB

Input Features:
2352 signed INT8 values

## Hardware

- Raspberry Pi
- Basys3 FPGA Board
- Artix-7 XC7A35T FPGA

## Software

- Python
- NumPy
- Pillow
- Vivado 2016.4
- VHDL

## Communication

USB-UART

Baud Rate: 115200

Input:
2352 bytes

Output:
1 byte

0x00 = Cat
0x01 = Dog

## Results

Quantized Validation Accuracy:
72.5%

## Team

- Eyad Mohamed
- Abdelrahman Diab
- Abdelwahab Mohamed
- Ahmed El-Shahat
- Belal Ramadan
- Mohamed Aboammo

## Course

ELCT 601 - Digital System Design
German University in Cairo
Spring 2026
