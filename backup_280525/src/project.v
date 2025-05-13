`default_nettype none
module tt_um_example (
    //----------------------------------------------------------
    // Tiny Tapeout top-level ports
    //----------------------------------------------------------
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    //----------------------------------------------------------
    // Application parameters
    //----------------------------------------------------------
    parameter integer NUM_UNITS  = 4;   // four processing channels
    parameter integer DATA_WIDTH = 16;  // 16-bit samples

    // bytes per sample and index counter width
    localparam integer SAMPLE_BYTES = DATA_WIDTH/8;           // =2
    localparam integer IDX_W        = (SAMPLE_BYTES==1) ? 1   // avoids 0-width
                                        : $clog2(SAMPLE_BYTES);

    // active-low reset from pad
    wire rst = ~rst_n;

    //----------------------------------------------------------
    // ui_in decoding
    // ---------------------------------------------------------
    // ui_in[2] is a 'byte valid' strobe from the host
    // ui_in[1:0] selects which unit’s results appear on uo_out
    //----------------------------------------------------------
    wire       byte_valid     = ui_in[2];
    wire [1:0] selected_unit  = ui_in[1:0];

    // remaining 5 bits unused (address not needed any more)
    wire _unused_ui = &{ ui_in[7:3] };

    //----------------------------------------------------------
    // 8-bit serial  → 16-bit parallel sample buffer
    //----------------------------------------------------------
    reg  [IDX_W-1:0]  idx          = {IDX_W{1'b0}};
    reg  [DATA_WIDTH-1:0] sample_sr = {DATA_WIDTH{1'b0}};
    reg                  sample_wr_en = 1'b0;   // 1-clk pulse

    always @(posedge clk) begin
        sample_wr_en <= 1'b0;                   // default: de-assert

        if (rst) begin
            idx        <= {IDX_W{1'b0}};
            sample_sr  <= {DATA_WIDTH{1'b0}};
        end
        else if (byte_valid) begin
            // shift left 8 bits, append new byte at LSB
            sample_sr <= { sample_sr[DATA_WIDTH-9:0], uio_in };

            // byte counter
            if (idx == SAMPLE_BYTES-1) begin
                sample_wr_en <= 1'b1;           // 16-bit word complete
                idx          <= {IDX_W{1'b0}};
            end else begin
                idx <= idx + 1'b1;
            end
        end
    end

    //----------------------------------------------------------
    // Processing system (4 × RAM16 buffer, 4 processing units)
    //----------------------------------------------------------
    wire [NUM_UNITS-1:0]   spike_array;
    wire [2*NUM_UNITS-1:0] event_array;

    processing_system #(
        .NUM_UNITS (NUM_UNITS ),
        .DATA_WIDTH(DATA_WIDTH),
        .DEBUG     (0)
    ) u_processing (
        .clk                 (clk),
        .rst                 (rst),
        .sample_in           (sample_sr),   // 16-bit word
        .sample_in_valid     (sample_wr_en),
        .spike_detection_array (spike_array),
        .event_out_array       (event_array)
    );

    //----------------------------------------------------------
    // Output multiplexer: show selected unit’s results
    //----------------------------------------------------------
    assign uo_out  = { 5'b0,
                       event_array[ (2*selected_unit) +: 2 ],
                       spike_array[ selected_unit ] };

    // uio_* are unused outputs/tri-state controls
    assign uio_out = 8'h00;
    assign uio_oe  = 8'h00;

    //----------------------------------------------------------
    // tie off unused input (avoid lint warnings)
    //----------------------------------------------------------
    wire _unused_ena = &{ ena };

endmodule
