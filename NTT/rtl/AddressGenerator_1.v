// Converted to Verilog-2001, ASIC-synthesizable, hard-coded constants (no localparams),
// no for-loops / genvars / functions / tasks / initial blocks.
// Signal names preserved.
`timescale 1ns / 1ps
module AddressGenerator (input                                       clk,
                         input                                       reset,
                         input                                       start,
                         output reg [9:0]                            raddr0,    // RING_DEPTH-PE_DEPTH+1 : 8-0+1 = 9 -> [9:0]
                         output reg [9:0]                            waddr0,
                         output reg [9:0]                            waddr1,
                         output reg                                  wen0,
                         output reg                                  wen1,
                         output reg                                  brsel0,
                         output reg                                  brsel1,
                         output reg                                  brselen0,
                         output reg                                  brselen1,
                         output reg [1:0]                            brscramble0, // 2*PE_NUMBER*(PE_DEPTH+1)-1:0 -> 1:0
                         output reg [10:0]                           raddr_tw, // RING_DEPTH-PE_DEPTH+2 : 8-0+2 = 10 -> [10:0]
                         output reg [4:0]                            stage_count,
                         output reg                                  ntt_finished);

// ---------------------------------------------------------------------------
// Hard-coded values (derived from original localparams):
// DATA_SIZE_ARB = 18
// RING_SIZE     = 256 -> RING_DEPTH = 8
// PE_NUMBER     = 1 -> PE_DEPTH = 0
// W_SIZE = 9, L_SIZE = 2, MODRED_DELAY = 5, INTMUL_DELAY = 3, STAGE_DELAY = 5

// ---------------------------------------------------------------------------
// Control signals (widths hard-coded)
reg [4:0] c_stage_limit;
reg [8:0] c_loop_limit;


reg [10:0] c_tw_limit;


reg [4:0] c_stage, c_stage_n;
reg [8:0] c_loop,  c_loop_n;

reg [10:0] c_tw, c_tw_n;

reg [8:0] c_wait_limit, c_wait;
reg [8:0] c_wait_limit_n, c_wait_n;



reg [7:0] raddr,  raddr_n;
reg [1:0] raddr_m, raddr_m_n;


reg [7:0] waddre,  waddre_n;
reg [7:0] waddro,  waddro_n;
reg [1:0] waddr_m, waddr_m_n;

reg       wen;
reg       brsel;
reg       brselen;
reg       finished;
reg [1:0] brscramble;
reg [1:0] brscramble_my;
// ---------------------------------------------------------------------------
// FSM
reg [1:0] state, state_n;
// 0 --> IDLE
// 1 --> NTT
// 2 --> NTT (WAIT between stages)


// FSM: 0=IDLE, 1=NTT, 2=WAIT


always @(posedge clk or posedge reset) begin
  if (reset) state <= 2'd0;
  else       state <= state_n;
end

always @(*) begin
  state_n = state;
  case (state)
    2'd0: begin
      // enter NTT when start is seen
      if (start) state_n = 2'd1;
    end
    2'd1: begin
      // loop through butterflies
      state_n = (c_loop == c_loop_limit) ? 2'd2 : 2'd1;
    end
    2'd2: begin
      // inter-stage wait
      if ((c_stage == c_stage_limit) && (c_wait == c_wait_limit))
        state_n = 2'd0;       // finished
      else if (c_wait == c_wait_limit)
        state_n = 2'd1;       // next stage
      else
        state_n = 2'd2;       // keep waiting
    end
    default: state_n = 2'd0;
  endcase
end


// --------------------------------------------------------------------------- WAIT OPERATION


always @(posedge clk or posedge reset) begin
  if (reset) begin
    c_wait_limit <= 9'd0;
    c_wait       <= 9'd0;
  end else begin
    c_wait_limit <= c_wait_limit_n;
    c_wait       <= c_wait_n;
  end
end

always @(*) begin
  c_wait_limit_n = c_wait_limit;
  if (start) c_wait_limit_n = 9'd15;

  if (state == 2'd2) c_wait_n = (c_wait < c_wait_limit) ? (c_wait + 9'd1) : 9'd0;
  else               c_wait_n = 9'd0;
end


// --------------------------------------------------------------------------- c_stage & c_loop

always @(posedge clk, posedge reset) begin
    if (reset) begin
        c_stage_limit <= 5'd0;
        c_loop_limit  <= 9'd0;
    end
    else begin
        if (start) begin
            c_stage_limit <= 5'd7;                     // RING_DEPTH-1 => 8-1 = 7
            c_loop_limit  <= 9'd127;                   // (RING_SIZE >> (PE_DEPTH+1)) - 1 => (256 >> 1) -1 = 128-1 =127
        end
        else begin
            c_stage_limit <= c_stage_limit;
            c_loop_limit  <= c_loop_limit;
        end
    end
end



always @(posedge clk or posedge reset) begin
  if (reset) begin
    c_stage <= 5'd0;
    c_loop  <= 9'd0;
  end else begin
    c_stage <= c_stage_n;
    c_loop  <= c_loop_n;
  end
end

// limits are already set on start in your code; keep that block as-is

always @(*) begin
  // stage
  if ((state == 2'd2) && (c_wait == c_wait_limit) && (c_stage == c_stage_limit))
    c_stage_n = 5'd0;
  else if ((state == 2'd2) && (c_wait == c_wait_limit))
    c_stage_n = c_stage + 5'd1;
  else
    c_stage_n = c_stage;

  // loop
  if ((state == 2'd2) && (c_wait == c_wait_limit))
    c_loop_n = 9'd0;
  else if ((state == 2'd1) && (c_loop < c_loop_limit))
    c_loop_n = c_loop + 9'd1;
  else
    c_loop_n = c_loop;
end


// --------------------------------------------------------------------------- twiddle factors
wire [10:0] c_tw_temp = (c_loop_limit >> c_stage);



always @(posedge clk or posedge reset) begin
  if (reset) c_tw <= 11'd0;
  else       c_tw <= c_tw_n;
end

always @(*) begin
  c_tw_n = c_tw;

  if (start) begin
    c_tw_n = 11'd0;
  end else if ((state == 2'd1) && (c_loop != c_loop_limit)) begin
    if (c_stage == 5'd0) begin
      if (c_loop[0] == 1'b0)
        c_tw_n = ((c_tw + ((1 << (8-0-2)) >> c_stage)) & c_loop_limit);
      else
        c_tw_n = ((c_tw + 11'd1 - ((1 << (8-0-2)) >> c_stage)) & c_loop_limit);
    end else if (c_stage >= 5'd7) begin
      c_tw_n = c_tw; // no change
    end else begin
      if (c_loop[0] == 1'b0) begin
        c_tw_n = c_tw
               + ((1 << (8-0-2)) >> c_stage)
               - (((c_loop & c_tw_temp) == c_tw_temp) ? (((c_loop & c_tw_temp)>>1) + 1) : 0);
      end else begin
        c_tw_n = (c_tw + 11'd1)
               - ((1 << (8-0-2)) >> c_stage)
               - (((c_loop & c_tw_temp) == c_tw_temp) ? (((c_loop & c_tw_temp)>>1) + 1) : 0);
      end
    end
  end else if ((state == 2'd2) && (c_wait == c_wait_limit) && (c_stage == c_stage_limit)) begin
    c_tw_n = 11'd0;
  end else if ((state == 2'd2) && (c_wait == c_wait_limit)) begin
    c_tw_n = c_tw + 11'd1;
  end
end

// --------------------------------------------------------------------------- raddr (1 cc delayed)


wire [7:0] raddr_temp = ((8-0-1) - (c_stage + 1)); // 7 - (c_stage+1)

always @(posedge clk or posedge reset) begin
  if (reset) begin
    raddr   <= 8'd0;
    raddr_m <= 2'd0;
  end else begin
    raddr   <= raddr_n;
    raddr_m <= raddr_m_n;
  end
end

always @(*) begin
  // default hold
  raddr_n   = raddr;
  raddr_m_n = raddr_m;

  if (start) begin
    raddr_n   = 8'd0;
    raddr_m_n = 2'd0;
  end else begin
    if ((state == 2'd2) && (c_wait == c_wait_limit)) begin
      raddr_n   = 8'd0;
      raddr_m_n = {raddr_m[1], ~raddr_m[0]};
    end else if ((state == 2'd1) && (c_loop <= c_loop_limit)) begin
      if (c_stage < (8-0-1)) begin
        raddr_n = (~c_loop[0])
                  ? ((c_loop >> 1) + ((c_loop >> (raddr_temp+1)) << raddr_temp))
                  : ((1 << raddr_temp) + (c_loop >> 1) + ((c_loop >> (raddr_temp+1)) << raddr_temp));
      end else begin
        raddr_n = c_loop[7:0];
      end
    end
  end
end


// --------------------------------------------------------------------------- waddr (1 cc delayed)


wire [7:0] waddr_temp = ((8-0-1) - (c_stage + 1));

always @(posedge clk or posedge reset) begin
  if (reset) begin
    waddre  <= 8'd0;
    waddro  <= 8'd0;
    waddr_m <= 2'd0;
  end else begin
    waddre  <= waddre_n;
    waddro  <= waddro_n;
    waddr_m <= waddr_m_n; // <- important: update from next
  end
end

always @(*) begin
  // defaults
  waddre_n  = waddre;
  waddro_n  = waddro;
  waddr_m_n = waddr_m;

  if (start) begin
    waddre_n  = 8'd0;
    waddro_n  = (1 << (8-0-1));
    waddr_m_n = 2'd1;
  end else begin
    if ((state == 2'd2) && (c_wait == c_wait_limit)) begin
      waddre_n  = 8'd0;
      waddro_n  = 8'd0;
      if (c_stage == (c_stage_limit - 1))
        waddr_m_n = 2'b10;
      else
        waddr_m_n = {waddr_m[1], ~waddr_m[0]};
    end else if ((state == 2'd1) && (c_loop <= c_loop_limit)) begin
      if (c_stage < (8-0-1)) begin
        waddre_n = (c_loop >> 1) + ((c_loop >> (waddr_temp+1)) << waddr_temp);
        waddro_n = (c_loop >> 1) + ((c_loop >> (waddr_temp+1)) << waddr_temp) + (1 << waddr_temp);
      end else begin
        waddre_n = c_loop[7:0];
        waddro_n = c_loop[7:0];
      end
    end
  end
end

// --------------------------------------------------------------------------- wen,brsel,brselen (1 cc delayed)

always @(posedge clk, posedge reset) begin
    if (reset) begin
        wen     <= 1'b0;
        brsel   <= 1'b0;
        brselen <= 1'b0;
    end
    else begin
        if (state == 2'd1) begin
            wen     <= 1'b1;
            brsel   <= c_loop[0];
            brselen <= 1'b1;
        end
        else begin
            wen     <= 1'b0;
            brsel   <= 1'b0;
            brselen <= 1'b0;
        end
    end
end

// --------------------------------------------------------------------------- brscrambled (unrolled; original loop had 2 iterations for PE_NUMBER=1)

wire [0:0] brscrambled_temp;
wire [0:0] brscrambled_temp2;
wire [0:0] brscrambled_temp3;
assign brscrambled_temp  = (1 >> (c_stage - (8-0-1)));   // (PE_NUMBER >> (c_stage-(RING_DEPTH-PE_DEPTH-1)))
assign brscrambled_temp2 = (0 - (c_stage - (8-0-1)));   // (PE_DEPTH - (c_stage-(RING_DEPTH-PE_DEPTH-1)))
assign brscrambled_temp3 = ((0+1) - (c_stage - (8-0-1))); // ((PE_DEPTH+1) - (c_stage-(RING_DEPTH-PE_DEPTH-1)))

always @(posedge clk, posedge reset) begin
    if (reset) begin
        brscramble <= 2'b00;
    end    
    else begin
        brscramble <= brscramble_my;
    end
end

always @(*) begin
    brscramble_my =brscramble;
        if (c_stage >= (8-0-1)) begin
            // n = 0
            // brscramble[(PE_DEPTH+1)*0+:(PE_DEPTH+1)] <= (brscrambled_temp*0[0]) + (((0>>1)<<1) & (brscrambled_temp-1)) + ((0>>(brscrambled_temp2+1))<<(brscrambled_temp3)) + ((0>>brscrambled_temp2) & 1);
            // Evaluate for n=0: most terms zero -> result = 0
            brscramble_my[1:0] = 2'b00; // we'll assign both n=0 and n=1 parts below

            // n = 1
            // compute expression for n=1:
            // (brscrambled_temp*1[0]) + (((1>>1)<<1) & (brscrambled_temp-1)) + ((1>>(brscrambled_temp2+1))<<(brscrambled_temp3)) + ((1>>brscrambled_temp2) & 1);
            // Break down and place into bits: since PE_DEPTH+1 = 1 bit per n, we map n=0 -> bit[0], n=1 -> bit[1].
            // We implement compactly as:
            brscramble_my[0] = 1'b0; // n=0 -> 0
            // For n=1 compute bit:
            // We'll implement the intended arithmetic conservatively to mirror original behavior:
            brscramble_my[1] = (brscrambled_temp * 1'b1)
                             | ((((1 >> 1) << 1) & (brscrambled_temp - 1)) != 0)
                             | ((((1 >> (brscrambled_temp2 + 1)) << brscrambled_temp3) != 0))
                             | (((1 >> brscrambled_temp2) & 1'b1) != 0);
            // Note: some synthesizers may optimize expressions above. This keeps logic combinational.
        end
        else begin
            brscramble_my = 2'b00;
        end
end

// --------------------------------------------------------------------------- ntt_finished

always @(posedge clk, posedge reset) begin
    if (reset) begin
        finished <= 1'b0;
    end
    else begin
        if ((state == 2'd2) && (c_wait == c_wait_limit) && (c_stage == c_stage_limit))
            finished <= 1'b1;
        else
            finished <= 1'b0;
    end
end

// --------------------------------------------------------------------------- delays
// Note: The original used ShiftReg11 modules to delay signals. Here we keep the same instantiations
// but with hard-coded SHIFT and DATA values derived from constants:
// INTMUL_DELAY = 3, MODRED_DELAY = 5, STAGE_DELAY = 5

// -------------------- read signals
wire [10:0] c_tw_w;





// Shift of 1; DATA = RING_DEPTH-PE_DEPTH+3 => 8-0+3 = 11
ShiftReg #(.SHIFT(1), .DATA(11)) sr00 (clk, reset, c_tw, c_tw_w);

always @(posedge clk, posedge reset) begin
    if (reset) begin
        raddr0   <= 10'd0;
        raddr_tw <= 11'd0;
    end
    else begin
        raddr0   <= {raddr_m, raddr};
        raddr_tw <= c_tw_w;
    end
end

// -------------------- write signals (waddr0/1, wen0/1, brsel0/1, brselen0/1)
// waddr0/1
wire [9:0] waddre_w, waddro_w;

// SHIFT = INTMUL_DELAY + MODRED_DELAY + STAGE_DELAY = 3 + 5 + 5 = 13
// DATA = RING_DEPTH-PE_DEPTH+2 => 8-0+2 = 10 -> [9:0] width
ShiftReg #(.SHIFT(13), .DATA(10)) sr01 (clk, reset, {waddr_m, waddre}, waddre_w);
ShiftReg #(.SHIFT(14), .DATA(10)) sr02 (clk, reset, {waddr_m, waddro}, waddro_w);

always @* begin
    waddr0 = waddre_w;
    waddr1 = waddro_w;
end

// wen0/1
wire [0:0] wen0_w, wen1_w;

ShiftReg #(.SHIFT(13), .DATA(1)) sr03 (clk, reset, wen, wen0_w);
ShiftReg #(.SHIFT(14), .DATA(1)) sr04 (clk, reset, wen, wen1_w);

always @* begin
    wen0 = wen0_w;
    wen1 = wen1_w;
end

// brsel
wire [0:0] brsel0_w, brsel1_w;

ShiftReg #(.SHIFT(13), .DATA(1)) sr05 (clk, reset, brsel, brsel0_w);
ShiftReg #(.SHIFT(14), .DATA(1)) sr06 (clk, reset, brsel, brsel1_w);

always @* begin
    brsel0 = brsel0_w;
    brsel1 = brsel1_w;
end

// brselen
wire [0:0] brselen0_w, brselen1_w;

ShiftReg #(.SHIFT(13), .DATA(1)) sr07 (clk, reset, brselen, brselen0_w);
ShiftReg #(.SHIFT(14), .DATA(1)) sr08 (clk, reset, brselen, brselen1_w);

always @* begin
    brselen0 = brselen0_w;
    brselen1 = brselen1_w;
end

// stage count
wire [4:0] c_stage_w;

ShiftReg #(.SHIFT(14), .DATA(5)) sr09 (clk, reset, c_stage, c_stage_w);

always @* begin
    stage_count = c_stage_w;
end

// brscrambled
wire [1:0] brscramble_w;

ShiftReg #(.SHIFT(13), .DATA(2)) sr10 (clk, reset, brscramble, brscramble_w);

always @* begin
    brscramble0 = brscramble_w;
end

// ntt finished
wire finished_w;

ShiftReg #(.SHIFT(4), .DATA(1)) sr11 (clk, reset, finished, finished_w);

always @* begin
    ntt_finished = finished_w;
end

endmodule
