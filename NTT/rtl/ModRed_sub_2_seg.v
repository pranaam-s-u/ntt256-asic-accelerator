/*
Modified for ASIC synthesis
Verilog-2001, two-segment coding style
No loops, genvars, functions, tasks, or initial blocks
*/
`timescale 1ns/1ps


module ModRed_sub #(
    parameter CURR_DATA = 0,
    parameter NEXT_DATA = 0
)(
    input wire clk,
    input wire reset,
    input wire [8:0] qH,               // (18 - 7) = 11 bits hardcoded for (DATA_SIZE_ARB - W_SIZE)
    input wire [CURR_DATA-1:0] T1,
    output reg [NEXT_DATA-1:0] C
);

    // ---------------- Hardcoded parameters ----------------
    // DATA_SIZE_ARB = 18
    // RING_SIZE = 256 -> log2(256) = 8
    // RING_DEPTH = 8
    // W_SIZE = RING_DEPTH + 1 = 9

    // ---------------- Internal registers ----------------
    reg [8:0] T2L;
    reg [8:0] T2;
    reg [(CURR_DATA - 9)-1:0] T2H;
    reg CARRY;
    (* use_dsp = "yes" *) reg [17:0] MULT;

    // ---------------- Combinational logic ----------------
    always @* begin
        T2L = T1[8:0];
        T2  = -T2L;
    end

    reg [(CURR_DATA - 9)-1:0] T2H_my;
    reg CARRY_my;
    reg [17:0] MULT_my;
    reg [NEXT_DATA-1:0]C_my;
    // ---------------- Sequential logic ----------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            T2H   <= {((CURR_DATA - 9)){1'b0}};
            CARRY <= 1'b0;
            MULT  <= 18'd0;
            C     <= {NEXT_DATA{1'b0}};
        end
        else begin
            T2H   <= T2H_my;
            CARRY <= CARRY_my;
            MULT  <= MULT_my;
            C     <= C_my;
        end
    end

    always @* begin
        T2H_my = (T1 >> 9);
        CARRY_my = (T2L[8] | T2[8]);
        MULT_my = qH * T2;
        C_my = (MULT + T2H) + CARRY;
    end
endmodule
