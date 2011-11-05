////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//  CDC (clock domain crossing) general purpose FIFO with gray counter        //
//                                                                            //
//  Copyright (C) 2011  Iztok Jeras                                           //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//  This RTL is free hardware: you can redistribute it and/or modify          //
//  it under the terms of the GNU Lesser General Public License               //
//  as published by the Free Software Foundation, either                      //
//  version 3 of the License, or (at your option) any later version.          //
//                                                                            //
//  This RTL is distributed in the hope that it will be useful,               //
//  but WITHOUT ANY WARRANTY; without even the implied warranty of            //
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             //
//  GNU General Public License for more details.                              //
//                                                                            //
//  You should have received a copy of the GNU General Public License         //
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.     //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
//                                                                            //
// Handshaking protocol:                                                      //
//                                                                            //
// Both the input and the output port employ the same handshaking mechanism.  //
// The data source sets the request signal (*_req) and the data drain         //
// confirms the transfer by setting the grant signal (*_grt).                 //
//                                                                            //
//            --------   req   -----------------   req   --------             //
//            )    S | ------> | D           S | ------> | D    (             //
//            (    R |         | R    CDC    R |         | R    )             //
//            )    C | <------ | N           C | <------ | N    (             //
//            --------   grt   -----------------   grt   --------             //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module sockit_cdc #(
  parameter FF = 4,              // FIFO deepth
  parameter SS = 2,              // synchronization stages
  parameter RI = 1,              // registered input  data
  parameter RO = 1,              // registered output data
  parameter DW = 1               // data    width
)(
  // input port
  input  wire          ffi_clk,  // clock
  input  wire          ffi_rst,  // reset
  input  wire [DW-1:0] ffi_bus,  // data
  input  wire          ffi_req,  // request
  output wire          ffi_grt,  // grant
  // output port
  input  wire          ffo_clk,  // clock
  input  wire          ffo_rst,  // reset
  output wor  [DW-1:0] ffo_bus,  // data
  output wire          ffo_req,  // request
  input  wire          ffo_grt   // grant
);

localparam WB = $clog2(FF);      // counter width
localparam WG = WB+1;            // counter width

////////////////////////////////////////////////////////////////////////////////
// gray code related functions
////////////////////////////////////////////////////////////////////////////////

// conversion from integer to gray
function automatic [WG-1:0] int2gry (input [WG-1:0] val);
  integer i;
begin
  for (i=0; i<WG-1; i=i+1)  int2gry[i] = val[i+1] ^ val[i];
  int2gry[WG-1] = val[WG-1];
end
endfunction

// conversion from gray to integer
function automatic [WG-1:0] gry2int (input [WG-1:0] val);
  integer i;
begin
  gry2int[WG-1] = val[WG-1];
  for (i=WG-1; i>0; i=i-1)  gry2int[i-1] = val[i-1] ^ gry2int[i];
end
endfunction

