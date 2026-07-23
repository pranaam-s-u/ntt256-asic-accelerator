/*
Copyright 2020, Ahmet Can Mert <ahmetcanmert@sabanciuniv.edu>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
`timescale 1ns / 1ps
module NTTN (input                           clk,
             input                           reset,
             input                           load_w,
             input                           load_data,
             input                           start,
             input                           start_intt,
             input [17:0]       din,
             output reg                      done,
             output reg [17:0]  dout
             );

// ---------------------------------------------------------------- 
// Local parameters
// ----------------------------------------------------------------

// User parameters
localparam DATA_SIZE_ARB = 18;
localparam RING_SIZE     = 256;
localparam PE_NUMBER     = 1;

// Derived parameters
localparam DATA_SIZE       = 32;
localparam DATA_SIZE_DEPTH = 5;
localparam GENERIC         = 2;
localparam CSA_LEVEL       = 2;
localparam INTMUL_DELAY    = 3;

localparam RING_DEPTH      = 8;
localparam W_SIZE          = 9;
localparam L_SIZE          = 2;
localparam MODRED_DELAY    = 5;

localparam PE_DEPTH        = 0;
localparam STAGE_DELAY     = 5;
localparam R               = 18;

// ---------------------------------------------------------------- connections

// parameters & control
reg [2:0] state;
// 0: IDLE
// 1: load twiddle factors + q + n_inv
// 2: load data
// 3: performs ntt
// 4: output data
// 5: last stage of intt

reg [RING_DEPTH+3:0] sys_cntr;

reg [DATA_SIZE_ARB-1:0] q;
reg [DATA_SIZE_ARB-1:0] n_inv;

// data tw brams (datain,dataout,waddr,raddr,wen)
reg [DATA_SIZE_ARB-1:0]        pi_0;
reg [DATA_SIZE_ARB-1:0]        pi_1;
wire [DATA_SIZE_ARB-1:0]       po_0;
wire [DATA_SIZE_ARB-1:0]       po_1;
reg [RING_DEPTH-PE_DEPTH+1:0] pw_0;
reg [RING_DEPTH-PE_DEPTH+1:0] pw_1;
reg [RING_DEPTH-PE_DEPTH+1:0] pr_0;
reg [RING_DEPTH-PE_DEPTH+1:0] pr_1;
reg                           pe_0;
reg                           pe_1;

reg [DATA_SIZE_ARB-1:0]        ti_0;
wire [DATA_SIZE_ARB-1:0]       to_0;
reg [RING_DEPTH-PE_DEPTH+3:0] tw_0;
reg [RING_DEPTH-PE_DEPTH+3:0] tr_0;
reg                           te_0;

// control signals
wire [RING_DEPTH-PE_DEPTH+1:0] raddr;
wire [RING_DEPTH-PE_DEPTH+1:0] waddr0;
wire [RING_DEPTH-PE_DEPTH+1:0] waddr1;
wire                           wen0;
wire                           wen1;
wire                           brsel0;
wire                           brsel1;
wire                           brselen0;
wire                           brselen1;
wire [2*PE_NUMBER*(PE_DEPTH+1)-1:0] brscramble;
wire [RING_DEPTH-PE_DEPTH+2:0]      raddr_tw;

wire [4:0]                       stage_count;
wire                             ntt_finished;

reg                              ntt_intt; // ntt:0 -- intt:1

// pu
reg [DATA_SIZE_ARB-1:0] NTTin_0;
reg [DATA_SIZE_ARB-1:0] NTTin_1;
reg [DATA_SIZE_ARB-1:0] MULin_0;
wire [DATA_SIZE_ARB-1:0] ASout_0;
wire [DATA_SIZE_ARB-1:0] ASout_1;
wire [DATA_SIZE_ARB-1:0] EOout_0;
wire [DATA_SIZE_ARB-1:0] EOout_1;

// ---------------------------------------------------------------- BRAMs
BRAM  bd00(clk,pe_0,pw_0,pi_0,pr_0,po_0);
BRAM  bd01(clk,pe_1,pw_1,pi_1,pr_1,po_1);
BRAM1 bt00(clk,te_0,tw_0,ti_0,tr_0,to_0);

// ---------------------------------------------------------------- NTT2 units
NTT2 nttu(clk,reset,
          q,
          NTTin_0,NTTin_1,
          MULin_0,
          ASout_0,ASout_1,
          EOout_0,EOout_1);

// ---------------------------------------------------------------- control unit
AddressGenerator ag(clk,reset,
                    (start | start_intt),
                    raddr,
                    waddr0,waddr1,
                    wen0,wen1,
                    brsel0,brsel1,
                    brselen0,brselen1,
                    brscramble,
                    raddr_tw,
                    stage_count,
                    ntt_finished
                    );

// ---------------------------------------------------------------- ntt/intt
reg ntt_intt_next;

always @(posedge clk or posedge reset) begin
    if(reset) begin
        ntt_intt <= 1'b0;
    end
    else begin
        ntt_intt <= ntt_intt_next;
    end
end

always @* begin
        ntt_intt_next = ntt_intt;
        if(start)
            ntt_intt_next = 1'b0;
        else if(start_intt)
            ntt_intt_next = 1'b1;
        else
            ntt_intt_next = ntt_intt;
end

// ---------------------------------------------------------------- state machine & sys_cntr
reg [2:0] state_next;
reg [RING_DEPTH+3:0] sys_cntr_next;

always @(posedge clk or posedge reset) begin
    if(reset) begin
        state <= 3'd0;
        sys_cntr <= 0;
    end
    else begin
        state <= state_next;
        sys_cntr <= sys_cntr_next;
    end
end

always @* begin
    state_next = state;
    sys_cntr_next = sys_cntr;
        case(state)
        3'd0: begin
            if(load_w)
                state_next = 3'd1;
            else if(load_data)
                state_next = 3'd2;
            else if(start | start_intt)
                state_next = 3'd3;
            else
                state_next = 3'd0;
            sys_cntr_next = 0;
        end
        3'd1: begin
            if(sys_cntr == ((((((1<<(RING_DEPTH-PE_DEPTH))-1)+PE_DEPTH)<<PE_DEPTH)<<1)+2-1)) begin
                state_next = 3'd0;
                sys_cntr_next = 0;
            end
            else begin
                state_next = 3'd1;
                sys_cntr_next = sys_cntr + 1;
            end
        end
        3'd2: begin
            if(sys_cntr == (RING_SIZE-1)) begin
                state_next = 3'd0;
                sys_cntr_next = 0;
            end
            else begin
                state_next = 3'd2;
                sys_cntr_next = sys_cntr + 1;
            end
        end
        3'd3: begin
            if(ntt_finished && (ntt_intt == 0))
                state_next = 3'd4;
            else if(ntt_finished && (ntt_intt == 1))
                state_next = 3'd5;
            else
                state_next = 3'd3;
            sys_cntr_next = 0;
        end
        3'd4: begin
            if(sys_cntr == (RING_SIZE+1)) begin
                state_next = 3'd0;
                sys_cntr_next = 0;
            end
            else begin
                state_next = 3'd4;
                sys_cntr_next = sys_cntr + 1;
            end
        end
        3'd5: begin
            if(sys_cntr == (((RING_SIZE >> (PE_DEPTH+1))<<1) + INTMUL_DELAY+MODRED_DELAY+STAGE_DELAY)) begin
                state_next = 3'd4;
                sys_cntr_next = 0;
            end
            else begin
                state_next = 3'd5;
                sys_cntr_next = sys_cntr + 1;
            end
        end
        default: begin
            state_next = 3'd0;
            sys_cntr_next = 0;
        end
        endcase
end

// ---------------------------------------------------------------- load twiddle factor + q + n_inv & other operations
reg te_0_next;
reg [RING_DEPTH-PE_DEPTH+3:0] tw_0_next;
reg [DATA_SIZE_ARB-1:0] ti_0_next;
reg [RING_DEPTH-PE_DEPTH+3:0] tr_0_next;

always @(posedge clk or posedge reset) begin
    if(reset) begin
        te_0 <= 1'b0;
        tw_0 <= 0;
        ti_0 <= 0;
        tr_0 <= 0;
    end
    else begin
        te_0 <= te_0_next;
        tw_0 <= tw_0_next;
        ti_0 <= ti_0_next;
        tr_0 <= tr_0_next;
    end
end

always @* begin
    te_0_next = te_0;
    tw_0_next = tw_0;
    ti_0_next = ti_0;
    tr_0_next = tr_0;
    
        if((state == 3'd1) && (sys_cntr < ((((1<<(RING_DEPTH-PE_DEPTH))-1)+PE_DEPTH)<<PE_DEPTH))) begin
            te_0_next = (0 == (sys_cntr & ((1 << PE_DEPTH)-1)));
            tw_0_next[RING_DEPTH-PE_DEPTH+3]   = 1'b0;
            tw_0_next[RING_DEPTH-PE_DEPTH+2:0] = (sys_cntr >> PE_DEPTH);
            ti_0_next = din;
            tr_0_next = 0;
        end
        else if((state == 3'd1) && (sys_cntr < (((((1<<(RING_DEPTH-PE_DEPTH))-1)+PE_DEPTH)<<PE_DEPTH)<<1))) begin
            te_0_next = (0 == ((sys_cntr-((((1<<(RING_DEPTH-PE_DEPTH))-1)+PE_DEPTH)<<PE_DEPTH)) & ((1 << PE_DEPTH)-1)));
            tw_0_next[RING_DEPTH-PE_DEPTH+3]   = 1'b1;
            tw_0_next[RING_DEPTH-PE_DEPTH+2:0] = ((sys_cntr-((((1<<(RING_DEPTH-PE_DEPTH))-1)+PE_DEPTH)<<PE_DEPTH)) >> PE_DEPTH);
            ti_0_next = din;
            tr_0_next = 0;
        end
        else if(state == 3'd3) begin // NTT operations
            te_0_next = 1'b0;
            tw_0_next = 0;
            ti_0_next = 0;
            tr_0_next = {ntt_intt,raddr_tw};
        end
        else begin
            te_0_next = 1'b0;
            tw_0_next = 0;
            ti_0_next = 0;
            tr_0_next = 0;
        end
    end

reg [DATA_SIZE_ARB-1:0] q_next;
reg [DATA_SIZE_ARB-1:0] n_inv_next;

always @(posedge clk or posedge reset) begin
    if(reset) begin
        q     <= 0;
        n_inv <= 0;
    end
    else begin
        q     <= q_next;
        n_inv <= n_inv_next;
    end
end

always @* begin
    q_next = q;
    n_inv_next = n_inv;
    
    if(reset) begin
        q_next = 0;
        n_inv_next = 0;
    end
    else begin
        if((state == 3'd1) && (sys_cntr == ((((((1<<(RING_DEPTH-PE_DEPTH))-1)+PE_DEPTH)<<PE_DEPTH)<<1)+2-2))) begin
            q_next = din;
        end
        if((state == 3'd1) && (sys_cntr == ((((((1<<(RING_DEPTH-PE_DEPTH))-1)+PE_DEPTH)<<PE_DEPTH)<<1)+2-1))) begin
            n_inv_next = din;
        end
    end
end

// ---------------------------------------------------------------- load data & other data operations
wire [RING_DEPTH-PE_DEPTH-1:0] addrout;
wire [RING_DEPTH-PE_DEPTH-1:0] inttlast;
wire [RING_DEPTH+3:0]          sys_cntr_d;
wire [RING_DEPTH-PE_DEPTH-1:0] inttlast_d;

assign addrout = (sys_cntr >> (PE_DEPTH+1));
assign inttlast = (sys_cntr & ((RING_SIZE >> (PE_DEPTH+1))-1));

reg pe_0_next;
reg pe_1_next;
reg [RING_DEPTH-PE_DEPTH+1:0] pw_0_next;
reg [RING_DEPTH-PE_DEPTH+1:0] pw_1_next;
reg [DATA_SIZE_ARB-1:0] pi_0_next;
reg [DATA_SIZE_ARB-1:0] pi_1_next;
reg [RING_DEPTH-PE_DEPTH+1:0] pr_0_next;
reg [RING_DEPTH-PE_DEPTH+1:0] pr_1_next;

always @(posedge clk or posedge reset) begin
    if(reset) begin
        pe_0 <= 1'b0;
        pe_1 <= 1'b0;
        pw_0 <= 0;
        pw_1 <= 0;
        pi_0 <= 0;
        pi_1 <= 0;
        pr_0 <= 0;
        pr_1 <= 0;
    end
    else begin
        pe_0 <= pe_0_next;
        pe_1 <= pe_1_next;
        pw_0 <= pw_0_next;
        pw_1 <= pw_1_next;
        pi_0 <= pi_0_next;
        pi_1 <= pi_1_next;
        pr_0 <= pr_0_next;
        pr_1 <= pr_1_next;
    end
end

always @* begin
    pe_0_next = pe_0;
    pe_1_next = pe_1;
    pw_0_next = pw_0;
    pw_1_next = pw_1;
    pi_0_next = pi_0;
    pi_1_next = pi_1;
    pr_0_next = pr_0;
    pr_1_next = pr_1;
    

    
        if((state == 3'd2)) begin // input data
            if(sys_cntr < (RING_SIZE >> 1)) begin
                pe_0_next = (0 == ((sys_cntr & ((1 << PE_DEPTH)-1)) << 1));
                pw_0_next = (sys_cntr >> PE_DEPTH);
                pi_0_next = din;
                pr_0_next = 0;
                
                pe_1_next = 1'b0;
                pw_1_next = 0;
                pi_1_next = 0;
                pr_1_next = 0;
            end
            else begin
                pe_0_next = 1'b0;
                pw_0_next = 0;
                pi_0_next = 0;
                pr_0_next = 0;
                
                pe_1_next = (1 == (((sys_cntr & ((1 << PE_DEPTH)-1)) << 1)+1));
                pw_1_next = ((sys_cntr-(RING_SIZE >> 1)) >> PE_DEPTH);
                pi_1_next = din;
                pr_1_next = 0;
            end
        end
        else if(state == 3'd3) begin // NTT operations
            if(stage_count < (RING_DEPTH - PE_DEPTH - 1)) begin
                if(brselen0) begin
                    if(brsel0 == 0) begin
                        pe_0_next = wen0;
                        pw_0_next = waddr0;
                        pi_0_next = EOout_0;
                        
                        pe_1_next = 1'b0;
                        pw_1_next = pw_1;
                        pi_1_next = pi_1;
                    end
                    else begin // brsel0 == 1
                        pe_0_next = wen1;
                        pw_0_next = waddr1;
                        pi_0_next = EOout_1;
                        
                        pe_1_next = 1'b0;
                        pw_1_next = pw_1;
                        pi_1_next = pi_1;
                    end
                end
                else begin
                    pe_0_next = 1'b0;
                    pw_0_next = pw_0;
                    pi_0_next = pi_0;
                    
                    pe_1_next = 1'b0;
                    pw_1_next = pw_1;
                    pi_1_next = pi_1;
                end

                if(brselen1) begin
                    if(brsel1 == 0) begin
                        pe_1_next = wen0;
                        pw_1_next = waddr0;
                        pi_1_next = EOout_0;
                    end
                    else begin // brsel1 == 1
                        pe_1_next = wen1;
                        pw_1_next = waddr1;
                        pi_1_next = EOout_1;
                    end
                end
                else begin
                    pe_1_next = 1'b0;
                    pw_1_next = pw_1;
                    pi_1_next = pi_1;
                end
            end
            else if(stage_count < (RING_DEPTH - 1)) begin
                pe_0_next = wen0;
                pe_1_next = wen0;
                pw_0_next = waddr0;
                pw_1_next = waddr0;
                pi_0_next = ASout_0;
                pi_1_next = ASout_1;
            end
            else begin
                pe_0_next = wen0;
                pe_1_next = wen0;
                pw_0_next = waddr0;
                pw_1_next = waddr0;
                pi_0_next = ASout_0;
                pi_1_next = ASout_1;
            end
            pr_0_next = raddr;
            pr_1_next = raddr;
        end
        else if(state == 3'd4) begin // output data
            pe_0_next = 1'b0;
            pe_1_next = 1'b0;
            pw_0_next = 0;
            pw_1_next = 0;
            pi_0_next = 0;
            pi_1_next = 0;
            pr_0_next = {2'b10,addrout};
            pr_1_next = {2'b10,addrout};
        end
        else if(state == 3'd5) begin // last stage of intt
            if(sys_cntr_d < (RING_SIZE >> (PE_DEPTH+1))) begin
                pe_0_next = 1'b1;
                pw_0_next = {2'b10,inttlast_d};
                pi_0_next = ASout_1;
                
                pe_1_next = 1'b0;
                pw_1_next = 0;
                pi_1_next = 0;
            end
            else if(sys_cntr_d < (RING_SIZE >> (PE_DEPTH))) begin
                pe_0_next = 1'b0;
                pw_0_next = 0;
                pi_0_next = 0;
                
                pe_1_next = 1'b1;
                pw_1_next = {2'b10,inttlast_d};
                pi_1_next = ASout_1;
            end
            else begin
                pe_0_next = 1'b0;
                pe_1_next = 1'b0;
                pw_0_next = 0;
                pw_1_next = 0;
                pi_0_next = 0;
                pi_1_next = 0;
            end
            pr_0_next = {2'b10,inttlast};
            pr_1_next = {2'b10,inttlast};
        end
        else begin
            pe_0_next = 1'b0;
            pe_1_next = 1'b0;
            pw_0_next = 0;
            pw_1_next = 0;
            pi_0_next = 0;
            pi_1_next = 0;
            pr_0_next = 0;
            pr_1_next = 0;
    end
end

// done signal & output data
wire [PE_DEPTH:0] coefout;
assign coefout = (sys_cntr-2);

reg done_next;
reg [DATA_SIZE_ARB-1:0] dout_next;

always @(posedge clk or posedge reset) begin
    if(reset) begin
        done <= 1'b0;
        dout <= 0;
    end
    else begin
        done <= done_next;
        dout <= dout_next;
    end
end

always @* begin
    done_next = 1'b0;
    dout_next = 0;
    
    if(reset) begin
        done_next = 1'b0;
        dout_next = 0;
    end
    else begin
        if(state == 3'd4) begin
            done_next = (sys_cntr == 1) ? 1'b1 : 1'b0;
            if(coefout == 0)
                dout_next = po_0;
            else
                dout_next = po_1;
        end
        else begin
            done_next = 1'b0;
            dout_next = 0;
        end
    end
end

// ---------------------------------------------------------------- PU control
reg [DATA_SIZE_ARB-1:0] NTTin_0_next;
reg [DATA_SIZE_ARB-1:0] NTTin_1_next;
reg [DATA_SIZE_ARB-1:0] MULin_0_next;

always @(posedge clk or posedge reset) begin
    if(reset) begin
        NTTin_0 <= 0;
        NTTin_1 <= 0;
        MULin_0 <= 0;
    end
    else begin
        NTTin_0 <= NTTin_0_next;
        NTTin_1 <= NTTin_1_next;
        MULin_0 <= MULin_0_next;
    end
end

always @* begin
    NTTin_0_next = NTTin_0;
    NTTin_1_next = NTTin_1;
    MULin_0_next = MULin_0;
    
        if(state == 3'd5) begin
            if(sys_cntr < (2+(RING_SIZE >> (PE_DEPTH+1)))) begin
                NTTin_0_next = po_0;
                NTTin_1_next = 0;
            end
            else if(sys_cntr < (2+(RING_SIZE >> (PE_DEPTH)))) begin
                NTTin_0_next = po_1;
                NTTin_1_next = 0;
            end
            else begin
                NTTin_0_next = po_0;
                NTTin_1_next = po_1;
            end
            MULin_0_next = n_inv;
        end
        else begin
            NTTin_0_next = po_0;
            NTTin_1_next = po_1;
            MULin_0_next = to_0;

    end
end

// --------------------------------------------------------------------------- delays
ShiftReg #(.SHIFT(INTMUL_DELAY+MODRED_DELAY+STAGE_DELAY-1),.DATA(RING_DEPTH+4)) sr00(clk,reset,sys_cntr,sys_cntr_d);
ShiftReg #(.SHIFT(INTMUL_DELAY+MODRED_DELAY+STAGE_DELAY-1),.DATA(RING_DEPTH-PE_DEPTH)) sr01(clk,reset,inttlast,inttlast_d);

endmodule
