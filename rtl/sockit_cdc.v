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
  parameter CW = $clog2(FF),     // counter width
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
  output wire [DW-1:0] ffo_bus,  // data
  output wire          ffo_req,  // request
  input  wire          ffo_grt   // grant
);

////////////////////////////////////////////////////////////////////////////////
// gray code related functions
////////////////////////////////////////////////////////////////////////////////

// conversion from integer to gray
function automatic [CW-1:0] int2gry (input [CW-1:0] val);                                                                                                               integer i;
begin
  for (i=0; i<CW-1; i=i+1)  int2gry[i] = val[i+1] ^ val[i];
  int2gry[CW-1] = val[CW-1];
end
endfunction

// conversion from gray to integer
function automatic [CW-1:0] gry2int (input [CW-1:0] val);
  integer i;
begin
  gry2int[CW-1] = val[CW-1];
  for (i=CW-1; i>0; i=i-1)  gry2int[i-1] = val[i-1] ^ gry2int[i];
end
endfunction

// gray increment (with conversion into integer and back to gray)
function automatic [CW-1:0] gry_inc (input [CW-1:0] gry_cng); 
begin
  gry_inc = int2gry (gry2int (gry_cng) + 'd1);
end
endfunction

////////////////////////////////////////////////////////////////////////////////
// local signals                                                              //
////////////////////////////////////////////////////////////////////////////////

// input port
wire          ffi_trn;           // transfer
reg  [CW-1:0] ffi_syn [SS-1:0];  // synchronization
reg  [CW-1:0] ffi_cnb;           // counter binary
reg  [CW-1:0] ffi_cng;           // counter gray
wire [CW-1:0] ffi_inb;           // increment binary
wire [CW-1:0] ffi_ing;           // increment gray
wire          ffi_cne;           // counter end
reg           ffi_cns;           // counter set

// CDC FIFO memory
reg  [DW-1:0] cdc_mem [0:2**CW-1];

// output port
wire          ffo_trn;           // transfer
reg  [CW-1:0] ffo_syn [SS-1:0];  // synchronization
reg  [CW-1:0] ffo_cnb;           // counter binary
reg  [CW-1:0] ffo_cng;           // counter gray
wire [CW-1:0] ffo_inb;           // increment binary
wire [CW-1:0] ffo_ing;           // increment gray
reg           ffo_cns;           // counter set
wire          ffo_cne;           // counter end

// generate loop index
genvar i;

////////////////////////////////////////////////////////////////////////////////
// input port                                                                 //
////////////////////////////////////////////////////////////////////////////////

// transfer
assign ffi_trn = ffi_req & ffi_grt;

// synchronization
generate for (i=0; i<SS; i=i+1) begin
  if (i==0) begin
    always @ (posedge ffi_clk, posedge ffi_rst)
    if (ffi_rst)  ffi_syn [i] <= {CW{1'b0}};
    else          ffi_syn [i] <= {ffo_cns, ffo_cng};
  end else begin
    always @ (posedge ffi_clk, posedge ffi_rst)
    if (ffi_rst)  ffi_syn [i] <= {CW{1'b0}};
    else          ffi_syn [i] <= ffi_syn [i-1];
  end
end endgenerate

// counter end
assign ffi_cne = fli_cnb == (FF-1);

// increment binary
assign ffi_inb = fli_cne ? {CW{1'b0}} : fli_cnb+1;

// counter binary
always @ (posedge ffi_clk, posedge ffi_rst)
if (ffi_rst)       ffi_cnb <= {CW{1'b0}};
else if (ffi_trn)  ffi_cnb <= ffi_inb;

// increment gray
assign ffi_ing = fli_cne ? {CW{1'b0}} : gry_inc (ffi_cng);

// counter gray
always @ (posedge ffi_clk, posedge ffi_rst)
if (ffi_rst)       ffi_cng <= {CW{1'b0}};
else if (ffi_trn)  ffi_cng <= ffi_ing;

// counter set
always @ (posedge ffi_clk, posedge ffi_rst)
if (ffi_rst)       ffi_cns <= {CW{1'b0}};
else if (ffi_trn)  ffi_cns <= ffi_cns ^ ffi_cne;

// status
assign ffi_grt = ffi_syn [SS-1] != {ffi_set, ffi_cng};

// data memory
always @ (posedge ffi_clk)
if (ffi_trn) cdc_mem [ffi_cnb] <= ffi_bus;

////////////////////////////////////////////////////////////////////////////////
// output port                                                                //
////////////////////////////////////////////////////////////////////////////////

// transfer
assign ffo_trn = ffo_req & ffo_grt;

// synchronization
generate for (i=0; i<SS; i=i+1) begin
  if (i==0) begin
    always @ (posedge ffo_clk, posedge ffo_rst)
    if (ffo_rst)  ffo_syn [i] <= {CW{1'b0}};
    else          ffo_syn [i] <= {ffo_cns, ffi_cng};
  end else begin
    always @ (posedge ffo_clk, posedge ffo_rst)
    if (ffo_rst)  ffo_syn [i] <= {CW{1'b0}};
    else          ffo_syn [i] <= ffo_syn [i-1];
  end
end endgenerate

// counter end
assign ffo_cne = flo_cnb == (FF-1);

// increment binary
assign ffo_inb = flo_cne ? {CW{1'b0}} : flo_cnb+1;

// counter binary
always @ (posedge ffo_clk, posedge ffo_rst)
if (ffo_rst)       ffo_cnb <= {CW{1'b0}};
else if (ffo_trn)  ffo_cnb <= ffo_inb;

// increment gray
assign ffo_ing = flo_cne ? {CW{1'b0}} : gry_inc (ffo_cng);

// counter gray
always @ (posedge ffo_clk, posedge ffo_rst)
if (ffo_rst)       ffo_cng <= {CW{1'b0}};
else if (ffo_trn)  ffo_cng <= ffo_ing;

// counter set
always @ (posedge ffo_clk, posedge ffo_rst)
if (ffo_rst)       ffo_cns <= {CW{1'b0}};
else if (ffo_trn)  ffo_cns <= ffo_cns ^ ffo_cne;

// status
assign ffo_req = ffo_syn [SS-1] != {ffo_set, ffo_cng};

// asynchronous output data
assign ffo_bus = cdc_mem [ffo_cnb];

endmodule
