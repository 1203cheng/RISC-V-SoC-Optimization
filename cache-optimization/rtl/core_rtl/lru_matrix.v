`timescale 1ns / 1ps
// TODO: Update info
// =============================================================================
//  Program : lru_matrix.v
//  Author  : Wei Cheng
//  Date    : 
// -----------------------------------------------------------------------------
//  Description:
// -----------------------------------------------------------------------------
//  Revision information:
//
//  None.
// -----------------------------------------------------------------------------
//  License information:
//
//  This software is released under the BSD-3-Clause Licence,
//  see https://opensource.org/licenses/BSD-3-Clause for details.
//  In the following license statements, "software" refers to the
//  "source code" of the complete hardware/software system.
//
//  Copyright 2019,
//                    Embedded Intelligent Systems Lab (EISL)
//                    Deparment of Computer Science
//                    National Chiao Tung Uniersity
//                    Hsinchu, Taiwan.
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

`ifdef LRU_REPLACEMENT
module lru_matrix
#(parameter WAY_NUM = 4,
  parameter WAY_BITS = $clog2(WAY_NUM))
(
    input                       clk_i,
    input                       rst_i,
    input                       cache_hit_i,
    input      [WAY_BITS-1 : 0] hit_way_i,
    output reg [WAY_BITS-1 : 0] lru_o
);

reg [WAY_NUM-1 : 0] LRU_matrix[WAY_NUM-1 : 0];
integer i, j;

// TODO: Reset
always @(posedge clk_i)
begin
    if (rst_i) begin
        for (i = 0; i < WAY_NUM; i = i + 1)
            LRU_matrix[i] <= 0;
    end
    else if (cache_hit_i)
    begin
        for (i = 0; i < WAY_NUM; i = i + 1) begin
            if (i != hit_way_i) begin
                LRU_matrix[hit_way_i][i] <= 1'b1;

                for (j = 0; j < WAY_NUM; j = j + 1) begin
                    if (j != hit_way_i)
                        LRU_matrix[i][j] <= LRU_matrix[i][j];
                end
            end

            LRU_matrix[i][hit_way_i] <= 1'b0;

            // if (i != hit_way_i) begin
            //     LRU_matrix[hit_way_i][i] <= 1'b1;
            //     LRU_matrix[i][hit_way_i] <= 1'b0;
            // end

            // LRU_matrix[i][hit_way_i] <= 1'b0;
        end
    end
    else
        for (i = 0; i < WAY_NUM; i = i + 1)
            LRU_matrix[i] <= LRU_matrix[i];          
end

// FIXME: for loop?
always @(*)
begin
    for (i = 0; i < WAY_NUM; i = i + 1) begin
        if (LRU_matrix[i] == 0)
            lru_o = i;
    end
end

endmodule
`endif
