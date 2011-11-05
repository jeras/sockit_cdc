#!/bin/bash

# list of Verilog sources
sources="rtl/sockit_cdc.v tbn/cdc_tb.v"

# cleanup first
rm -f cdc_tb.out
rm -r cdc_tb.fst


for cdc_ff in {2..16}
do
  # compile Verilog sources (testbench and RTL)
  iverilog -o cdc_tb.out -DCDC_FF=$cdc_ff $sources
  # run the simulation
  vvp cdc_tb.out -none
done


# compile Verilog sources (testbench and RTL)
iverilog -o cdc_tb.out -DCDC_FF=5 $sources
# run the simulation
vvp cdc_tb.out -fst
# open the waveform and detach it
gtkwave cdc_tb.fst cdc_tb.sav &
