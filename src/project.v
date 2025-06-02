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

    localparam integer SAMPLE_BYTES = DATA_WIDTH/8;
    localparam integer IDX_W = (SAMPLE_BYTES == 1) ? 1 : $clog2(SAMPLE_BYTES);

    wire rst = ~rst_n;

    wire       byte_valid     = ui_in[2];
    wire [1:0] selected_unit  = ui_in[1:0];
    wire _unused_ui = &{ ui_in[7:3] };

    reg [IDX_W-1:0] idx = 0;
    reg [DATA_WIDTH-1:0] sample_sr = 0;
    reg sample_wr_en = 0;

    always @(posedge clk) begin
        sample_wr_en <= 1'b0;
        if (rst) begin
            idx       <= 0;
            sample_sr <= 0;
        end else if (byte_valid) begin
            // shift in MSB first (big endian)
            sample_sr <= { sample_sr[DATA_WIDTH-9:0], uio_in };
            if (idx == SAMPLE_BYTES - 1) begin
                sample_wr_en <= 1'b1;
                idx <= 0;
            end else begin
                idx <= idx + 1;
            end
        end
    end

    wire [NUM_UNITS-1:0]   spike_array;
    wire [2*NUM_UNITS-1:0] event_array;

    processing_system #(
        .NUM_UNITS (NUM_UNITS),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_processing (
        .clk                 (clk),
        .rst                 (rst),
        .sample_in           (sample_sr),
        .write_sample_in     (sample_wr_en),
        .spike_detection_array(spike_array),
        .event_out_array     (event_array),
        .sample_valid_debug  ()
    );

    assign uo_out = {
        5'b00000,
        event_array[(2*selected_unit) +: 2],
        spike_array[selected_unit]
    };

    assign uio_out = 8'h00;
    assign uio_oe  = 8'h00;

    wire _unused_ena = &{ ena };

endmodule
