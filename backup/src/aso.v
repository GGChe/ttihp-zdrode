module aso (
    input wire clk,
    input wire rst,
    input wire [15:0] data_in,
    input wire [15:0] threshold_in,
    output reg spike_detected
);

// State encoding
localparam TRAINING  = 1'b0;
localparam OPERATION = 1'b1;

reg state;

// Internal signals
reg signed [15:0] x1, x2, x3, x4;
reg signed [15:0] aso;
reg signed [15:0] threshold;

// Absolute value function
function signed [15:0] abs_val;
    input signed [15:0] val;
    begin
        abs_val = (val < 0) ? -val : val;
    end
endfunction

always @(posedge clk or posedge rst) begin
    if (rst) begin
        x1 <= 16'sd0;
        x2 <= 16'sd0;
        x3 <= 16'sd0;
        x4 <= 16'sd0;
        aso <= 16'sd0;
        threshold <= 16'sd500;  // Default threshold
        state <= TRAINING;
        spike_detected <= 1'b0;
    end else begin
        // Shift samples
        x1 <= x2;
        x2 <= x3;
        x3 <= x4;
        x4 <= $signed(data_in);

        case (state)
            TRAINING: begin
                threshold <= 16'sd500;
                state <= OPERATION;
            end

            OPERATION: begin
                threshold <= $signed(threshold_in);
                aso <= abs_val(x4 - x1);
                spike_detected <= (aso > threshold) ? 1'b1 : 1'b0;
            end
        endcase
    end
end

endmodule
