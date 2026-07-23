`timescale 1ns / 1ps
module intMult(
    input clk,
    input reset,
    input [17:0] A,
    input [17:0] B,
    output reg [35:0] C
);

// internal registers and wires
reg [15:0] first_index_dsp0;
reg [15:0] second_index_dsp0;

reg [35:0] output_dsp0;
reg [35:0] output_dsp1;
reg [35:0] output_dsp2;
reg [35:0] output_dsp3;

reg [35:0] op_reg0;
reg [35:0] op_reg1;
reg [35:0] op_reg2;
reg [35:0] C_out;
reg [35:0] S_out;

//My var

reg [35:0] output_dsp0_my;
reg [35:0] output_dsp1_my;
reg [35:0] output_dsp2_my;
reg [35:0] output_dsp3_my;

 reg [35:0] C_out_my;
reg [35:0] C_my;

// --------------------------------------------------------------- divide inputs into 16-bit chunks
always @(*) begin
    first_index_dsp0 = A[15:0];
    second_index_dsp0 = B[15:0];
end

// --------------------------------------------------------------- multiply 16-bit chunks
always @(posedge clk or posedge reset) begin
    if(reset) begin
        output_dsp0 <= 36'd0;
        output_dsp1 <= 36'd0;
        output_dsp2 <= 36'd0;
        output_dsp3 <= 36'd0;
    end
    else begin
        // 18-bit multiplication is split into 16-bit partials
        // (A[15:0]*B[15:0]) + ((A[17:16]*B[15:0])<<16) + ((A[15:0]*B[17:16])<<16) + ((A[17:16]*B[17:16])<<32)
        output_dsp0 <=  output_dsp0_my;                     // low * low
        output_dsp1 <=  output_dsp1_my;                     // high * low
        output_dsp2 <=  output_dsp2_my;                     // low * high
        output_dsp3 <=  output_dsp3_my;                     // high * high
    end
end

always @* begin
    output_dsp0_my = (first_index_dsp0[15:0] * second_index_dsp0[15:0]);
    output_dsp1_my = ((A[17:16] * second_index_dsp0[15:0]) << 16);
    output_dsp2_my = ((first_index_dsp0[15:0] * B[17:16]) << 16); 
    output_dsp3_my = ((A[17:16] * B[17:16]) << 32);

end
// --------------------------------------------------------------- Carry-Save Adder equivalent
always @* begin
    op_reg0 = output_dsp0;
    op_reg1 = output_dsp1 + output_dsp2;
    op_reg2 = output_dsp3;
end
   

always @(*) begin
    C_out_my = op_reg0 + op_reg1;
end
// DFF value
always @(posedge clk or posedge reset) begin
    if(reset) begin
        C_out <= 36'd0;
        S_out <= 36'd0;
    end
    else begin
        C_out <= C_out_my;
        S_out <= op_reg2;
    end
end



always @* begin
    C_my = C_out + S_out;
end
// --------------------------------------------------------------- final addition
always @(posedge clk or posedge reset) begin
    if(reset)
        C <= 36'd0;
    else
        C <= C_my;
end

endmodule






















