`timescale 1ns / 1ps

module tb_processing_system;

  // -------------------------------------------------------
  // 1) Test Parameters
  // -------------------------------------------------------
  // You can use the parametric version of processing_system if you like:
  parameter integer NUM_UNITS = 8;

  // Since each unit is 16 bits, total wide word = NUM_UNITS * 16 = 64 bits if NUM_UNITS=4
  // We'll feed data in 8-bit chunks => 8 cycles per full frame.

  // -------------------------------------------------------
  // 2) Testbench Signals
  // -------------------------------------------------------
  reg         clk;
  reg         rst;
  reg  [7:0]  serial_data_in;
  wire [3:0]  spike_detection_array; // For NUM_UNITS=4
  wire [7:0]  event_out_array;       // 2 bits per unit => 8 bits total, if NUM_UNITS=4

  // Example threshold inputs to the processing_system
  reg  [7:0]  class_a_thresh_in;
  reg  [7:0]  class_b_thresh_in;
  reg  [15:0] timeout_period_in;

  // -------------------------------------------------------
  // 3) Instantiate the Processing System Under Test (UUT)
  // -------------------------------------------------------
  processing_system #(
    .NUM_UNITS(NUM_UNITS)
  ) uut (
    .clk                  (clk),
    .rst                  (rst),
    .serial_data_in       (serial_data_in),
    .class_a_thresh_in    (class_a_thresh_in),
    .class_b_thresh_in    (class_b_thresh_in),
    .timeout_period_in    (timeout_period_in),
    .spike_detection_array(spike_detection_array),
    .event_out_array      (event_out_array)
  );

  // -------------------------------------------------------
  // 4) Clock Generation: 10 ns period => 100 MHz
  // -------------------------------------------------------
  initial clk = 0;
  always #5 clk = ~clk;

  // -------------------------------------------------------
  // 5) Test Procedure
  // -------------------------------------------------------
  integer i;
  // We'll store 8 bytes to form one 64-bit frame.
  // Each byte is just an incrementing pattern for demonstration.
  reg [7:0] test_data [0:7];

  initial begin
    // Optional: Dump waveforms for debugging
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_processing_system);

    // 5.1) Initialize test_data
    //      You could choose any pattern you like.
    for (i = 0; i < 8; i = i + 1) begin
      test_data[i] = i * 8'h11; // e.g. 0x00, 0x11, 0x22, ...
    end

    // 5.2) Setup threshold inputs
    class_a_thresh_in  = 8'd20;
    class_b_thresh_in  = 8'd40;
    timeout_period_in  = 16'd100;

    // 5.3) Reset
    rst = 1'b1;
    serial_data_in = 8'b0;

    #20;  // Hold reset for a couple of clock cycles
    rst = 1'b0;

    // 5.4) Feed one 64-bit frame (8 bytes)
    $display("Feeding one 64-bit frame to processing_system:");
    for (i = 0; i < 8; i = i + 1) begin
      @(posedge clk);
      serial_data_in = test_data[i];
      $display("  Sending byte[%0d] = 0x%02h", i, test_data[i]);
    end

    // 5.5) After we've sent 8 bytes, let the system run a bit
    //      so it can write to the RAM and the processing units can do their job.
    @(posedge clk);
    serial_data_in = 8'h00; // not sending more data
    $display("Finished sending 64 bits. Waiting for system to process...");

    // Wait a few more cycles for processing
    repeat (10) @(posedge clk);

    // 5.6) Print out final outputs
    $display("\nFinal Outputs:");
    $display("  spike_detection_array = %b", spike_detection_array);
    $display("  event_out_array       = %b", event_out_array);

    // If you had known expected values from the logic, you could compare:
    // if (spike_detection_array != some_expected_spike_bits) ...
    //   $display("Mismatch detected!");
    // else
    //   $display("Pass!");

    $display("\nSimulation complete.\n");
    $finish;
  end

endmodule
