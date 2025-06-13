module processing_unit (
    input  wire        clk,
    input  wire        rst,
    input  wire [15:0] data_in,
    input  wire [15:0] threshold_in,
    input  wire [7:0]  class_a_thresh_in,
    input  wire [7:0]  class_b_thresh_in,
    input  wire [15:0] timeout_period_in,
    output wire        spike_detection,
    output wire [1:0]  event_out
);
    reg [15:0] last_data_in;
    reg [15:0] last_threshold_in;
    // Internal signal
    wire spike_detected_internal;

    // Instantiate spike detector (ADO)
    aso spike_detector_instance (
        .clk(clk),
        .rst(rst),
        .data_in(data_in),
        .threshold_in(threshold_in),
        .spike_detected(spike_detected_internal)
    );

    // Instantiate event classifier
    classifier classifier_instance (
        .clk(clk),
        .reset(rst),
        .current_detection(spike_detected_internal),
        .event_out(event_out),
        .class_a_thresh_in(class_a_thresh_in),
        .class_b_thresh_in(class_b_thresh_in),
        .timeout_period_in(timeout_period_in)
    );

    // Output spike detection signal
    assign spike_detection = spike_detected_internal;

    // Debug print for threshold_in
    always @(posedge clk) begin
        if (!rst) begin
            if (threshold_in !== last_threshold_in) begin
                $display("DEBUG: threshold_in = %h at time %t", threshold_in, $time);
                last_threshold_in <= threshold_in;
            end
        end else begin
            last_threshold_in <= 16'hxxxx;
        end
    end

    // Uncomment if you want data_in debug as well
    // always @(posedge clk) begin
    //     if (!rst) begin
    //         if (data_in !== last_data_in) begin
    //             $display("DEBUG: data_in = %h at time %t", data_in, $time);
    //             last_data_in <= data_in;
    //         end
    //     end else begin
    //         last_data_in <= 16'hxxxx;
    //     end
    // end

endmodule
