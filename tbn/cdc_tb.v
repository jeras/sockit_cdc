////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

`timescale 1us / 1ns

module cdc_tb ();

parameter     CW = 1;   // counter width
parameter     DW = 8;   // data    width

// input port
reg           cdi_clk;  // clock
reg           cdi_rst;  // reset
wire          cdi_clr;  // clear
wire [DW-1:0] cdi_dat;  // data
reg           cdi_req;  // request
wire          cdi_grt;  // grant

wire          cdi_trn;  // transfer
integer       cdi_cnt;  // counter
real          cdi_per;  // period
reg  [32-1:0] cdi_rnd;  // random
reg  [32-1:0] cdi_prb;  // probability

// output port
reg           cdo_clk;  // clock
reg           cdo_rst;  // reset
wire          cdo_clr;  // clear
wire [DW-1:0] cdo_dat;  // data
wire          cdo_req;  // request
reg           cdo_grt;  // grant

wire          cdo_trn;  // transfer
integer       cdo_cnt;  // counter
real          cdo_per;  // period
reg  [32-1:0] cdo_rnd;  // random
reg  [32-1:0] cdo_prb;  // probability

// monitoring
integer error = 0;

////////////////////////////////////////////////////////////////////////////////
// clocks and resets
////////////////////////////////////////////////////////////////////////////////

initial              cdi_clk = 1'b1;
always #(cdi_per/2)  cdi_clk = ~cdi_clk;

initial              cdo_clk = 1'b1;
always #(cdo_per/2)  cdo_clk = ~cdo_clk;

initial begin
  cdi_rst = 1'b1;
  repeat (4) @ (posedge cdi_clk);
  cdi_rst = 1'b0;
end

initial begin
  cdo_rst = 1'b1;
  repeat (4) @ (posedge cdo_clk);
  cdo_rst = 1'b0;
end

initial begin
  cdi_per = 10.0;
  cdo_per = 10.0;
end

////////////////////////////////////////////////////////////////////////////////
// control signals
////////////////////////////////////////////////////////////////////////////////

assign cdi_clr = 1'b0;
assign cdo_clr = 1'b0;

assign cdi_trn = cdi_req & cdi_grt;
assign cdo_trn = cdo_req & cdo_grt;

always @ (posedge cdi_clk, posedge cdi_rst)
if (cdi_rst)  cdi_req <= 1'b0;
else          cdi_req <= ~cdi_req | cdi_trn ? $random(cdi_rnd) < cdi_prb : 1'b1;

always @ (posedge cdo_clk, posedge cdo_rst)
if (cdo_rst)  cdo_grt <= 1'b0;
else          cdo_grt <= ~cdo_grt | cdo_trn ? $random(cdo_rnd) < cdo_prb : 1'b1;

initial begin
  cdi_rnd = 0;
  cdo_rnd = 1;
end

initial begin
  cdi_prb = 32'h7fffffff;
  cdo_prb = 32'h7fffffff;
end

////////////////////////////////////////////////////////////////////////////////
// counters 
////////////////////////////////////////////////////////////////////////////////

always @ (posedge cdi_clk, posedge cdi_rst)
if (cdi_rst)       cdi_cnt <= 0;
else if (cdi_trn)  cdi_cnt <= cdi_cnt + 1;

always @ (posedge cdo_clk, posedge cdo_rst)
if (cdo_rst)       cdo_cnt <= 1'b0;
else if (cdo_trn)  cdo_cnt <= cdo_cnt + 1;

////////////////////////////////////////////////////////////////////////////////
// data signals
////////////////////////////////////////////////////////////////////////////////

assign cdi_dat = cdi_cnt [DW-1:0];

always @ (posedge cdo_clk)
if (cdo_trn & (cdo_dat !== cdo_cnt [DW-1:0])) begin
  error <= error + 1;
end

////////////////////////////////////////////////////////////////////////////////
// test status
////////////////////////////////////////////////////////////////////////////////

// request for a dump file
initial begin
  $dumpfile("cdc_tb.fst");
  $dumpvars(0, cdc_tb);
end

always @ (posedge cdo_clk)
if (cdo_cnt == 64)  $finish();

////////////////////////////////////////////////////////////////////////////////
// DUT instance
////////////////////////////////////////////////////////////////////////////////

// data output
sockit_cdc #(
  .CW       (CW),
  .DW       (DW)
) cdc (
  // input port
  .cdi_clk  (cdi_clk),
  .cdi_rst  (cdi_rst),
  .cdi_clr  (cdi_clr),
  .cdi_dat  (cdi_dat),
  .cdi_req  (cdi_req),
  .cdi_grt  (cdi_grt),
  // output port
  .cdo_clk  (cdo_clk),
  .cdo_rst  (cdo_rst),
  .cdo_clr  (cdo_clr),
  .cdo_dat  (cdo_dat),
  .cdo_req  (cdo_req),
  .cdo_grt  (cdo_grt)
);

endmodule
