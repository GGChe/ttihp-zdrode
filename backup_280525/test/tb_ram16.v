`timescale 1ns/1ns
`default_nettype none

module tb_RAM16;

    //------------------------------------------------------------------
    // Configuration  :  depth = 4 words (ADDR_WIDTH = 2)
    //------------------------------------------------------------------
    localparam ADDR_WIDTH = 2;
    localparam DEPTH      = (1 << ADDR_WIDTH);

    //------------------------------------------------------------------
    // Testbench signals
    //------------------------------------------------------------------
    reg  clk, rst, en, we, clr;
    reg  [ADDR_WIDTH-1:0] addr;
    reg  [15:0] din;
    wire [15:0] dout;
    wire full;

    //------------------------------------------------------------------
    // DUT
    //------------------------------------------------------------------
    RAM16 #(.ADDR_WIDTH(ADDR_WIDTH)) dut (
        .CLK (clk),
        .RST (rst),
        .EN  (en),
        .WE  (we),
        .CLR (clr),
        .FULL(full),
        .A   (addr),
        .Di  (din),
        .Do  (dout)
    );

    //------------------------------------------------------------------
    // Clock: 100 MHz
    //------------------------------------------------------------------
    initial clk = 0;
    always  #5 clk = ~clk;

    //------------------------------------------------------------------
    // Dump helper
    //------------------------------------------------------------------
    task dump_ram;
        integer k;
        begin
            $display("── RAM dump ──");
            for (k = 0; k < DEPTH; k = k + 1)
                $display("  [%0d] = %h", k, dut.RAM[k]);
            $display("────────────────");
        end
    endtask

    //------------------------------------------------------------------
    // Test sequence
    //------------------------------------------------------------------
    integer i; reg [15:0] exp;

    initial begin
        $dumpfile("tb_RAM16.vcd");
        $dumpvars(0, tb_RAM16);

        // ---------- Power-on reset ---------------------------------------
        rst = 1; en = 0; we = 0; clr = 0; addr = 0; din = 0;
        #20;                     // two clocks
        rst = 0;

        // ---------- Write more than one depth to trigger full/clear ------
        for (i = 0; i < 12; i = i + 1) begin
            //--------------------------------------------------------------
            // Write
            //--------------------------------------------------------------
            addr = i[ADDR_WIDTH-1:0];   // wraps 0-3
            din  = i + 1;
            en = 1; we = 1; #10;        // one clock
            we = 0;

            dump_ram();                 // show before clear

            //--------------------------------------------------------------
            // Read back
            //--------------------------------------------------------------
            exp = i + 1;
            #10;
            $display("ADDR=%0d EXP=%h GOT=%h", addr, exp, dout);

            //--------------------------------------------------------------
            // React to FULL
            //--------------------------------------------------------------
            if (full) begin
                $display("⚠ FULL at %0t – clearing RAM", $time);
                clr = 1; #10; clr = 0;          // one-clock pulse
                #10; dump_ram();                // verify cleared
            end

            en = 0; #10;                        // idle gap
        end

        $display("Test complete.");
        #20; $finish;
    end
endmodule
