#!/bin/bash

# cleanup first
rm -f gray_tb.out

# compile Verilog sources (testbench and RTL) with Icarus Verilog
iverilog -o gray_tb.out tbn/gray_tb.v

# run the simulation
vvp gray_tb.out
