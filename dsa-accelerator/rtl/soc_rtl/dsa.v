`include "aquila_config.vh"

`ifdef ENABLE_DSA_FMA
module dsa #(parameter XLEN = 32, AXI_DATA_LEN = 32)
(
    input                  clk_i,
    input                  rst_i,

    (* mark_debug = "true" *)input                  p_strobe_i,
    (* mark_debug = "true" *)input [XLEN - 1 : 0]   p_addr_i,
    (* mark_debug = "true" *)input                  p_rw_i,
    (* mark_debug = "true" *)input [XLEN/8 - 1 : 0] p_byte_enable_i, // Not used
    (* mark_debug = "true" *)input [XLEN - 1 : 0]   p_data_i,
    (* mark_debug = "true" *)output [XLEN - 1 : 0]  p_data_o,
    (* mark_debug = "true" *)output                 p_data_ready_o
);

// Parameter
localparam CHANNEL_A = 2'b00;
localparam CHANNEL_B = 2'b01;
localparam CHANNEL_C = 2'b10;
localparam COMPUTING = 2'b11;

// DSA register
(* mark_debug = "true" *)reg [XLEN - 1 : 0]        p_data_r;
(* mark_debug = "true" *)reg [XLEN - 1 : 0]        A_r;
(* mark_debug = "true" *)reg [XLEN - 1 : 0]        B_r;
(* mark_debug = "true" *)reg [XLEN - 1 : 0]        C_r;
      
(* mark_debug = "true" *)reg [1 : 0]               select_r;

(* mark_debug = "true" *)reg                       p_strobe_r;
(* mark_debug = "true" *)reg                       p_rw_r;
(* mark_debug = "true" *)reg                       A_valid_r;
(* mark_debug = "true" *)reg                       B_valid_r;
(* mark_debug = "true" *)reg                       C_valid_r;
(* mark_debug = "true" *)reg                       write_AB_r;
(* mark_debug = "true" *)reg                       write_C_r;
(* mark_debug = "true" *)reg                       write_computing_r;
(* mark_debug = "true" *)reg                       read_done_r;
(* mark_debug = "true" *)reg                       computing_r;
(* mark_debug = "true" *)reg signed [XLEN - 1 : 0] wait_counter;
(* mark_debug = "true" *)reg                       result_valid_r;

// Profiler
`ifdef ENABLE_DSA_PROFILER
(* mark_debug = "true" *)reg [2 * XLEN - 1 : 0]    computing_cnt;
(* mark_debug = "true" *)reg [2 * XLEN - 1 : 0]    data_feeding_cnt;
`endif

// DSA signal
(* mark_debug = "true" *)wire                      p_strobe;
(* mark_debug = "true" *)wire                      p_rw;
(* mark_debug = "true" *)wire [XLEN - 1 : 0]       p_data;
(* mark_debug = "true" *)wire [1 : 0]              select_i;
(* mark_debug = "true" *)wire [1 : 0]              select;
(* mark_debug = "true" *)wire                      valid;
(* mark_debug = "true" *)wire                      write_done;
(* mark_debug = "true" *)wire                      start_compute;
(* mark_debug = "true" *)wire                      waiting;
(* mark_debug = "true" *)wire                      result2C;

// Signals related to the floating-point fused multiply-add unit
(* mark_debug = "true" *)wire                      A_is_ready;
(* mark_debug = "true" *)wire                      B_is_ready;
(* mark_debug = "true" *)wire                      C_is_ready;
(* mark_debug = "true" *)wire                      result_is_valid;
(* mark_debug = "true" *)wire                      result_valid;
(* mark_debug = "true" *)wire [XLEN - 1 : 0]       result;

