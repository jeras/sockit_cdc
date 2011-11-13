#!/bin/bash

# list of Verilog sources
sources="tbn/cdc_tb.v rtl/sockit_cdc.v"

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
    iverilog -o cdc_tb.out           -DCDC_FF=$cdc_ff       -DCDC_SS=$cdc_ss $sources
    #irun -sv -64bit -access +r -define CDC_FF=$cdc_ff -define CDC_SS=$cdc_ss $sources
    # run the simulation
    vvp cdc_tb.out -none
  done
done


# compile Verilog sources (testbench and RTL)
iverilog -o cdc_tb.out           -DCDC_FF=5       -DCDC_OH=1 $sources
#irun -sv -64bit -access +r -define CDC_FF=5 -define CDC_OH=1 $sources
# run the simulation
vvp cdc_tb.out -fst
# open the waveform and detach it
gtkwave cdc_tb.fst cdc_tb.sav &
