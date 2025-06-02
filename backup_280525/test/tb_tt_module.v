`timescale 10ns/10ns
`default_nettype none

module tb_tt_module;

    //  Parameters
    parameter integer NUM_CHANNELS = 4;
    parameter integer DATA_WIDTH   = 16;
    parameter integer PROCESS_CYCLES = 2;
    localparam DEBUG = 1;

    //  Clock reset
    reg clk = 0;
    reg rst_n = 0;
    reg ena   = 1;

    always #25 clk = ~clk;     // 20 MHz (period = 50 ns)

    reg  [7:0] ui_in  = 8'h00;
    reg  [7:0] uio_in = 8'h00;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    tt_um_example dut (
        .clk    (clk   ),
        .rst_n  (rst_n ),
        .ena    (ena   ),
        .ui_in  (ui_in ),
        .uio_in (uio_in),
        .uo_out (uo_out),
        .uio_out(uio_out),
        .uio_oe (uio_oe)
    );

    //  Waveform dump
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_tt_module);
        $dumpvars(1, dut);                        // top level
        $dumpvars(2, dut.u_processing);           // processing_system
        $dumpvars(4, dut.u_processing.g_units[0].u_proc);
        $dumpvars(4, dut.u_processing.g_units[1].u_proc);
        $dumpvars(4, dut.u_processing.g_units[2].u_proc);
        $dumpvars(4, dut.u_processing.g_units[3].u_proc);
    end

    //  Stimulus: read CSV and push 4×16‑bit samples
    integer data_file;
    integer code;
    reg [255:0] line;
    reg [15:0] ch0, ch1, ch2, ch3;
    reg [63:0] packed_data;
    integer byte_index;
    integer sample_count = 0;
    integer max_samples  = 10000;
    integer i = 0;

    initial begin
        // Reset
        rst_n = 0;
        repeat (10) @(posedge clk);
        rst_n = 1;

        // Open CSV
        // data_file = $fopen("/home/gonsos/ttihp-zdrode/test/test_file.csv", "r");
        data_file = $fopen("/home/gonsos/ttihp-zdrode/test/input_data_4ch.csv", "r");
        if (data_file == 0) begin
            $display("ERROR: Could not open input_data_4ch.csv");
            $finish;
        end

        // Main loop
        while (!$feof(data_file) && sample_count < max_samples) begin
            // 1.  Read one line & pack into 64 bits  {ch3,ch2,ch1,ch0}
            line = "";
            code = $fgets(line, data_file);

            ch0 = 0; ch1 = 0; ch2 = 0; ch3 = 0;
            if (NUM_CHANNELS == 1)
                code = $sscanf(line, "%d", ch0);
            else if (NUM_CHANNELS == 2)
                code = $sscanf(line, "%d,%d", ch0, ch1);
            else if (NUM_CHANNELS == 3)
                code = $sscanf(line, "%d,%d,%d", ch0, ch1, ch2);
            else
                code = $sscanf(line, "%d,%d,%d,%d", ch0, ch1, ch2, ch3);

            packed_data = {ch3, ch2, ch1, ch0};

            // $display("Sample %0d: packed_data = 0x%016h", sample_count, packed_data);

            // 2. Serial write: 8 bytes MSB-first
            for (byte_index = 7; byte_index >= 0; byte_index = byte_index - 1) begin
                @(posedge clk);
                uio_in = packed_data[byte_index*8 +: 8];
                ui_in  = 8'b0000_1000;     // write_en_raw = 1
                @(posedge clk);
                ui_in  = 8'b0000_0000;
            end

            // 3. Wait for RAM full and processing (latency cycles)
            repeat (PROCESS_CYCLES) @(posedge clk);

            // 4. Poll each channel’s event bits
            for (i = 0; i < NUM_CHANNELS; i = i + 1) begin
                ui_in = i[1:0];    // Select channel i on uo_out
                @(posedge clk);

                // if (uo_out[7]) begin
                //     $display("  OUT: sample %0d  ch%0d  input=%0d  EVENT  (uo_out=%b)",
                //              sample_count, i, (i==0?ch0:i==1?ch1:i==2?ch2:ch3), uo_out);
                // end else if (DEBUG) begin
                //     $display("  OUT: sample %0d  ch%0d  input=%0d  no event",
                //              sample_count, i, (i==0?ch0:i==1?ch1:i==2?ch2:ch3));
                // end
            end

            sample_count = sample_count + 1;
        end

        $fclose(data_file);
        $display("Simulation complete – %0d samples processed.", sample_count);
        repeat (10) @(posedge clk);
        $finish;
    end
endmodule