// DSA logic
assign p_strobe = p_strobe_i || p_strobe_r;
assign p_rw     = p_rw_i || p_rw_r;
assign p_data   = (p_strobe_i) ? p_data_i : p_data_r;
assign select_i = (p_addr_i[3:0] == 4'h0) ? CHANNEL_A :
                  (p_addr_i[3:0] == 4'h4) ? CHANNEL_B :
                  (p_addr_i[3:0] == 4'h8) ? CHANNEL_C :
                  (p_addr_i[3:0] == 4'hC) ? COMPUTING : 2'b00;
assign select   = (p_strobe_i) ? select_i : select_r;
assign valid    = (select == CHANNEL_A) ? A_valid_r :
                  (select == CHANNEL_B) ? B_valid_r :
                  (select == CHANNEL_C) ? C_valid_r : 1'b0;
                //   (select == COMPUTING) ? 1'b1 : 1'b0;

// Valid logic
always @(posedge clk_i)
begin
    if (rst_i || (A_valid_r && A_is_ready))
        A_valid_r <= 1'b0;
    else if (p_strobe && p_rw && ~A_valid_r && (select == CHANNEL_A))
        A_valid_r <= 1'b1;
    else
        A_valid_r <= A_valid_r;
end

always @(posedge clk_i) // TODO: should be integrated with the above always block
begin
    if (rst_i || (B_valid_r && B_is_ready))
        B_valid_r <= 1'b0;
    else if (p_strobe && p_rw && ~B_valid_r && (select == CHANNEL_B))
        B_valid_r <= 1'b1;
    else
        B_valid_r <= B_valid_r;
end

assign result2C = (~C_valid_r && (wait_counter > $signed(0)) &&
                   ~wait_counter[XLEN - 1] && result_valid);

always @(posedge clk_i)
begin
    if (rst_i || (C_valid_r && C_is_ready))
        C_valid_r <= 1'b0;
    else if ((p_strobe && p_rw && ~C_valid_r && (select == CHANNEL_C)) || result2C)
        C_valid_r <= 1'b1;
    else
        C_valid_r <= C_valid_r;
end

// Input from processor
always @(posedge clk_i)
begin
    if (rst_i || (read_done_r || write_done)) begin
        p_strobe_r <= 1'b0;
        select_r <= 2'b00;
        p_rw_r <= 1'b0;
        p_data_r <= {XLEN{1'b0}};
    end
    else if (p_strobe_i && ((p_rw_i && valid) ||
                            (~p_rw_i && ~result_valid))) begin
        p_strobe_r <= p_strobe_i;
        select_r <= select_i;
        p_rw_r <= p_rw_i;
        p_data_r <= p_data_i;
    end
    else begin
        p_strobe_r <= p_strobe_r;
        select_r <= select_r;
        p_rw_r <= p_rw_r;
        p_data_r <= p_data_r;
    end
end

// Write to DSA register
always @(posedge clk_i)
begin
    if (rst_i) begin
        A_r <= {XLEN{1'b0}};
        B_r <= {XLEN{1'b0}};
        write_AB_r <= 1'b0;
    end
    else if (p_strobe && p_rw && ~valid) begin
        case (select)
            CHANNEL_A: A_r <= p_data;
            CHANNEL_B: B_r <= p_data;
            default: ;
        endcase

        write_AB_r <= 1'b1;
    end
    else begin
        A_r <= A_r;
        B_r <= B_r;
        write_AB_r <= 1'b0;
    end
end

// Channel C and result
always @(posedge clk_i)
begin
    if (rst_i) begin
        C_r <= {XLEN{1'b0}};
        write_C_r <= 1'b0;
    end
    else if (~C_valid_r && result_is_valid) begin
        C_r <= result;
        write_C_r <= write_C_r;
    end
    else if (p_strobe && p_rw && ~C_valid_r && (select == CHANNEL_C)) begin
        C_r <= p_data;
        write_C_r <= 1'b1;
    end
    else begin
        C_r <= C_r;
        write_C_r <= 1'b0;
    end
end

// Computing logic
assign start_compute = (A_is_ready && A_valid_r) || (B_is_ready && B_valid_r) ||
                       (C_is_ready && C_valid_r);

always @(posedge clk_i)
begin
    if (rst_i || (result_is_valid && ~waiting)) begin
        computing_r <= 1'b0;
        write_computing_r <= 1'b0;
    end
    else if (p_strobe && p_rw && (select == COMPUTING)) begin
        computing_r <= p_data;
        write_computing_r <= 1'b1;
    end
    else if (start_compute) begin
        computing_r <= 1'b1;
        write_computing_r <= 1'b0;
    end
    else begin
        computing_r <= computing_r;
        write_computing_r <= 1'b0;
    end
end

always @(posedge clk_i)
begin
    if (rst_i || (~start_compute && ~computing_r)) begin
        wait_counter <= {XLEN{1'b0}};
    end
    else begin
        wait_counter <= wait_counter + (A_is_ready && A_valid_r) +
                        (B_is_ready && B_valid_r) -
                        ((C_is_ready && C_valid_r && 
                          (start_compute || computing_r)) << 1);
    end
end

assign waiting = |wait_counter;

always @(posedge clk_i)
begin
    if (rst_i)
        result_valid_r <= 1'b0;
    else if (p_strobe && p_rw && (select == COMPUTING))
        result_valid_r <= &p_data;
    else if (result2C)
        result_valid_r <= 1'b0;
    else if (result_is_valid)
        result_valid_r <= 1'b1;
    else
        result_valid_r <= result_valid_r;
end

assign result_valid = result_is_valid || result_valid_r;

// DSA ready logic
always @(posedge clk_i)
begin
    if (rst_i)
        read_done_r <= 1'b0;
    else if (p_strobe && ~p_rw && result_valid && ~computing_r)
        read_done_r <= 1'b1;
    else
        read_done_r <= 1'b0;
end

assign write_done = write_AB_r || write_C_r || write_computing_r; 

// Output to processor
assign p_data_o = ((select_i == CHANNEL_C) && read_done_r) ? C_r : {XLEN{1'b0}};
assign p_data_ready_o = read_done_r || write_done;

// DSA profiler
`ifdef ENABLE_DSA_PROFILER
always @(posedge clk_i)
begin
    if (rst_i) begin
        computing_cnt <= {(2 * XLEN){1'b0}};
        data_feeding_cnt <= {(2 * XLEN){1'b0}};
    end
    else begin
        computing_cnt <= computing_cnt + computing_r;
        data_feeding_cnt <= data_feeding_cnt + waiting;
    end
end
`endif

// Floating-point fused multiply-add
floating_point_0 FP_FMA (
    // Top-level signals
    .aclk(clk_i),
    .aresetn(~rst_i),

    // S_AXIS_A
    .s_axis_a_tdata(A_r),
    .s_axis_a_tready(A_is_ready),
    .s_axis_a_tvalid(A_valid_r),

    // S_AXIS_B
    .s_axis_b_tdata(B_r),
    .s_axis_b_tready(B_is_ready),
    .s_axis_b_tvalid(B_valid_r),

    // S_AXIS_C
    .s_axis_c_tdata(C_r),
    .s_axis_c_tready(C_is_ready),
    .s_axis_c_tvalid(C_valid_r),

    // M_AXIS_RESULT
    .m_axis_result_tdata(result),
    .m_axis_result_tready(~C_valid_r),
    .m_axis_result_tvalid(result_is_valid)
);

endmodule
`endif
