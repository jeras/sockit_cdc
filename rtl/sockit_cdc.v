////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//  SPI (3 wire, dual, quad) master                                           //
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
//                       ----------   req    ----------                       //
//                       )      S | ------>  | D      (                       //
//                       (      R |          | R      )                       //
//                       )      C | <------  | N      (                       //
//                       ----------   grt    ----------                       //
//                                                                            //
// Clear signal:                                                              //
//                                                                            //
// The *_clr signal provides an optional synchronous clear of data counters.  //
// To be precise by applying clear the counter of the applied side copies the //
// counter value from the opposite side, thus causing the data still stored   //
// inside the FIFO to be thrown out.                                          //
//                                                                            //
//                                                                            //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module sockit_cdc #(
  parameter    CW = 1,   // counter width
  parameter    DW = 1    // data    width
)(
  // input port
  input  wire          cdi_clk,  // clock
  input  wire          cdi_rst,  // reset
  input  wire          cdi_clr,  // clear
  input  wire [DW-1:0] cdi_dat,  // data
  input  wire          cdi_req,  // request
  output reg           cdi_grt,  // grant
  // output port
  input  wire          cdo_clk,  // clock
  input  wire          cdo_rst,  // reset
  input  wire          cdo_clr,  // clear
  output wire [DW-1:0] cdo_dat,  // data
  output reg           cdo_req,  // request
  input  wire          cdo_grt   // grant
);

////////////////////////////////////////////////////////////////////////////////
// gray code related functions
////////////////////////////////////////////////////////////////////////////////

// conversion from integer to gray
function automatic [CW-1:0] int2gry (input [CW-1:0] val);                                                                                                               
  integer i;
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
function automatic [CW-1:0] gry_inc (input [CW-1:0] gry_cnt); 
begin
  gry_inc = int2gry (gry2int (gry_cnt) + 'd1);
end
endfunction

////////////////////////////////////////////////////////////////////////////////
// local signals                                                              //
////////////////////////////////////////////////////////////////////////////////

// input port
wire          cdi_trn;  // transfer
reg  [CW-1:0] cdi_syn;  // synchronization
reg  [CW-1:0] cdi_cnt;  // gray counter
wire [CW-1:0] cdi_inc;  // gray increment

// CDC FIFO memory
reg  [DW-1:0] cdc_mem [0:2**CW-1];

// output port
wire          cdo_trn;  // transfer
reg  [CW-1:0] cdo_syn;  // synchronization
reg  [CW-1:0] cdo_cnt;  // gray counter
wire [CW-1:0] cdo_inc;  // gray increment

////////////////////////////////////////////////////////////////////////////////
// input port                                                                 //
////////////////////////////////////////////////////////////////////////////////

// transfer
assign cdi_trn = cdi_req & cdi_grt;

// counter increment
assign cdi_inc = gry_inc (cdi_cnt);

// synchronization and counter registers
always @ (posedge cdi_clk, posedge cdi_rst)
if (cdi_rst) begin
                     cdi_syn <= {CW{1'b0}};
                     cdi_cnt <= {CW{1'b0}};
                     cdi_grt <=     1'b1  ;
end else begin
                     cdi_syn <= cdo_cnt;
  if      (cdi_clr)  cdi_cnt <= cdi_syn;
  else if (cdi_trn)  cdi_cnt <= cdi_inc;
                     cdi_grt <= cdi_grt & ~cdi_trn | (cdi_syn != cdi_grt ? cdi_inc : cdi_cnt);
end

// data memory
always @ (posedge cdi_clk)
if (cdi_trn) cdc_mem [cdi_cnt] <= cdi_dat;

////////////////////////////////////////////////////////////////////////////////
// output port                                                                //
////////////////////////////////////////////////////////////////////////////////

// transfer
assign cdo_trn = cdo_req & cdo_grt;

// counter increment
assign cdo_inc = gry_inc (cdo_cnt);

// synchronization and counter registers
always @ (posedge cdo_clk, posedge cdo_rst)
if (cdo_rst) begin
                     cdo_syn <= {CW{1'b0}};
                     cdo_cnt <= {CW{1'b0}};
                     cdo_req <=     1'b0  ;
end else begin
                     cdo_syn <= cdi_cnt;
  if      (cdo_clr)  cdo_cnt <= cdo_syn;
  else if (cdo_trn)  cdo_cnt <= cdo_inc;
                     cdo_req <= cdo_req & ~cdo_trn | (cdo_syn != cdo_req ? cdo_inc : cdo_cnt);
end

// asynchronous output data
assign cdo_dat = cdc_mem [cdo_cnt];

endmodule
