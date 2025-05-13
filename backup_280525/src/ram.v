`default_nettype none
// ---------------------------------------------------------------------------
// 16-bit × 2^ADDR_WIDTH single-port RAM
//  • FULL rises after DEPTH writes
//  • CLR clears all locations and FULL
//  • RST (new) clears everything on power-up / global reset
// ---------------------------------------------------------------------------
module RAM16 #(
    parameter ADDR_WIDTH = 5,
    parameter DEPTH      = (1 << ADDR_WIDTH)
)(
    input                   CLK,
    input                   RST, 
    input                   EN,
    input                   WE,
    input                   CLR, 
    output reg              FULL, 
    input  [ADDR_WIDTH-1:0] A, 
    input  [15:0]           Di,  
    output reg [15:0]       Do  
);

    // -----------------------------------------------------------------------
    // Storage array
    // -----------------------------------------------------------------------
    reg [15:0] RAM [0:DEPTH-1];

    // loop index for clears
    integer j;

    // write counter
    reg [ADDR_WIDTH:0] wr_cnt;          // one bit wider than address

    // -----------------------------------------------------------------------
    // Sequential behaviour
    // -----------------------------------------------------------------------
    always @(posedge CLK) begin
        // ---------- global reset -------------------------------------------
        if (RST) begin
            for (j = 0; j < DEPTH; j = j + 1)
                RAM[j] <= 16'h0000;
            Do     <= 16'h0000;
            wr_cnt <= 0;
            FULL   <= 1'b0;
        end
        // ---------- CLR request --------------------------------------------
        else if (CLR) begin
            for (j = 0; j < DEPTH; j = j + 1)
                RAM[j] <= 16'h0000;
            Do     <= 16'h0000;
            wr_cnt <= 0;
            FULL   <= 1'b0;
        end
        // ---------- normal read / write ------------------------------------
        else begin
            if (EN) begin
                Do <= RAM[A];          // read-first
                if (WE)
                    RAM[A] <= Di;      // then write (if asserted)
            end
            else
                Do <= 16'h0000;

            // FULL flag generation
            if (EN && WE && !FULL) begin
                if (wr_cnt == DEPTH-1)
                    FULL <= 1'b1;
                wr_cnt <= wr_cnt + 1'b1;
            end
        end
    end
endmodule
