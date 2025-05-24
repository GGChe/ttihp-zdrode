`timescale 1ns/1ns
`default_nettype none

module tb_processing_system_file;

    // ---------------------------------------------------------
    // Parameters
    // ---------------------------------------------------------
    localparam NUM_UNITS  = 4;
    localparam DATA_WIDTH = 16;

    localparam CLK_PERIOD = 10;   // 100 MHz

    // ---------------------------------------------------------
    // Clock / reset
    // ---------------------------------------------------------
    reg clk = 0;
    reg rst = 1;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ---------------------------------------------------------
    // DUT I/O
    // ---------------------------------------------------------
    reg  [DATA_WIDTH-1:0] sample_in      = 0;
    reg                   sample_in_valid= 0;

    wire [NUM_UNITS-1:0]      spike_detection_array;
    wire [2*NUM_UNITS-1:0]    event_out_array;

    processing_system #(
        .NUM_UNITS (NUM_UNITS),
        .DATA_WIDTH(DATA_WIDTH),
        .DEBUG     (0)
    ) dut (
        .clk (clk),
        .rst (rst),
        .sample_in(sample_in),
        .sample_in_valid(sample_in_valid),
        .spike_detection_array(spike_detection_array),
        .event_out_array(event_out_array)
    );

    // ---------------------------------------------------------
    // File I/O
    // ---------------------------------------------------------
    integer data_file;
    integer ev_file;
    integer code;
    integer int_in;
    integer sample_count = 0;
    integer max_samples  = 250000;
    integer k;

    // Open files and handle errors once
    initial begin
        data_file = $fopen("test/20170420/20170420_slice01_01_CTRL1_0006_43_unsigned.txt","r");
        if (data_file==0) begin
            $display("ERROR: cannot open data file."); $finish;
        end
        ev_file = $fopen("output/event_out_log.txt","w");
        if (ev_file==0) begin
            $display("ERROR: cannot open event log."); $finish;
        end
    end

    // ---------------------------------------------------------
    // Stimulus / scoreboard
    // ---------------------------------------------------------
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_processing_system_file);

        #100;
        rst = 0;
        $display("*** Feeding samples ***");

        while ((!$feof(data_file)) && (sample_count < max_samples)) begin
            @(posedge clk);
            // one-cycle strobe
            sample_in_valid <= 1'b1;
            if ($feof(data_file)==0) begin
                code = $fscanf(data_file,"%d\n",int_in);
                if (code>0) sample_in <= int_in[15:0];
            end
            @(posedge clk);
            sample_in_valid <= 1'b0;  // de-assert for at least 1 clk
            sample_count = sample_count + 1;
        end

        $display("*** Finished after %0d samples ***", sample_count);
        #500;
        $fclose(data_file);
        $fclose(ev_file);
        $finish;
    end

    // ---------------------------------------------------------
    // Event logging (every clk)
    // ---------------------------------------------------------
    always @(posedge clk)
        $fwrite(ev_file,"%t,%0h\n",$time,event_out_array);

endmodule
