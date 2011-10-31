#!/bin/bash

# cleanup first
rm -f cdc_tb.out
rm -r cdc_tb.fst

# compile Verilog sources (testbench and RTL) with Icarus Verilog
iverilog -o cdc_tb.out tbn/cdc_tb.v rtl/sockit_cdc.v

# run the simulation
vvp cdc_tb.out -fst

# open the waveform and detach it
gtkwave cdc_tb.fst cdc_tb.sav &
