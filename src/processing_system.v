`default_nettype none
`default_nettype none
module processing_system #(
        parameter integer NUM_UNITS  = 4,
        parameter integer DATA_WIDTH = 16
    )(
        input  wire                     clk,
        input  wire                     rst,

        input  wire [DATA_WIDTH-1:0]    sample_in,        // 16-bit word
        input  wire                     write_sample_in,  // strobe

        output wire [NUM_UNITS-1:0]     spike_detection_array,
        output wire [2*NUM_UNITS-1:0]   event_out_array,
        output wire                     sample_valid_debug
    );

    localparam integer RAM_ADDR_W = $clog2(NUM_UNITS);

    // ------------------------------------------------------------
    // 1.  RAM write side
    // ------------------------------------------------------------
    wire ram_full_pulse;                 // 1-cy pulse at wrap
    wire [DATA_WIDTH-1:0] ram_dout;

    RAM16 #(.ADDR_WIDTH(RAM_ADDR_W)) u_ram16 (
        .CLK  (clk),
        .RST  (rst),
        .READ (read_en),
        .WRITE(write_sample_in),
        .FULL (ram_full_pulse),
        .A    (rd_addr),
        .Di   (sample_in),
        .Do   (ram_dout)
    );

    // ------------------------------------------------------------
    // 2. Read-out FSM
    // ------------------------------------------------------------
    reg                       read_en = 1'b0;
    reg [RAM_ADDR_W-1:0]      rd_addr = 0;
    reg                       sample_valid = 1'b0;
    reg [DATA_WIDTH-1:0]      proc_word_buf [0:NUM_UNITS-1];
    // Add this line near your existing `reg` declarations
    reg [DATA_WIDTH-1:0] ram_dout_reg;
    reg [RAM_ADDR_W:0] read_count;

    always @(posedge clk) begin
        if (rst) begin
            read_en        <= 0;
            rd_addr        <= 0;
            read_count     <= 0;
            sample_valid   <= 0;
            ram_dout_reg   <= 0;
        end else begin
            sample_valid <= 0;

            if (ram_full_pulse && !read_en) begin
                read_en        <= 1;
                rd_addr        <= 0;
                read_count     <= 0;
                ram_dout_reg   <= 0;
                // $display("[PROCESSING UNIT] RAM full pulse detected, starting read phase", $time);
            end else if (read_en) begin
                ram_dout_reg <= ram_dout;

               if (read_count <= NUM_UNITS) begin
                    proc_word_buf[read_count - 1] <= ram_dout;
                    // $display("[PROCESSING UNIT] Reading RAM: rd_addr=%0d, stored 0x%0h into proc_word_buf[%0d]",
                    //         rd_addr, ram_dout_reg, read_count - 1);
                end


                rd_addr    <= rd_addr + 1;
                read_count <= read_count + 1;

                // Stop after capturing final value
                if (read_count == NUM_UNITS) begin
                    read_en <= 0;
                    sample_valid <= 1;
                    // $display("[PROCESSING UNIT] Finished reading RAM, sample_valid asserted", $time);
                end
            end
        end
    end


    assign sample_valid_debug = sample_valid;

    // 3. Processing-unit array
    wire [NUM_UNITS-1:0]   spike_det_int;
    wire [2*NUM_UNITS-1:0] event_out_int;

    genvar gi;
    for (gi = 0; gi < NUM_UNITS; gi = gi + 1) begin : G_PU
        localparam integer GIDX = gi;

        processing_unit u_proc (
            .clk                (clk),
            .rst                (rst),
            .data_in            (proc_word_buf[gi]),
            .threshold_in       (16'd200),
            .class_a_thresh_in  (8'd10),
            .class_b_thresh_in  (8'd3),
            .timeout_period_in  (16'd1000),
            .spike_detection    (spike_det_int[gi]),
            .event_out          (event_out_int[2*gi +: 2])
        );

        // Display input data for debug
        // always @(posedge clk) begin
        //     if (sample_valid) begin
        //         $display("[PROCESSING_SYSTEM] processing_unit[%0d] proc_word_buf[%0d] = 0x%0h", gi, gi, proc_word_buf[gi]);
        //     end
        // end
    end

    assign spike_detection_array = spike_det_int;
    assign event_out_array       = event_out_int;
endmodule
