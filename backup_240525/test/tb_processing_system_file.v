`timescale 10ns/10ns

module tb_processing_system_file;

  parameter integer NUM_UNITS      = 4;
  parameter integer DATA_WIDTH     = 16;

  parameter SAMPLE_PERIOD   = 200;
  parameter PROCESS_PERIOD  = 50;
  parameter PROCESS_CYCLES  = 2;

  reg  clk = 0;
  reg  rst = 1;

  reg  [DATA_WIDTH-1:0] data_in_array [0:NUM_UNITS-1];
  wire [NUM_UNITS*DATA_WIDTH-1:0] data_in_wide;

  reg  [7:0]  class_a_thresh_in = 8'h05;
  reg  [7:0]  class_b_thresh_in = 8'h01;
  reg  [15:0] timeout_period_in = 16'h2710;

  wire [NUM_UNITS-1:0]   spike_detection_array;
  wire [2*NUM_UNITS-1:0] event_out_array;

  reg simulation_active = 1'b1;

  // Flatten the array into a wide bus
  genvar i;
  generate
    for (i = 0; i < NUM_UNITS; i = i + 1) begin : flatten_inputs
      assign data_in_wide[16*(i+1)-1 : 16*i] = data_in_array[i];
    end
  endgenerate

  // DUT
  processing_system #(
    .NUM_UNITS(NUM_UNITS)
  ) dut (
    .clk(clk),
    .rst(rst),
    .data_in_wide(data_in_wide),
    .class_a_thresh_in(class_a_thresh_in),
    .class_b_thresh_in(class_b_thresh_in),
    .timeout_period_in(timeout_period_in),
    .spike_detection_array(spike_detection_array),
    .event_out_array(event_out_array)
  );

  // Clock Generation
  always #(PROCESS_PERIOD/2) clk = ~clk;

  // File IO
  integer data_file;
  integer code;
  integer int_in;
  integer k;
  integer event_log_file;
  integer sample_count;
  integer max_samples;

  initial begin
    sample_count = 0;
    max_samples = 250000;

    $dumpfile("wave.vcd");
    $dumpvars(1, tb_processing_system_file);

    #100;
    rst = 0;

    for (k = 0; k < NUM_UNITS; k = k + 1)
      data_in_array[k] = 16'h0190;

    data_file = $fopen("/home/gonsos/ttihp-zdrode/test/20170420/20170420_slice01_01_CTRL1_0006_43_unsigned.txt", "r");
    if (data_file == 0) begin
      $display("ERROR: Could not open data input file.");
      $finish;
    end

    event_log_file = $fopen("output/event_out_log.txt", "w");
    if (event_log_file == 0) begin
      $display("ERROR: Could not open event output log file.");
      $finish;
    end

    $display("*** Starting data feed at time=%t ***", $time);

    while ((!$feof(data_file)) && (sample_count < max_samples)) begin
      @(posedge clk);
      if (!$feof(data_file)) begin
        code = $fscanf(data_file, "%d\n", int_in);
        if (code > 0) begin
          for (k = 0; k < NUM_UNITS; k = k + 1)
            data_in_array[k] = int_in[15:0];
        end
      end

      repeat (PROCESS_CYCLES) @(posedge clk);

      sample_count = sample_count + 1;
    end

    $fclose(data_file);
    $display("*** Finished simulation at time=%t after %0d samples ***", $time, sample_count);
    #500;
    simulation_active = 0;
    #10;
    $fclose(event_log_file);
    $finish;
  end

  // Output monitoring
  integer idx;
  reg [1:0] event_out_values [0:NUM_UNITS-1];
  always @(posedge clk) begin
    if (simulation_active) begin
      for (idx = 0; idx < NUM_UNITS; idx = idx + 1) begin
        event_out_values[idx] = event_out_array[2*idx +: 2];
        $fwrite(event_log_file, "%t, %0d, %0d\n", $time, idx, event_out_values[idx]);
      end
    end
  end

endmodule
