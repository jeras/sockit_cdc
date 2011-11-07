#!/bin/bash

# list of Verilog sources
sources="rtl/sockit_cdc.v tbn/cdc_tb.v"

# cleanup first
rm -f cdc_tb.out
rm -r cdc_tb.fst


# FIFO deepth
for cdc_ff in {2..16}
do
  # synchronization stages
  for cdc_ss in {1..3}
  do
    # compile Verilog sources (testbench and RTL)
    iverilog -o cdc_tb.out -DCDC_FF=$cdc_ff -DCDC_SS=$cdc_ss $sources
    # run the simulation
    vvp cdc_tb.out -none
  done
done


# compile Verilog sources (testbench and RTL)
iverilog -o cdc_tb.out -DCDC_FF=5 $sources
# run the simulation
vvp cdc_tb.out -fst
# open the waveform and detach it
gtkwave cdc_tb.fst cdc_tb.sav &
