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
    localparam integer TOTAL_W   = NUM_UNITS*DATA_WIDTH;
    localparam integer TOTAL_B   = TOTAL_W/8;
    localparam integer IDX_W     = $clog2(TOTAL_B);

    wire rst = ~rst_n;

    //------------------------------------------------------------
    // ui_in decoding
    //------------------------------------------------------------
    wire [4:0] ram_addr      = ui_in[7:3];   // 5‑bit address 0‑31
    wire       write_en_raw  = ui_in[2];      // shift byte
    wire [1:0] selected_unit = ui_in[1:0];

    //------------------------------------------------------------
    // 8‑bit serial → 64‑bit parallel
    //------------------------------------------------------------
    reg [IDX_W-1:0]  idx   = 0;
    reg [63:0]       shreg = 0;
    reg              sample_wr_en = 0;        // one‑cycle strobe

    always @(posedge clk) begin
        sample_wr_en <= 0;

        if (rst) begin
            idx   <= 0;
            shreg <= 0;
        end else if (write_en_raw) begin
            shreg <= {shreg[55:0], uio_in};
            idx   <= idx + 1'b1;
            if (idx == TOTAL_B-1) begin
                sample_wr_en <= 1;
                idx          <= 0;
            end
        end
    end

    //------------------------------------------------------------
    // Processing system with internal RAM64
    //------------------------------------------------------------
    wire [NUM_UNITS-1:0]   spike_array;
    wire [2*NUM_UNITS-1:0] event_array;

    processing_system #(
        .NUM_UNITS  (NUM_UNITS ),
        .DATA_WIDTH (DATA_WIDTH),
        .DEBUG      (0)
    ) u_processing (
        .clk            (clk),
        .rst            (rst),
        .ram_addr       (ram_addr),
        .ram_write_data (shreg),
        .ram_write_en   (sample_wr_en),
        .spike_detection_array (spike_array),
        .event_out_array       (event_array)
    );

    //------------------------------------------------------------
    // Output MUX
    //------------------------------------------------------------
    assign uo_out  = {5'b0,
                      event_array[(2*selected_unit)+:2],
                      spike_array[selected_unit]};
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;
    wire _unused = &{ena};
endmodule
