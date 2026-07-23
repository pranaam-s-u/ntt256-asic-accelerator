`timescale 1ns / 1ps


module ModMult(
    input clk,
    input reset,
    input [17:0] A,
    input [17:0] B,
    input [17:0] q,
    output [17:0] C
);

// --------------------------------------------------------------- connections
wire [35:0] P;

// --------------------------------------------------------------- module instances
intMult im(
    .clk(clk),
    .reset(reset),
    .A(A),
    .B(B),
    .C(P)
);

ModRed mr(
    .clk(clk),
    .reset(reset),
    .q(q),
    .P(P),
    .C(C)
);

endmodule
