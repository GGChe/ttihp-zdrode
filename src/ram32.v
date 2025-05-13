`default_nettype none

module RAM64 (
`ifdef USE_POWER_PINS
    input VPWR,
    input VGND,
`endif
    input CLK,
    input [7:0] WE0,           // 8-bit write enable for 8 bytes
    input EN0,
    input [4:0] A0,            // 32-depth (same as original)
    input [63:0] Di0,          // 64-bit data input
    output reg [63:0] Do0      // 64-bit data output
);

  reg [63:0] RAM[31:0];        // 32-word deep RAM with 64-bit words

  always @(posedge CLK)
    if (EN0) begin
      Do0 <= RAM[A0];
      if (WE0[0]) RAM[A0][7:0]    <= Di0[7:0];
      if (WE0[1]) RAM[A0][15:8]   <= Di0[15:8];
      if (WE0[2]) RAM[A0][23:16]  <= Di0[23:16];
      if (WE0[3]) RAM[A0][31:24]  <= Di0[31:24];
      if (WE0[4]) RAM[A0][39:32]  <= Di0[39:32];
      if (WE0[5]) RAM[A0][47:40]  <= Di0[47:40];
      if (WE0[6]) RAM[A0][55:48]  <= Di0[55:48];
      if (WE0[7]) RAM[A0][63:56]  <= Di0[63:56];
    end else begin
      Do0 <= 64'b0;
    end

endmodule
