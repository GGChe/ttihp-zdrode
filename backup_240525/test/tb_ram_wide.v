`timescale 1ns/1ns
`default_nettype none

module tb_ram_wide;

    // Parameters
    localparam NUM_CHANNELS = 4;
    localparam DATA_WIDTH   = 16;
    localparam ADDR_WIDTH   = 4;
    localparam TOTAL_WIDTH  = NUM_CHANNELS * DATA_WIDTH;
    localparam MAX_SAMPLES  = 9;

    // Signals
    reg clk;
    reg rst;
    reg write_en;
    reg read_en;
    reg [ADDR_WIDTH-1:0] addr;
    reg [TOTAL_WIDTH-1:0] wide_data_in;
    wire [TOTAL_WIDTH-1:0] data_out;
    wire ram_full;

    // Instantiate the DUT
    ram_wide #(
        .NUM_CHANNELS(NUM_CHANNELS),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DEBUG(1)
    ) dut (
        .clk(clk),
        .rst(rst),
        .wide_data_in(wide_data_in),
        .write_en(write_en),
        .read_en(read_en),
        .addr(addr),
        .ram_full(ram_full),
        .data_out(data_out)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Initialize clock
    initial clk = 0;

    integer i;
    reg [DATA_WIDTH-1:0] val;
    reg [TOTAL_WIDTH-1:0] expected_data;

    initial begin
        $dumpfile("tb_ram_wide.vcd");
        $dumpvars(0, tb_ram_wide);

        // Reset logic
        rst = 1;
        write_en = 0;
        read_en = 0;
        addr = 0;
        wide_data_in = 0;

        #20;
        rst = 0;
        #10;

        // Write test values
        for (i = 0; i < MAX_SAMPLES; i = i + 1) begin
            val = i + 1;
            expected_data = {val, val, val, val};

            // Write
            addr = i[ADDR_WIDTH-1:0];
            wide_data_in = expected_data;
            write_en = 1;
            #10;
            write_en = 0;

            $display("WRITE: addr=%0d, data=%h", addr, expected_data);

            // Wait before read
            #10;

            // Read
            read_en = 1;
            #10;
            read_en = 0;

            #10; // Wait for synchronous read

            $display("READ:  addr=%0d, data=%h", addr, data_out);

            if (data_out === expected_data)
                $display("✅ Match for value %0d", val);
            else
                $display("❌ Mismatch for value %0d: expected %h, got %h", val, expected_data, data_out);

            #10;
        end

        $display("Test complete.");
        #20;
        $finish;
    end

endmodule
