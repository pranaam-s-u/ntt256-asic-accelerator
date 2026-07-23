// Verilog-2001 synthesizable ModRed (two-segment, DATA_SIZE_ARB = 18)
`timescale 1ns/1ps

module ModRed (
    input clk,
    input reset,
    input [17:0] q,
    input [35:0] P,
    output reg [17:0] C
);

// Hard-coded widths for two-segment implementation:
// DATA_SIZE_ARB = 18
// 2*DATA_SIZE_ARB = 36
// W_SIZE = 9  (RING_DEPTH + 1 with RING_DEPTH = 8)
// W_SIZE-1 = 8
// L_SIZE = 2
// Segment widths: first step NEXT_DATA = 28, final NEXT_DATA = 20

// Internal wires (unrolled instead of array)
wire [35:0] C_reg0;
wire [35:0] C_reg1;
wire [35:0] C_reg2;

// connect P to first stage (36 bits)
assign C_reg0[35:0] = P[35:0];

// First ModRed_sub instance (equivalent to i_gen_loop = 0)
// CURR_DATA = 36, NEXT_DATA = 28
ModRed_sub #(
    .CURR_DATA(36),
    .NEXT_DATA(28)
) mrs (
    .clk(clk),
    .reset(reset),
    .qH(q[17:9]),
    .T1(C_reg0[35:0]),
    .C(C_reg1[27:0])
);

// Last ModRed_sub instance (final stage)
// CURR_DATA = 28, NEXT_DATA = 20 (DATA_SIZE_ARB + 2)
ModRed_sub #(
    .CURR_DATA(28),
    .NEXT_DATA(20)
) mrsl (
    .clk(clk),
    .reset(reset),
    .qH(q[17:9]),
    .T1(C_reg1[27:0]),
    .C(C_reg2[19:0])
);

// final subtraction and comparison
wire [19:0] C_ext;
wire [19:0] C_temp;

// extend/collect result from final stage
assign C_ext  = C_reg2[19:0];

// subtract q (18 bits) from C_ext (20 bits) by zero-extending q to 20 bits
assign C_temp = C_ext - {2'b00, q[17:0]};


// register update / final selection (synchronous, asynchronous reset)
always @(posedge clk or posedge reset) begin
    if (reset) begin
        C <= 18'b0;
    end
    else begin
        // if borrow (MSB of C_temp is 1) then keep C_ext, else take lower 18 bits of C_temp
        if (C_temp[19])
            C <= C_ext[17:0];
        else
            C <= C_temp[17:0];
    end
end

endmodule
