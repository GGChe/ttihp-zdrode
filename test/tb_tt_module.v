`timescale 10ns / 10ns
`default_nettype none

module tb_tt_module;

    // ------------------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------------------
    parameter integer NUM_UNITS      = 4;
    parameter integer DATA_WIDTH     = 16;
    parameter integer PROCESS_CYCLES = 2;

    // ------------------------------------------------------------------------
    // Clock / Reset
    // ------------------------------------------------------------------------
    reg clk   = 0;
    reg rst_n = 0;
    reg ena   = 1;
    always #5 clk = ~clk;   // 100 MHz

    // ------------------------------------------------------------------------
    // I/Os to DUT
    // ------------------------------------------------------------------------
    reg  [7:0] ui_in  = 8'h00;
    reg  [7:0] uio_in = 8'h00;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // ------------------------------------------------------------------------
    // DUT instantiation
    // ------------------------------------------------------------------------
    tt_um_example dut (
        .clk   (clk),
        .rst_n (rst_n),
        .ena   (ena),
        .ui_in (ui_in),
        .uio_in(uio_in),
        .uo_out(uo_out),
        .uio_out(uio_out),
        .uio_oe(uio_oe)
    );

    // ------------------------------------------------------------------------
    // Waveform dump
    // ------------------------------------------------------------------------
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_tt_module);
        $dumpvars(1, dut);
    end

    // ------------------------------------------------------------------------
    // Stimulus
    // ------------------------------------------------------------------------
    integer data_file;
    integer code;
    integer sample_count = 0;
    integer max_rows     = 1000000;
    integer i;

    // one 16-bit sample for each channel
    reg [DATA_WIDTH-1:0] sample [0:NUM_UNITS-1];

    initial begin
        // -------- reset --------
        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (5) @(posedge clk);

        // -------- open CSV file --------
        data_file = $fopen("test/input_data_4ch.csv", "r");
        if (data_file == 0) begin
            $display("ERROR: Cannot open test/input_data_4ch.csv");
            $finish;
        end

        // -------- main loop: one pass per CSV row --------
        while (!$feof(data_file) && sample_count < max_rows) begin
            // read four integers separated by commas, terminated by '\n'
            code = $fscanf(data_file, "%d,%d,%d,%d\n",
                           sample[0], sample[1], sample[2], sample[3]);

            if (code == NUM_UNITS) begin
                // ---- push the four samples (CH0..CH3) into the DUT ----
                for (i = 0; i < NUM_UNITS; i = i + 1) begin
                    // MSB
                    @(posedge clk);
                    uio_in = sample[i][15:8];
                    ui_in  = 8'b0000_0100;  // write-strobe
                    @(posedge clk);
                    ui_in  = 8'h00;

                    // LSB
                    @(posedge clk);
                    uio_in = sample[i][7:0];
                    ui_in  = 8'b0000_0100;
                    @(posedge clk);
                    ui_in  = 8'h00;
                end

                // give DUT time to crunch
                repeat (PROCESS_CYCLES) @(posedge clk);

                // ---- read back the four channels ----
                for (i = 0; i < NUM_UNITS; i = i + 1) begin
                    ui_in = {6'b0, i[1:0]};   // zero-extend 2-bit index
                    @(posedge clk);
                    // $display("CH%0d output = %b", i, uo_out);
                end

                sample_count = sample_count + 1;
            end
            else begin
                $display("WARNING: malformed line %0d (got %0d numbers)",
                         sample_count, code);
                @(posedge clk);  // keep clock moving
            end
        end

        $fclose(data_file);
        $display("Simulation complete — %0d CSV rows processed.",
                 sample_count);
        $finish;
    end
endmodule
