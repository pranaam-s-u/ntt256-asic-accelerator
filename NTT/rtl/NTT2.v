`timescale 1ns / 1ps
module NTT2 #(
    parameter DATA_SIZE_ARB = 18,
    // delay = INTMUL_DELAY + MODRED_DELAY
    parameter INTMUL_DELAY  = 3,
    parameter L_SIZE        = 2,  // For K=18, RING_SIZE=256 → W=9 → L=2
    parameter MODRED_DELAY  = (L_SIZE * 2 + 1),
    parameter SHIFT_DELAY   = (INTMUL_DELAY + MODRED_DELAY)
)(
    input                         clk,
    input                         reset,
    input      [DATA_SIZE_ARB-1:0] q,
    input      [DATA_SIZE_ARB-1:0] NTTin0,
    input      [DATA_SIZE_ARB-1:0] NTTin1,
    input      [DATA_SIZE_ARB-1:0] MULin,
    output reg [DATA_SIZE_ARB-1:0] ADDout,
    output reg [DATA_SIZE_ARB-1:0] SUBout,
    output reg [DATA_SIZE_ARB-1:0] NTToutEVEN,
    output reg [DATA_SIZE_ARB-1:0] NTToutODD
);

/////////////////////////////////////
// Modular add
/////////////////////////////////////
wire        [DATA_SIZE_ARB  :0] madd;
wire signed [DATA_SIZE_ARB+1:0] madd_q;
wire        [DATA_SIZE_ARB-1:0] madd_res;

assign madd     = NTTin0 + NTTin1;
assign madd_q   = madd - q;
assign madd_res = (madd_q[DATA_SIZE_ARB+1] == 1'b0) ? 
                    madd_q[DATA_SIZE_ARB-1:0] : 
                    madd[DATA_SIZE_ARB-1:0];

/////////////////////////////////////
// Modular sub
/////////////////////////////////////
wire        [DATA_SIZE_ARB  :0] msub;
wire signed [DATA_SIZE_ARB+1:0] msub_q;
wire        [DATA_SIZE_ARB-1:0] msub_res;

assign msub     = NTTin0 - NTTin1;
assign msub_q   = msub + q;
assign msub_res = (msub[DATA_SIZE_ARB] == 1'b0) ? 
                    msub[DATA_SIZE_ARB-1:0] : 
                    msub_q[DATA_SIZE_ARB-1:0];

/////////////////////////////////////
// First pipeline stage
/////////////////////////////////////
reg [DATA_SIZE_ARB-1:0] MULin0, MULin1;
reg [DATA_SIZE_ARB-1:0] ADDreg;

always @(posedge clk) begin
    if (reset) begin
        MULin0 <= 0;
        MULin1 <= 0;
        ADDreg <= 0;
    end else begin
        MULin0 <= MULin;
        MULin1 <= msub_res;
        ADDreg <= madd_res;
    end
end

/////////////////////////////////////
// Modular multiply
/////////////////////////////////////
wire [DATA_SIZE_ARB-1:0] MODout;

ModMult mm (
    .clk(clk), .reset(reset), 
    .A(MULin0), .B(MULin1), .q(q), 
    .C(MODout)
);

/////////////////////////////////////
// Shift register for ADD path
/////////////////////////////////////
wire [DATA_SIZE_ARB-1:0] ADDreg_next;

ShiftReg #(
    .SHIFT(SHIFT_DELAY),
    .DATA(DATA_SIZE_ARB)
) pipe_add (
    .clk(clk), .reset(reset), 
    .data_in(ADDreg), .data_out(ADDreg_next)
);

/////////////////////////////////////
// Output stage
/////////////////////////////////////
always @(*) begin
    ADDout     = ADDreg_next;
    SUBout     = MODout;
    NTToutEVEN = ADDreg_next;
end

always @(posedge clk) begin
    if (reset)
        NTToutODD <= 0;
    else
        NTToutODD <= SUBout;
end

endmodule
