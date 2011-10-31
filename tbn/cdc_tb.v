////////////////////////////////////////////////////////////////////////////////
// 
////////////////////////////////////////////////////////////////////////////////

`timescale 1us / 1ns

module cdc_tb ();

parameter     FF = 4;   // counter width
parameter     DW = 8;   // data    width

// input port
reg           ffi_clk;  // clock
reg           ffi_rst;  // reset
wire [DW-1:0] ffi_bus;  // data
reg           ffi_req;  // request
wire          ffi_grt;  // grant

wire          ffi_trn;  // transfer
integer       ffi_cnt;  // counter
real          ffi_per;  // period
reg  [32-1:0] ffi_rnd;  // random
reg  [32-1:0] ffi_prb;  // probability

// output port
reg           ffo_clk;  // clock
reg           ffo_rst;  // reset
wire [DW-1:0] ffo_bus;  // data
wire          ffo_req;  // request
reg           ffo_grt;  // grant

wire          ffo_trn;  // transfer
integer       ffo_cnt;  // counter
real          ffo_per;  // period
reg  [32-1:0] ffo_rnd;  // random
reg  [32-1:0] ffo_prb;  // probability

// monitoring
integer error = 0;

////////////////////////////////////////////////////////////////////////////////
// clocks and resets
////////////////////////////////////////////////////////////////////////////////

initial              ffi_clk = 1'b1;
always #(ffi_per/2)  ffi_clk = ~ffi_clk;

initial              ffo_clk = 1'b1;
always #(ffo_per/2)  ffo_clk = ~ffo_clk;

initial begin
  ffi_rst = 1'b1;
  repeat (4) @ (posedge ffi_clk);
  ffi_rst = 1'b0;
end

initial begin
  ffo_rst = 1'b1;
  repeat (4) @ (posedge ffo_clk);
  ffo_rst = 1'b0;
end

initial begin
  ffi_per = 10.0;
  ffo_per = 10.0;
end

////////////////////////////////////////////////////////////////////////////////
// control signals
////////////////////////////////////////////////////////////////////////////////

assign ffi_trn = ffi_req & ffi_grt;
assign ffo_trn = ffo_req & ffo_grt;

always @ (posedge ffi_clk, posedge ffi_rst)
if (ffi_rst)  ffi_req <= 1'b0;
else          ffi_req <= ~ffi_req | ffi_trn ? $random(ffi_rnd) < ffi_prb : 1'b1;

always @ (posedge ffo_clk, posedge ffo_rst)
if (ffo_rst)  ffo_grt <= 1'b0;
else          ffo_grt <= ~ffo_grt | ffo_trn ? $random(ffo_rnd) < ffo_prb : 1'b1;

initial begin
  ffi_rnd = 0;
  ffo_rnd = 1;
end

initial begin
  ffi_prb = 32'h7fffffff;
  ffo_prb = 32'h7fffffff;
end

////////////////////////////////////////////////////////////////////////////////
// counters 
////////////////////////////////////////////////////////////////////////////////

always @ (posedge ffi_clk, posedge ffi_rst)
if (ffi_rst)       ffi_cnt <= 0;
else if (ffi_trn)  ffi_cnt <= ffi_cnt + 1;

always @ (posedge ffo_clk, posedge ffo_rst)
if (ffo_rst)       ffo_cnt <= 1'b0;
else if (ffo_trn)  ffo_cnt <= ffo_cnt + 1;

////////////////////////////////////////////////////////////////////////////////
// data signals
////////////////////////////////////////////////////////////////////////////////

assign ffi_bus = ffi_cnt [DW-1:0];

always @ (posedge ffo_clk)
if (ffo_trn & (ffo_bus !== ffo_cnt [DW-1:0])) begin
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

// test correct end
always @ (posedge ffo_clk)
if (ffo_cnt == 64)  $finish();

// test timeout
initial begin
  #10000 $finish();
end

////////////////////////////////////////////////////////////////////////////////
// DUT instance
////////////////////////////////////////////////////////////////////////////////

// data output
sockit_cdc #(
  .FF       (FF),
  .DW       (DW)
) cdc (
  // input port
  .ffi_clk  (ffi_clk),
  .ffi_rst  (ffi_rst),
  .ffi_bus  (ffi_bus),
  .ffi_req  (ffi_req),
  .ffi_grt  (ffi_grt),
  // output port
  .ffo_clk  (ffo_clk),
  .ffo_rst  (ffo_rst),
  .ffo_bus  (ffo_bus),
  .ffo_req  (ffo_req),
  .ffo_grt  (ffo_grt)
);

endmodule
