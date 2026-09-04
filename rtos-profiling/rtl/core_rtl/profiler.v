`timescale 1ns / 1ps
`include "aquila_config.vh"
`define ENABLE_MUTEX_PROFILER

`ifdef ENABLE_PROFILER
module profiler #(
    parameter integer HART_ID = 0,
    parameter integer XLEN = 32
)
(
    // Top-level system signals
    input clk_i,
    input rst_i,

    // Signals from processor
    (* mark_debug = "true" *) input [XLEN - 1 : 0] pc_i,
    (* mark_debug = "true" *) input [XLEN - 1 : 0] code_i,
    (* mark_debug = "true" *) input [XLEN - 1 : 0] wbk_pc_i,
    (* mark_debug = "true" *) input                tmr_irq_i
);

// Instructions
localparam MRET = 32'h30200073;

// Program counters (should be modified according to different .elf files)
localparam MAIN_BEGIN = 32'h80001448;
localparam MAIN_END = 32'h80001314; // Use entering <vTaskDelete> in Task 1 as the end point

`ifdef ENABLE_MUTEX_PROFILER
localparam MUTEX_TAKE_BEGIN_1   = 32'h80001168;
localparam MUTEX_GIVE_BEGIN_1_1 = 32'h80001190;
localparam MUTEX_GIVE_BEGIN_1_2 = 32'h800011B0;

localparam MUTEX_TAKE_BEGIN_2   = 32'h80001068;
localparam MUTEX_GIVE_BEGIN_2   = 32'h80001090;

localparam MUTEX_TAKE_RET   = 32'h80003460;
localparam MUTEX_GIVE_RET   = 32'h80002E44;
`endif

// Main function signals
(* mark_debug = "true" *) reg                main;
(* mark_debug = "true" *) reg [2 * XLEN - 1 : 0] main_counter;

// Context-switching signals
(* mark_debug = "true" *) reg                tmr_irq_r;
(* mark_debug = "true" *) reg                ctxsw;
(* mark_debug = "true" *) reg [XLEN - 1 : 0] ctxsw_counter;
(* mark_debug = "true" *) reg [XLEN - 1 : 0] ctxsw_overhead;

`ifdef ENABLE_MUTEX_PROFILER
// Synchronization signals
(* mark_debug = "true" *) wire               mutex_take_begin;
(* mark_debug = "true" *) wire               mutex_take_end;
(* mark_debug = "true" *) wire               mutex_give_begin;
(* mark_debug = "true" *) wire               mutex_give_end;
(* mark_debug = "true" *) reg                mutex_take;
(* mark_debug = "true" *) reg                mutex_give;
(* mark_debug = "true" *) reg [XLEN - 1 : 0] mutex_take_counter;
(* mark_debug = "true" *) reg [XLEN - 1 : 0] mutex_give_counter;

assign mutex_take_begin = (wbk_pc_i == MUTEX_TAKE_BEGIN_1) || (wbk_pc_i == MUTEX_TAKE_BEGIN_2);
assign mutex_give_begin = (wbk_pc_i == MUTEX_GIVE_BEGIN_1_1) || (wbk_pc_i == MUTEX_GIVE_BEGIN_1_2) ||
                          (wbk_pc_i == MUTEX_GIVE_BEGIN_2);
assign mutex_take_end   = wbk_pc_i == MUTEX_TAKE_RET;
assign mutex_give_end   = wbk_pc_i == MUTEX_GIVE_RET;
`endif

// Main function logic
always @(posedge clk_i)
begin
    if (rst_i)
        main <= 1'b0;
    else if (pc_i == MAIN_BEGIN)
        main <= 1'b1;
    else if (pc_i == MAIN_END)
        main <= 1'b0;
    else
        main <= main;
end

always @(posedge clk_i)
begin
    if (rst_i)
        main_counter <= {(2 * XLEN){1'b0}};
    else if (main)
        main_counter <= main_counter + 1;
    else
        main_counter <= main_counter;
end

// Context-switching logic
always @(posedge clk_i)
begin
    if (rst_i)
        tmr_irq_r <= 1'b0;
    else
        tmr_irq_r <= tmr_irq_i;
end

always @(posedge clk_i)
begin
    if (rst_i) begin
        ctxsw <= 1'b0;
        ctxsw_counter <= {XLEN{1'b0}};
    end
    else if (tmr_irq_i && ~tmr_irq_r) begin
        ctxsw <= 1'b1;
        ctxsw_counter <= ctxsw_counter + 1;
    end
    else if (code_i == MRET) begin
        ctxsw <= 1'b0;
        ctxsw_counter <= ctxsw_counter;
    end
    else begin
        ctxsw <= ctxsw;
        ctxsw_counter <= ctxsw_counter;
    end
end

always @(posedge clk_i)
begin
    if (rst_i)
        ctxsw_overhead <= {XLEN{1'b0}};
    else if (ctxsw)
        ctxsw_overhead <= ctxsw_overhead + 1;
    else
        ctxsw_overhead <= ctxsw_overhead;
end

`ifdef ENABLE_MUTEX_PROFILER
// Synchronization logic
always @(posedge clk_i)
begin
    if (rst_i)
        mutex_take <= 1'b0;
    else if (mutex_take_begin)
        mutex_take <= 1'b1;
    else if (mutex_take_end)
        mutex_take <= 1'b0;
    else
        mutex_take <= mutex_take;
end

always @(posedge clk_i)
begin
    if (rst_i)
        mutex_give <= 1'b0;
    else if (mutex_give_begin)
        mutex_give <= 1'b1;
    else if (mutex_give_end)
        mutex_give <= 1'b0;
    else
        mutex_give <= mutex_give;        
end

always @(posedge clk_i)
begin
    if (rst_i)
        mutex_take_counter <= {XLEN{1'b0}};
    else if (mutex_take)
        mutex_take_counter <= mutex_take_counter + 1;
    else
        mutex_take_counter <= mutex_take_counter;
end

always @(posedge clk_i)
begin
    if (rst_i)
        mutex_give_counter <= {XLEN{1'b0}};
    else if (mutex_give)
        mutex_give_counter <= mutex_give_counter + 1;
    else
        mutex_give_counter <= mutex_give_counter;
end
`endif

endmodule
`endif
