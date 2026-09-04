`timescale 1ns / 1ps
// TODO: Modify discription and date
// =============================================================================
//  Program : analyzer.v
//  Author  : Wei Cheng
//  Date    : Oct/12/2024
// -----------------------------------------------------------------------------
//  Description:
//
//  This is the data cache profiler of the Aquila core.
//
// -----------------------------------------------------------------------------
//  License information:
//
//  This software is released under the BSD-3-Clause Licence,
//  see https://opensource.org/licenses/BSD-3-Clause for details.
//  In the following license statements, "software" refers to the
//  "source code" of the complete hardware/software system.
//
//  Copyright 2024,
//                    Wei Cheng
//
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  1. Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//
//  2. Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//
//  3. Neither the name of the copyright holder nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
// =============================================================================
`include "aquila_config.vh"
`ifdef ENABLE_DCACHE_PROFILER

// TODO: Wire the signal to external module and test the implemntation
module dcache_profiler #(
    parameter integer HART_ID = 0,
    parameter integer XLEN = 32
)
(
    // Top-level system signals
    input clk_i,
    input rst_i,

    // Processor signals
    input [XLEN - 1 : 0] exe_pc_i,
    (* mark_debug = "true" *) input [XLEN - 1 : 0] p_d_addr_i,
    input                p_d_strobe_i,
    input                p_d_rw_i,

    // Data cache signals
    input                d_p_ready_i,
    input                cache_hit_i,
    input [3 : 0]        S_i

);

// Parameters
localparam PI_BEGIN = 32'h80001600;
localparam PI_END   = 32'h800017E0;
localparam Analysis = 2;
localparam PRQ      = 11;

// Status signals
(* mark_debug = "true" *) reg program_pi;
(* mark_debug = "true" *) reg p_d_req;
(* mark_debug = "true" *) reg rw;
(* mark_debug = "true" *) reg cache_hit;

(* mark_debug = "true" *) wire read = ~rw;
(* mark_debug = "true" *) wire read_hit = cache_hit & ~rw;
(* mark_debug = "true" *) wire write = rw;
(* mark_debug = "true" *) wire write_hit = cache_hit & rw;

// Counters
(* mark_debug = "true" *) reg [XLEN - 1 : 0] latency;
(* mark_debug = "true" *) reg [XLEN - 1 : 0] read_cnt;
(* mark_debug = "true" *) reg [XLEN - 1 : 0] read_hit_cnt;
(* mark_debug = "true" *) reg [XLEN - 1 : 0] read_latency;
(* mark_debug = "true" *) reg [XLEN - 1 : 0] read_hit_latency;

(* mark_debug = "true" *) reg [XLEN - 1 : 0] write_cnt;
(* mark_debug = "true" *) reg [XLEN - 1 : 0] write_hit_cnt;
(* mark_debug = "true" *) reg [XLEN - 1 : 0] write_latency;
(* mark_debug = "true" *) reg [XLEN - 1 : 0] write_hit_latency;

// Profile only when the processor is in the pi.c region
always @(posedge clk_i)
begin
    if (rst_i)
        program_pi <= 0;
    else begin
        case (exe_pc_i)
            32'h80001600: program_pi <= 1;
            32'h800017E0: program_pi <= 0;
            default: program_pi <= program_pi;
        endcase
    end
end

// Strobe delay
always @(posedge clk_i)
begin
    if (rst_i)
        p_d_req <= 0;
    else if (p_d_strobe_i)
        p_d_req <= 1'b1;
    else if (d_p_ready_i)
        p_d_req <= 1'b0;
    else
        p_d_req <= p_d_req;
end

// Latency computations
always @(posedge clk_i)
begin
    if (rst_i)
        latency <= {XLEN{1'b0}};
    else if (p_d_req)
        latency <= latency + 1;
    else 
        latency <= {XLEN{1'b0}};
end

// Status read/write signal
initial
begin
    rw <= 1'b0;
    cache_hit <= 1'b0;
end

always @(*)
begin
    if ((S_i == Analysis) || (S_i == PRQ)) begin
        rw <= p_d_rw_i;
        cache_hit <= cache_hit_i;
    end
end

// Counters
always @(posedge clk_i)
begin
    if (rst_i) begin
        read_cnt <= {XLEN{1'b0}};
        read_hit_cnt <= {XLEN{1'b0}};
        write_cnt <= {XLEN{1'b0}};
        write_hit_cnt <= {XLEN{1'b0}};
    end
    else if (program_pi && d_p_ready_i) begin
        read_cnt <= read_cnt + read;
        read_hit_cnt <= read_hit_cnt + read_hit;
        write_cnt <= write_cnt + write;
        write_hit_cnt <= write_hit_cnt + write_hit;
    end
    else begin
        read_cnt <= read_cnt;
        read_hit_cnt <= read_hit_cnt;
        write_cnt <= write_cnt;
        write_hit_cnt <= write_hit_cnt;
    end
end

// Latency counters
always @(posedge clk_i)
begin
    if (rst_i) begin
        read_latency <= {XLEN{1'b0}};
        read_hit_latency <= {XLEN{1'b0}};
        write_latency <= {XLEN{1'b0}};
        write_hit_latency <= {XLEN{1'b0}};
    end
    else if (program_pi && d_p_ready_i) begin
        read_latency <= read ? read_latency + latency : read_latency;
        read_hit_latency <= read_hit ? read_hit_latency + latency : read_hit_latency;
        write_latency <= write ? write_latency + latency : write_latency;
        write_hit_latency <= write_hit ? write_hit_latency + latency : write_hit_latency;
    end
    else begin
        read_latency <= read_latency;
        read_hit_latency <= read_hit_latency;
        write_latency <= write_latency;
        write_hit_latency <= write_hit_latency;
    end
end

endmodule
`endif