// gray increment (with conversion into integer and back to gray)
function automatic [WG-1:0] gry_inc (input [WG-1:0] gry_cng); 
begin
  gry_inc = int2gry (gry2int (gry_cng) + 'd1);
end
endfunction

////////////////////////////////////////////////////////////////////////////////
// local signals                                                              //
////////////////////////////////////////////////////////////////////////////////

// input port
wire          ffi_trn;           // transfer
wire          ffi_cne;           // counter end
reg  [FF-1:0] ffi_cnh;           // counter one hot
reg  [WG-1:0] ffi_cnr;           // counter gray reference
reg  [WG-1:0] ffi_cng;           // counter gray
reg  [WG-1:0] ffi_syn [SS-1:0];  // synchronization

// CDC FIFO memory
reg  [DW-1:0] cdc_mem [0:FF-1];

// output port
wire          ffo_trn;           // transfer
wire          ffo_cne;           // counter end
reg  [FF-1:0] ffo_cnh;           // counter one hot
reg  [WG-1:0] ffo_cng;           // counter gray
reg  [WG-1:0] ffo_syn [SS-1:0];  // synchronization

// generate loop index
genvar i;

////////////////////////////////////////////////////////////////////////////////
// input port data/memory logic                                               //
////////////////////////////////////////////////////////////////////////////////

// transfer
assign ffi_trn = ffi_req & ffi_grt;

// counter end
assign ffi_cne = ffi_cnh [FF-1];

// increment binary

// counter binary
always @ (posedge ffi_clk, posedge ffi_rst)
if (ffi_rst)       ffi_cnh <= 'b1;
else if (ffi_trn)  ffi_cnh <= ffi_cne ? 'b1 : ffi_cnh << 1;

// data memory
generate for (i=0; i<FF; i=i+1) begin
always @ (posedge ffi_clk)
if (ffi_trn & ffi_cnh [i]) cdc_mem [i] <= ffi_bus;
end endgenerate

////////////////////////////////////////////////////////////////////////////////
// input port control/status logic                                            //
////////////////////////////////////////////////////////////////////////////////

// synchronization
generate for (i=0; i<SS; i=i+1) begin
  if (i==0) begin
    always @ (posedge ffi_clk, posedge ffi_rst)
    if (ffi_rst)  ffi_syn [i] <= {WG{1'b0}};
    else          ffi_syn [i] <= ffo_cng;
  end else begin
    always @ (posedge ffi_clk, posedge ffi_rst)
    if (ffi_rst)  ffi_syn [i] <= {WG{1'b0}};
    else          ffi_syn [i] <= ffi_syn [i-1];
  end
end endgenerate

// counter gray
always @ (posedge ffi_clk, posedge ffi_rst)
if (ffi_rst)       ffi_cng <= {WG{1'b0}};
else if (ffi_trn)  ffi_cng <= ffi_cne ? ffi_cng ^ {1'b1,{WB{1'b0}}} : gry_inc (ffi_cng);

// counter gray reference
always @ (posedge ffi_clk, posedge ffi_rst)
if (ffi_rst)       ffi_cnr <= int2gry(-FF);
else if (ffi_trn)  ffi_cnr <= ffi_cne ? ffi_cnr ^ {1'b1,{WB{1'b0}}} : gry_inc (ffi_cnr);

// status
assign ffi_grt = ffi_syn [SS-1] != ffi_cnr;

////////////////////////////////////////////////////////////////////////////////
// output port data/memory logic                                              //
////////////////////////////////////////////////////////////////////////////////

// transfer
assign ffo_trn = ffo_req & ffo_grt;

// counter end
assign ffo_cne = ffo_cnh [FF-1];

// counter one hot
always @ (posedge ffo_clk, posedge ffo_rst)
if (ffo_rst)       ffo_cnh <= 'b1;
else if (ffo_trn)  ffo_cnh <= ffo_cne ? 'b1 : ffo_cnh << 1;

// asynchronous output data
generate for (i=0; i<FF; i=i+1) begin
  assign ffo_bus = ffo_cnh [i] ? cdc_mem [i] : {DW{1'b0}};
end endgenerate

////////////////////////////////////////////////////////////////////////////////
// output port control/status logic                                           //
////////////////////////////////////////////////////////////////////////////////

// synchronization
generate for (i=0; i<SS; i=i+1) begin
  if (i==0) begin
    always @ (posedge ffo_clk, posedge ffo_rst)
    if (ffo_rst)  ffo_syn [i] <= {WG{1'b0}};
    else          ffo_syn [i] <= ffi_cng;
  end else begin
    always @ (posedge ffo_clk, posedge ffo_rst)
    if (ffo_rst)  ffo_syn [i] <= {WG{1'b0}};
    else          ffo_syn [i] <= ffo_syn [i-1];
  end
end endgenerate

// counter gray
always @ (posedge ffo_clk, posedge ffo_rst)
if (ffo_rst)       ffo_cng <= {WG{1'b0}};
else if (ffo_trn)  ffo_cng <= ffo_cne ? ffo_cng ^ {1'b1,{WB{1'b0}}} : gry_inc (ffo_cng);

// status
assign ffo_req = ffo_syn [SS-1] != ffo_cng;

endmodule
