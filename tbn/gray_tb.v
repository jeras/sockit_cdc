module gray_tb;

localparam CW = 4;

function automatic [CW-1:0] int2gry (input [CW-1:0] val);
  integer i;
begin
  for (i=0; i<CW-1; i=i+1)  int2gry[i] = val[i+1] ^ val[i];
  int2gry[CW-1] = val[CW-1];
end
endfunction

function automatic [CW-1:0] gry2int (input [CW-1:0] val);
  integer i;
begin
  gry2int[CW-1] = val[CW-1];
  for (i=CW-1; i>0; i=i-1)  gry2int[i-1] = val[i-1] ^ gry2int[i];
end
endfunction

integer cnt;

initial begin
  for (cnt = 0; cnt < 16; cnt = cnt+1) begin
  $display ("%8d, %8b, %8b, %8d", cnt, int2gry(cnt[CW-1:0]), gry2int(int2gry(cnt[CW-1:0])), gry2int(int2gry(cnt[CW-1:0])));
  end
end

endmodule
