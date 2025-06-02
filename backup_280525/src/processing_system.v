`default_nettype none
module processing_system #(
    parameter integer NUM_UNITS  = 4,
    parameter integer DATA_WIDTH = 16,
    parameter integer ADDR_WIDTH = 5,       // 32 words
    parameter integer DEPTH      = (1 << ADDR_WIDTH),
    parameter integer DEBUG      = 1
)(
    input  wire                     clk,
    input  wire                     rst,

    input  wire [15:0]              sample_in,
    input  wire                     sample_in_valid,

    output wire [NUM_UNITS-1:0]     spike_detection_array,
    output wire [2*NUM_UNITS-1:0]   event_out_array

    // 1. ROW WRITE POINTER  (one row per incoming sample)
    reg  [ADDR_WIDTH-1:0] wr_addr = 0;

    always @(posedge clk)
        if (rst)               
            wr_addr <= 0;
        else if (sample_in_valid)
            wr_addr <= buffer_full_pulse ? 0 : wr_addr + 1'b1;

    // ------------------------------------------------------------------
    // 2. Sweep-and-clear FSM  (Verilog-2001 style)
    // ------------------------------------------------------------------
    localparam [1:0] S_IDLE = 2'd0, S_READ = 2'd1, S_CLR = 2'd2;

    reg  [1:0]           state     = S_IDLE;
    reg  [ADDR_WIDTH-1:0] rd_addr  = 0;
    reg                   sample_valid = 0;
    reg                   clr_pulse    = 0;

    always @(posedge clk) begin
        sample_valid <= 1'b0;
        clr_pulse    <= 1'b0;

        if (rst) begin
            state   <= S_IDLE;
            rd_addr <= 0;
        end else begin
            case (state)
                S_IDLE:  if (buffer_full_pulse) begin
                             state   <= S_READ;
                             rd_addr <= 0;
                         end
                S_READ:  begin
                             sample_valid <= 1'b1;
                             rd_addr      <= rd_addr + 1'b1;
                             if (rd_addr == DEPTH-1)
                                 state <= S_CLR;
                         end
                S_CLR:   begin
                             clr_pulse <= 1'b1;   // one-cycle clear
                             state     <= S_IDLE;
                         end
            endcase
        end
    end

    // 3. Four identical RAM16 buffers  (broadcast write)
    wire [DATA_WIDTH-1:0] ram_q [0:NUM_UNITS-1];

    genvar gi;
    generate
        for (gi = 0; gi < NUM_UNITS; gi = gi + 1) begin : g_ram
            wire we_i  = sample_in_valid;               // write all RAMs
            wire en_i  = we_i | (state==S_READ) | clr_pulse;
            wire [ADDR_WIDTH-1:0] addr_i = (state==S_READ) ? rd_addr
                                                           : wr_addr;

            RAM16 #(.ADDR_WIDTH(ADDR_WIDTH)) u_ram16 (
                .CLK  (clk),
                .RST  (rst),
                .EN   (en_i),
                .WE   (we_i),
                .CLR  (clr_pulse),
                .FULL (),              // not used here
                .A    (addr_i),
                .Di   (sample_in),
                .Do   (ram_q[gi])
            );
        end
    endgenerate

    // ------------------------------------------------------------------
    // 4. Processing units
    // ------------------------------------------------------------------
    wire [NUM_UNITS-1:0]   spike_det_int;
    wire [2*NUM_UNITS-1:0] event_out_int;

    generate
        for (gi = 0; gi < NUM_UNITS; gi = gi + 1) begin : g_units
            processing_unit u_proc (
                .clk (clk),
                .rst (rst),
                .data_in (ram_q[gi]),
                .threshold_in      (16'd200),
                .class_a_thresh_in (8'd10),
                .class_b_thresh_in (8'd5),
                .timeout_period_in (16'd1000),
                .spike_detection   (spike_det_int[gi]),
                .event_out         (event_out_int[2*gi +: 2])
            );

            if (DEBUG) begin : dbg
                always @(posedge clk)
                    if (sample_valid)
                        $display("T=%0t  unit=%0d  row=%0d  sample=%0d (0x%h)",
                                 $time, gi, rd_addr, ram_q[gi], ram_q[gi]);
            end
        end
    endgenerate

    assign spike_detection_array = spike_det_int;
    assign event_out_array       = event_out_int;
endmodule
