#!/bin/bash

sources="gray_tb.out tbn/gray_tb.v"

# cleanup first
rm -f gray_tb.out

for cdc_ff in "2" "3" "4" "5" 
do
  # compile Verilog sources (testbench and RTL) with Icarus Verilog
  iverilog -o -DCDC_FF=$cdc_ff

  # run the simulation
  vvp gray_tb.out 
done
