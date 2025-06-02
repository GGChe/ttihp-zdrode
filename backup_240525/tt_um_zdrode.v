`default_nettype none

module tt_um_processing_system (
    // Dedicated 8-bit inputs
    input  wire [7:0] ui_in,
    // Dedicated 8-bit outputs
    output wire [7:0] uo_out,
    // 8 bidirectional pins (not used in this example)
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    // TinyTapeout-provided signals
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ena
);

    //------------------------------------------------
    // 1) Convert rst_n (active-low) to an active-high reset
    //------------------------------------------------
    wire rst = ~rst_n;

    //------------------------------------------------
    // 2) Simple logic to load 64 bits (data_in) from ui_in
    //    one byte at a time, over 8 clock cycles.
    //------------------------------------------------
    //    This is just one possible example approach:
    //    - If ui_in[0] == 1, we start shifting data
    //    - We accumulate 8 consecutive 8-bit values into a 64-bit register
    //    - Then we feed that into processing_system for as long as desired
    //------------------------------------------------

    reg [63:0] data_in_reg;
    reg [2:0]  load_count;
    reg        loading;

    // A small state machine in one always block
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            data_in_reg <= 64'd0;
            load_count  <= 3'd0;
            loading     <= 1'b0;
        end else begin
            // If ui_in[0] is a "start" signal, begin loading
            if (ui_in[0] && !loading) begin
                loading    <= 1'b1;
                load_count <= 3'd0;
            end

            // If loading is active, gather 8 bits each cycle
            if (loading) begin
                // Insert the incoming ui_in[7:0] into data_in_reg
                // in 8-bit chunks. For instance:
                data_in_reg[load_count*8 +: 8] <= ui_in;

                load_count <= load_count + 1'b1;
                // Once we've collected 8 chunks = 64 bits, stop
                if (load_count == 3'd7) begin
                    loading <= 1'b0;
                end
            end
        end
    end

    //------------------------------------------------
    // 3) Hardcode or partially hardcode thresholds
    //------------------------------------------------
    // For demonstration, we set a constant threshold array = 4×16 bits = 64 bits.
    // Each 16-bit threshold is 200 (decimal) = 0x00C8.
    // You can similarly create a small state machine to load these from ui_in
    // or from uio_in if you want dynamic thresholds.
    //------------------------------------------------
    localparam [63:0] THRESHOLD_ARRAY = 64'h00C8_00C8_00C8_00C8; // 4 × 0x00C8
    localparam [7:0]  CLASS_A_THRESH  = 8'd20;
    localparam [7:0]  CLASS_B_THRESH  = 8'd40;
    localparam [15:0] TIMEOUT_PERIOD  = 16'd100;

    //------------------------------------------------
    // 4) Instantiate the processing_system
    //------------------------------------------------
    wire [3:0] spike_detection_array;  // 4 bits total
    wire [7:0] event_out_array;        // 2 bits per channel × 4 channels = 8 bits

    processing_system #(
        .NUM_UNITS(4)
    ) ps_i (
        .clk                  (clk),
        .rst                  (rst),

        // 64-bit data = 4 channels × 16 bits
        .data_in             (data_in_reg),

        // 64-bit threshold array
        .threshold_in_array  (THRESHOLD_ARRAY),

        // 8/8/16 threshold parameters
        .class_a_thresh_in   (CLASS_A_THRESH),
        .class_b_thresh_in   (CLASS_B_THRESH),
        .timeout_period_in   (TIMEOUT_PERIOD),

        // outputs
        .spike_detection_array(spike_detection_array),
        .event_out_array      (event_out_array)
    );

    //------------------------------------------------
    // 5) Drive the dedicated 8-bit output
    //------------------------------------------------
    // Example: Lower 4 bits = spike_detection_array,
    //          Upper 4 bits = lower nibble of event_out_array
    // Customize as desired.
    //------------------------------------------------
    assign uo_out[3:0] = spike_detection_array;
    assign uo_out[7:4] = event_out_array[3:0];

    //------------------------------------------------
    // 6) Tie off or ignore the bidirectional pins
    //------------------------------------------------
    // For now, we do not use the bidirectional IO in this example.
    // We'll drive them low and disable output (uio_oe=0).
    //------------------------------------------------
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;
    wire   _unused = &{uio_in, ena};

endmodule
