`default_nettype none
// ============================================================
//  Processing system with internal 64‑bit × 32‑word RAM64
//  ▸ Host writes 8 bytes serially → one write‑strobe
//  ▸ When address = 31 the RAM is "full"; block auto‑reads the
//    whole buffer and broadcasts one 16‑bit slice per unit
// ============================================================
module processing_system #(
    parameter integer NUM_UNITS   = 4,  // parallel channels
    parameter integer DATA_WIDTH  = 16, // 16‑bit samples
    parameter integer DEBUG       = 1
)(
    //----------------------------------------------------------
    input  wire                       clk,
    input  wire                       rst,

    // host write port
    input  wire [4:0]                 ram_addr,       // 0‑31
    input  wire [63:0]                ram_write_data,
    input  wire                       ram_write_en,   // one cycle

    //----------------------------------------------------------
    output wire [NUM_UNITS-1:0]       spike_detection_array,
    output wire [2*NUM_UNITS-1:0]     event_out_array
);

    //----------------------------------------------------------
    // Internal parameters
    //----------------------------------------------------------
    localparam integer DEPTH    = 32;
    localparam integer ADDR_MAX = 31;

    //----------------------------------------------------------
    // 1.  RAM64 instance
    //----------------------------------------------------------
    wire [63:0] ram_q;
    RAM64 u_ram (
`ifdef USE_POWER_PINS
        .VPWR (1'b1),
        .VGND (1'b0),
`endif
        .CLK  (clk),
        .EN0  (ram_write_en | read_phase),
        .WE0  ({8{ram_write_en}}),      // write whole word
        .A0   (ram_write_en ? ram_addr : rd_ptr),
        .Di0  (ram_write_data),
        .Do0  (ram_q)
    );

    //----------------------------------------------------------
    // 2.  "full" flag and read‑sweep FSM
    //----------------------------------------------------------
    wire ram_full = (ram_addr == ADDR_MAX) && ram_write_en;

    reg             read_phase = 0;
    reg  [4:0]      rd_ptr     = 0;

    reg             sample_valid = 0;
    reg  [63:0]     sample_word  = 0;
    reg  [63:0]     ram_q_d      = 0;   // one‑cycle delay

    always @(posedge clk) begin
        if (rst) begin
            read_phase    <= 0;
            rd_ptr        <= 0;
            sample_valid  <= 0;
            sample_word   <= 0;
            ram_q_d       <= 0;
        end else begin
            // delay line for RAM output (read‑first)
            ram_q_d <= ram_q;
            sample_valid <= 0;

            //--------------------------------------------------
            // launch sweep when buffer becomes full
            //--------------------------------------------------
            if (ram_full && !read_phase) begin
                read_phase <= 1;
                rd_ptr     <= 0;
            end

            //--------------------------------------------------
            // sweeping: one word per clock
            //--------------------------------------------------
            if (read_phase) begin
                sample_word  <= ram_q_d;
                sample_valid <= 1;

                if (rd_ptr == ADDR_MAX) begin
                    read_phase <= 0;
                    rd_ptr     <= 0;
                end else
                    rd_ptr <= rd_ptr + 1;
            end
        end
    end

    //----------------------------------------------------------
    // 3.  Fan‑out to NUM_UNITS processing_unit blocks
    //----------------------------------------------------------
    wire [NUM_UNITS-1:0]   spike_detection_internal;
    wire [2*NUM_UNITS-1:0] event_out_internal;

    genvar j;
    generate
        for (j = 0; j < NUM_UNITS; j = j + 1) begin : g_units
            // little‑endian slice: channel 0 = bits [15:0]
            wire [15:0] data_in_j = sample_word[16*j +: 16];
            always @(posedge clk) begin
                $strobe("T=%0t  unit=%0d  data_in_j=%0d (%b)", $time, j, data_in_j, data_in_j);
            end
            processing_unit u_proc (
                .clk               (clk),
                .rst               (rst),
                .data_in           (data_in_j),
                .threshold_in      (16'd200),
                .class_a_thresh_in (8'd10),
                .class_b_thresh_in (8'd5),
                .timeout_period_in (16'd1000),
                .spike_detection   (spike_detection_internal[j]),
                .event_out         (event_out_internal[2*j +: 2])
            );

            if (DEBUG) begin : dbg
                always @(posedge clk)
                    if (sample_valid)
                        $display("T=%0t  unit=%0d  sample=%0d (0x%h)",
                                 $time, j, data_in_j, data_in_j);
            end
        end
    endgenerate

    //----------------------------------------------------------
    assign spike_detection_array = spike_detection_internal;
    assign event_out_array       = event_out_internal;

endmodule
