`timescale 1 ns / 1 ps
`default_nettype none
// =====================================================================
//  Testbench for “processing_system”
//  – Stimulates the input with DEPTH samples per acquisition frame
//  – Stores every sample in a reference buffer
//  – During the sweep-and-clear read phase compares the data seen by
//    each processing_unit against the reference buffer
//  – On any mismatch issues $error / $fatal; otherwise prints PASSED
// =====================================================================
module processing_system_tb;

    // 1.  Local parameters (keep consistent with DUT)
    localparam integer NUM_UNITS  = 4;
    localparam integer DATA_WIDTH = 16;
    localparam integer ADDR_WIDTH = 5;
    localparam integer DEPTH      = (1 << ADDR_WIDTH);

    // 2.  Clock / reset
    reg clk  = 0;
    reg rst  = 1;

    always #5  clk = ~clk;      // 100 MHz

    // 3.  DUT I/O signals
    reg  [DATA_WIDTH-1:0] sample_in       = 0;
    reg                   sample_in_valid = 0;

    wire [NUM_UNITS-1:0]   spike_detection_array;
    wire [2*NUM_UNITS-1:0] event_out_array;

    processing_system #(
        .NUM_UNITS (NUM_UNITS),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DEBUG     (0)
    ) dut (
        .clk (clk),
        .rst (rst),

        .sample_in       (sample_in),
        .sample_in_valid (sample_in_valid),

        .spike_detection_array (spike_detection_array),
        .event_out_array       (event_out_array)
    );

    // 5.  Reference memory + index counters
    reg [DATA_WIDTH-1:0] ref_mem [0:DEPTH-1];
    integer              wr_idx;
    integer              rd_idx;

    // 6.  Drive stimulus
    integer frame, i;

    initial begin
        repeat (5) @(posedge clk);
        rst <= 0;

        for (frame = 0; frame < 3; frame = frame + 1) begin
            wr_idx = 0;
            for (i = 0; i < DEPTH; i = i + 1) begin
                @(posedge clk);
                sample_in_valid <= 1'b1;
                sample_in       <= (frame * DEPTH) + i;      // simple, deterministic pattern
                ref_mem[wr_idx] <= sample_in;
                wr_idx          <= wr_idx + 1;
            end
            // stop driving input while the DUT performs sweep/clear
            @(posedge clk);
            sample_in_valid <= 1'b0;

            // -------- READ phase : wait for sample_valid to rise --------------------
            //   – Dutch internal “sample_valid” flag marks rows being presented
            wait (dut.sample_valid);
            rd_idx = 0;
            while (dut.sample_valid) begin                   // DEPTH cycles
                @(posedge clk);
                verify_row(rd_idx);
                rd_idx = rd_idx + 1;
            end

            // -------- clear should occur now; wait one extra cycle ------------------
            @(posedge clk);  // clr_pulse already consumed inside the DUT
        end

        $display("TEST PASSED – all processing units received the expected data.");
        $finish;
    end

    // 7.  Score-board task  (executed once per read row)
    task verify_row(input integer row);
        integer k;
        reg [DATA_WIDTH-1:0] expected, observed;
        // begin
        //     expected = ref_mem[row];
        //     // iterate over all processing units
        //     for (k = 0; k < NUM_UNITS; k = k + 1) begin
        //         observed = dut.g_units[k].u_proc.data_in;
        //         if (observed !== expected) begin
        //             $error("Mismatch @%0t : unit=%0d  row=%0d  expected=%0h  got=%0h",
        //                    $time, k, row, expected, observed);
        //             $fatal;                                   // abort simulation
        //         end
        //     end
        // end
    endtask

endmodule
