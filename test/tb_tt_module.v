`timescale 10ns / 10ns
`default_nettype none

module tb_tt_module;

    parameter integer NUM_UNITS      = 4;
    parameter integer DATA_WIDTH     = 16;
    parameter integer PROCESS_CYCLES = 2;

    // Clock and Reset
    reg clk = 0;
    reg rst_n = 0;
    reg ena   = 1;
    always #5 clk = ~clk;  // 100 MHz

    // I/Os to tt_um_example
    reg  [7:0] ui_in  = 8'h00;
    reg  [7:0] uio_in = 8'h00;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // DUT
    tt_um_example dut (
        .clk(clk),
        .rst_n(rst_n),
        .ena(ena),
        .ui_in(ui_in),
        .uio_in(uio_in),
        .uo_out(uo_out),
        .uio_out(uio_out),
        .uio_oe(uio_oe)
    );

    // Waveform dump
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_tt_module);
        $dumpvars(1, dut);
    end

    // Stimulus
    integer data_file;
    integer code;
    integer int_sample;
    integer sample_count = 0;
    integer max_samples  = 1000000;
    integer i;

    initial begin
        // Reset
        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (5) @(posedge clk);

        // Open input file
        data_file = $fopen("test/input_data.csv", "r");
        if (data_file == 0) begin
            $display("ERROR: Cannot open input_data.txt");
            $finish;
        end

        // Read and send data
        while (!$feof(data_file) && sample_count < max_samples) begin
            code = $fscanf(data_file, "%d\n", int_sample);

            if (code == 1) begin
                // $display("Sending sample %0d = 0x%04x", sample_count, int_sample);

                // Send MSB
                @(posedge clk);
                uio_in = int_sample[15:8];
                ui_in  = 8'b0000_0100;
                @(posedge clk);
                ui_in  = 8'b0000_0000;

                // Send LSB
                @(posedge clk);
                uio_in = int_sample[7:0];
                ui_in  = 8'b0000_0100;
                @(posedge clk);
                ui_in  = 8'b0000_0000;

                // Wait for processing
                repeat (PROCESS_CYCLES) @(posedge clk);

                // Read back outputs
                for (i = 0; i < NUM_UNITS; i = i + 1) begin
                    ui_in = i[1:0];  // Select channel
                    @(posedge clk);
                    // $display("CH%0d output: uo_out = %b", i, uo_out);
                end

                sample_count = sample_count + 1;

            end else begin
                $display("Warning: Skipping malformed line %0d", sample_count);
                @(posedge clk);
            end
        end

        $fclose(data_file);
        $display("Simulation complete — %0d samples processed.", sample_count);
        $finish;
    end

endmodule
