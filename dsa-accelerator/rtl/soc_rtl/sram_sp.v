`timescale 1ns / 1ps
`include "aquila_config.vh"

`ifdef ENABLE_CNN_TCM
module sram_sp
#(parameter DATA_WIDTH = 32, N_ENTRIES = 128)
(
    input                           clk_i,
    input                           en_i,
    input                           we_i,
    input  [DATA_WIDTH/8 - 1 : 0]   be_i,
    input  [$clog2(N_ENTRIES)-1: 0] addr_i,
    input  [DATA_WIDTH-1: 0]        data_i,
    output reg [DATA_WIDTH-1: 0]    data_o,
    output reg                      ready_o
);

reg [DATA_WIDTH-1 : 0] RAM [N_ENTRIES-1: 0];

integer idx;

initial
begin
    for (idx = 0; idx < N_ENTRIES; idx = idx + 1)
        RAM[idx] = 0;
end

always @(posedge clk_i)
begin
    if (en_i)
    begin
        if (we_i)
        begin
            for (idx = 0; idx < DATA_WIDTH/8; idx = idx + 1)
                if (be_i[idx]) RAM[addr_i][(idx<<3) +: 8] <= data_i[(idx<<3) +: 8];
            data_o <= data_i;
        end
        else
            data_o <= RAM[addr_i];
        
        ready_o <= 1'b1;
    end
    else
        ready_o <= 1'b0;
end
endmodule
`endif
