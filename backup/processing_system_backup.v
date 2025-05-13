`default_nettype none

module processing_system #(
    parameter integer NUM_UNITS = 4
)(
    input  wire                       clk,
    input  wire                       rst,

    // Parallel data input: NUM_UNITS × 16 bits
    input  wire [NUM_UNITS*16-1:0]    data_in_wide,

    // Shared thresholds/timeouts
    input  wire [7:0]                 class_a_thresh_in,
    input  wire [7:0]                 class_b_thresh_in,
    input  wire [15:0]                timeout_period_in,

    // Outputs
    output wire [NUM_UNITS-1:0]       spike_detection_array,
    output wire [2*NUM_UNITS-1:0]     event_out_array
);

    // Internal Wires
    wire [NUM_UNITS-1:0]   spike_detection_internal;
    wire [2*NUM_UNITS-1:0] event_out_internal;

    // Generate NUM_UNITS instances of processing_unit
    genvar j;
    generate
        for (j = 0; j < NUM_UNITS; j = j + 1) begin : processing_units
            wire [15:0] data_in_j;
            assign data_in_j = data_in_wide[16*(j+1)-1 : 16*j];

            processing_unit processing_unit_inst (
                .clk               (clk),
                .rst               (rst),
                .data_in           (data_in_j),
                .threshold_in      (16'd200),
                .class_a_thresh_in (class_a_thresh_in),
                .class_b_thresh_in (class_b_thresh_in),
                .timeout_period_in (timeout_period_in),

                .spike_detection   (spike_detection_internal[j]),
                .event_out         (event_out_internal[2*(j+1)-1 : 2*j])
            );

            // Print both binary and integer representations
            // always @(posedge clk) begin
            //     if (!rst) begin
            //         $display("Unit %0d input data: binary = %016b, integer = %0d", j, data_in_j, data_in_j);
            //     end
            // end
        end
    endgenerate


    // Output assignments
    assign spike_detection_array = spike_detection_internal;
    assign event_out_array       = event_out_internal;

endmodule