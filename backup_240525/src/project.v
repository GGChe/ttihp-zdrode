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

    // Parameters
    parameter integer NUM_UNITS   = 4;
    parameter integer DATA_WIDTH  = 16;
    parameter integer ADDR_WIDTH  = 4;
    localparam integer TOTAL_WIDTH = NUM_UNITS * DATA_WIDTH;

    // Internal signals
    wire rst = ~rst_n;

    // RAM control signals from ui_in
    wire [ADDR_WIDTH-1:0] ram_addr       = ui_in[7:4];
    wire                  write_en_raw   = ui_in[3];
    wire                  read_en_raw    = ui_in[2];
    wire [1:0]            selected_unit  = ui_in[1:0];

    // Buffered write control
    reg [2:0] write_idx = 0;
    reg [TOTAL_WIDTH-1:0] ram_data_in_buffer = 0;
    reg write_pending = 0;
    reg delayed_write_en = 0;

    // Read buffer delay for RAM output
    reg [TOTAL_WIDTH-1:0] ram_data_out_reg;

    wire [TOTAL_WIDTH-1:0] ram_data_out;
    wire ram_full;

    // Input shift buffer logic (write across 8 uio_in bytes)
    always @(posedge clk) begin
        if (rst) begin
            ram_data_in_buffer <= 0;
            write_idx <= 0;
            write_pending <= 0;
            delayed_write_en <= 0;
            read_en = 0;

        end else begin
            delayed_write_en <= 0;

            if (write_en_raw) begin
                ram_data_in_buffer <= {ram_data_in_buffer[TOTAL_WIDTH-9:0], uio_in};
                write_idx <= write_idx + 1;

                // After the last byte (index 7), trigger write in next cycle
                if (write_idx == 3'd7) begin
                    write_pending <= 1;
                end
            end else begin
                write_idx <= 0;
                write_pending <= 0;
            end

            // Trigger write enable one cycle after collecting all bytes
            if (write_pending && !write_en_raw) begin
                delayed_write_en <= 1;
                write_pending <= 0;
            end
        end
    end

    // RAM instance
    ram_wide #(
        .NUM_CHANNELS(NUM_UNITS),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DEBUG(0)  // Set to 1 for internal RAM logs
    ) u_ram (
        .clk(clk),
        .rst(rst),
        .wide_data_in(ram_data_in_buffer),
        .write_en(delayed_write_en),
        .read_en(read_en_raw),
        .addr(ram_addr),
        .ram_full(ram_full),
        .data_out(ram_data_out)
    );

    // Register RAM output to align with processing
    always @(posedge clk) begin
        if (rst)
            ram_data_out_reg <= 0;
        else if (read_en_raw)
            ram_data_out_reg <= ram_data_out;
    end

    // Processing system (4 channels)
    wire [NUM_UNITS-1:0] spike_array;
    wire [2*NUM_UNITS-1:0] event_array;

    processing_system #(
        .NUM_UNITS(NUM_UNITS)
    ) u_processing (
        .clk(clk),
        .rst(rst),
        .data_in_wide(ram_data_out_reg),
        .class_a_thresh_in(8'd10),
        .class_b_thresh_in(8'd5),
        .timeout_period_in(16'd1000),
        .spike_detection_array(spike_array),
        .event_out_array(event_array)
    );

    // Select outputs based on selected_unit
    wire       spike;
    wire [1:0] event_out;

    assign spike =      spike_array[selected_unit];
    assign event_out =  event_array[(2*selected_unit)+:2];

    assign uo_out  = {5'b00000, event_out, spike};
    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000;

    wire _unused = &{ena};

endmodule
