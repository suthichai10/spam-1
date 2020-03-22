`ifndef RAM_V
`define RAM_V

`timescale 1ns/100ps

// verilator lint_off UNOPTFLAT
module ram(_OE, _WE, addr, d);

parameter DWIDTH=8,AWIDTH=16, DEPTH= 1 << AWIDTH;

input _OE, _WE;
input [AWIDTH-1:0] addr;
inout [DWIDTH-1:0] d;
 
reg [DWIDTH-1:0] mem [DEPTH-1:0];
logic [7:0] dout;

assign d = dout;

// always @*
//     $monitor("RAM : _OE=%1b, _WE=%1b, addr=%8b, d=%8b, m0=%8b, m1=%8b, m2=%8b",_OE, _WE, addr, d, mem[0], mem[1], mem[2]);

  always @(_WE or _OE)
   begin
    // NOTE: 6116 and 62256 RAM datasheet says _WE overrides _OE but I want to detect this unexpected situation
     if (!_WE && !_OE) begin
       $display("RAM cannot be _OE and _WE simultaneously");
       $finish;
     end
   end

  always @(_WE or d or addr)
   begin
     if (!_WE) begin
        dout = {DWIDTH{1'bz}};
        mem[addr] = d;
     end
   end

  always @(_OE or addr)
   begin
      if (!_OE && _WE) 
        dout = mem[addr];
   end

  integer i;
  initial begin
    for(i=0;i<DEPTH;i=i+1)
       mem[i]={DWIDTH{1'bx}};
  end

endmodule

`endif