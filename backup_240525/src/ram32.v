`default_nettype none

module ram_wide #(
    parameter integer NUM_CHANNELS = 4,
    parameter integer DATA_WIDTH   = 16,
    parameter integer ADDR_WIDTH   = 1,
    parameter DEBUG = 1
)(
    input  wire clk,
    input  wire rst,
    input  wire [(NUM_CHANNELS*DATA_WIDTH)-1:0] wide_data_in,
    input  wire write_en,
    input  wire read_en,
    input  wire [ADDR_WIDTH-1:0] addr,
    output wire ram_full,
    output reg  [(NUM_CHANNELS*DATA_WIDTH)-1:0] data_out
);
    reg [(NUM_CHANNELS*DATA_WIDTH)-1:0] ram_mem [0:(1<<ADDR_WIDTH)-1];
    reg [ADDR_WIDTH-1:0] read_addr;
    assign ram_full = (addr == {ADDR_WIDTH{1'b1}});

    always @(posedge clk) begin
        if (rst) begin
            read_addr <= 0;
            data_out <= 0;
            $display("------------------ read_en %d", read_en);
        end else begin
            if (write_en) begin
                ram_mem[addr] <= wide_data_in;
                    $display("RAM WRITE @ %0t | addr=%0d | data_in = %h",
                            $time, addr, wide_data_in);
            end

            if (read_en) begin
                read_addr <= addr;
            end

            data_out <= ram_mem[read_addr];

            if (DEBUG) begin
                $display("RAM READ @ %0t | addr=%0d | data_out = %h",
                        $time, read_addr, ram_mem[read_addr]);
            end
        end
    end


endmodule
