`timescale 10ns/10ns

module tb_tt_module;

  parameter integer NUM_CHANNELS    = 4;
  parameter integer DATA_WIDTH      = 16;
  parameter integer PROCESS_CYCLES  = 2;
  localparam DEBUG = 1;  // Set to 0 to disable debug output

  reg clk = 0;
  reg rst_n = 0;
  reg ena = 1;

  reg  [7:0] ui_in;
  reg  [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

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

  // Clock generation
  always #25 clk = ~clk;

  // File and data
  integer data_file;
  integer code;
  reg [255:0] line;
  reg [15:0] ch0, ch1, ch2, ch3;
  reg [63:0] packed_data;
  reg [15:0] this_val;
  integer i;
  integer byte_index;
  integer sample_count = 0;
  integer max_samples = 1000000;

  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_tt_module);
    $dumpvars(1, dut);
    $dumpvars(1, dut.u_ram);

    rst_n = 0;
    #100;
    rst_n = 1;

    data_file = $fopen("/home/gonsos/ttihp-zdrode/test/test_file.csv", "r");
    if (data_file == 0) begin
      $display("ERROR: Could not open input_data.csv");
      $finish;
    end

    while (!$feof(data_file) && sample_count < max_samples) begin
      ch0 = 16'd0;
      ch1 = 16'd0;
      ch2 = 16'd0;
      ch3 = 16'd0;

      line = "";
      code = $fgets(line, data_file);

      if (NUM_CHANNELS == 1)
        code = $sscanf(line, "%d", ch0);
      else if (NUM_CHANNELS == 2)
        code = $sscanf(line, "%d,%d", ch0, ch1);
      else if (NUM_CHANNELS == 3)
        code = $sscanf(line, "%d,%d,%d", ch0, ch1, ch2);
      else
        code = $sscanf(line, "%d,%d,%d,%d", ch0, ch1, ch2, ch3);

      packed_data = {ch3, ch2, ch1, ch0};

      if (DEBUG) $display("Sample %0d: Packed data = %h", sample_count, packed_data);

      for (byte_index = 7; byte_index >= 0; byte_index = byte_index - 1) begin
        @(posedge clk);
        uio_in = packed_data[byte_index*8 +: 8];
        ui_in  = 8'b00001000;
        if (DEBUG) $display("Writing byte[%0d] = %02h", byte_index, uio_in);
        @(posedge clk);
        ui_in = 8'b00000000;
      end

      @(posedge clk);
      ui_in = 8'b00000100;
      if (DEBUG) $display("Triggering RAM read at sample %0d", sample_count);
      @(posedge clk);
      ui_in = 8'b00000000;

      repeat (PROCESS_CYCLES) @(posedge clk);

      for (i = 0; i < NUM_CHANNELS; i = i + 1) begin
        ui_in = i[1:0];
        @(posedge clk);

        this_val = (i == 0) ? ch0 :
                   (i == 1) ? ch1 :
                   (i == 2) ? ch2 : ch3;

        if (uo_out[7]) begin
          $display("Sample %0d, ch%0d: input = %0d → EVENT DETECTED (uo_out = %b)",
                   sample_count, i, this_val, uo_out);
        end else if (DEBUG) begin
          $display("Sample %0d, ch%0d: input = %0d → no event (uo_out = %b)",
                   sample_count, i, this_val, uo_out);
        end
      end

      sample_count = sample_count + 1;
    end

    $fclose(data_file);
    $display("Simulation complete. %0d samples processed.", sample_count);
    #100;
    $finish;
  end

endmodule
