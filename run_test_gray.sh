#!/bin/bash

sources="tbn/gray_tb.v"

# cleanup first
rm -f gray_tb.out

for cdc_ff in "2" "3" "4" "5" 
do
  # compile Verilog sources (testbench and RTL) with Icarus Verilog
  iverilog -o gray_tb.out -DCDC_FF=$cdc_ff $sources

  # run the simulation
  vvp gray_tb.out 
done
