`default_nettype none
module tt_um_example (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    parameter integer NUM_UNITS  = 4;
    parameter integer DATA_WIDTH = 16;

    // Active-low reset from external pin
    wire rst = ~rst_n;

    // Channel select input from ui_in[1:0]
    wire [1:0] selected_unit = ui_in[1:0];
    wire _unused_ui = &{ ui_in[7:2] };

    // 2-byte sample assembler (MSB first)
    reg [DATA_WIDTH-1:0] sample_sr = 0;
    reg byte_idx = 0;  // toggles 0 → 1 → 0
    reg sample_wr_en = 0;
    wire byte_valid = ui_in[2];

    always @(posedge clk) begin
        if (rst) begin
            byte_idx     <= 0;
            sample_sr    <= 0;
            sample_wr_en <= 0;
        end else begin
            sample_wr_en <= 0;

            if (byte_valid) begin
                if (byte_idx == 0) begin
                    // First byte → MSB
                    sample_sr[15:8] <= uio_in;
                    byte_idx <= 1;
                end else begin
                    // Second byte → LSB
                    sample_sr[7:0] <= uio_in;
                    byte_idx <= 0;
                    sample_wr_en <= 1'b1;  // complete 16-bit sample
                end
            end
        end
    end


    // Processing system instantiation
    wire [NUM_UNITS-1:0]   spike_array;
    wire [2*NUM_UNITS-1:0] event_array;

    processing_system #(
        .NUM_UNITS(NUM_UNITS),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_processing (
        .clk                   (clk),
        .rst                   (rst),
        .sample_in             (sample_sr),
        .write_sample_in       (sample_wr_en),
        .spike_detection_array (spike_array),
        .event_out_array       (event_array),
        .sample_valid_debug    ()
    );

    // Output mux: select event/spike data from selected unit
    assign uo_out = {
        5'b00000,
        event_array[(2 * selected_unit) +: 2],
        spike_array[selected_unit]
    };

    // Unused
    assign uio_out = 8'h00;
    assign uio_oe  = 8'h00;
    wire _unused_ena = &{ ena };

endmodule
