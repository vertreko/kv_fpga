//--------------------------------------------------------------------
// Copyright 2014 by Keith Vertrees
// Use however you like
//
// A common clock FIFO implemented with Xilinx SRL library cells.  The
// data width is parameterized, but the FIFO has a static maximum
// depth of 31 entries. This is not a fall through FIFO. The read data
// is available on the clock after rd_en is asserted, and remains
// until the next rd_en. The error flags are sticky. They will remain
// high until rst is asserted.

module kv_srl_fifo #
  (//-----------------------------------------------------------------
   // parameters
   parameter WIDTH = 8)
  (//-----------------------------------------------------------------
   // inputs
   input              clk,
   input [WIDTH-1:0]  d,
   input              rd_en,
   input              wr_en,
   input              rst,
   //-----------------------------------------------------------------
   // outputs
   output             empty,
   output             err_ovr,
   output             err_und,
   output             full,
   output [WIDTH-1:0] q);
  //------------------------------------------------------------------
  // registers
  reg                 empty_d;
  reg                 empty_q;

  reg                 err_ovr_d;
  reg                 err_ovr_q;

  reg                 err_und_d;
  reg                 err_und_q;

  reg                 full_d;
  reg                 full_q;

  wire [4:0]          rd_ptr_d;
  reg [4:0]           rd_ptr_q;
  //------------------------------------------------------------------
  // wires
  reg [4:0]           incr;
  //------------------------------------------------------------------
  // sequential
  always @(posedge clk) begin
    if (rst) begin
      empty_q           <= 1'd1;
      err_ovr_q         <= 1'd0;
      err_und_q         <= 1'd0;
      full_q            <= 1'd0;
      rd_ptr_q          <= 5'd0;
    end
    else begin
      empty_q           <= empty_d;
      err_ovr_q         <= err_ovr_d;
      err_und_q         <= err_und_d;
      full_q            <= full_d;
      rd_ptr_q          <= rd_ptr_d;
    end // else: !if(rst)
  end // always @ (posedge clk)
  //------------------------------------------------------------------
  // combinational
  always @* begin
    empty_d             = empty_q;
    err_ovr_d           = err_ovr_q;
    err_und_d           = err_und_q;
    full_d              = full_q;
    incr                = 5'd0;

    case ({rd_en,wr_en})
      2'b01: begin
        // net write
        empty_d   = 1'b0;
        err_ovr_d = err_ovr_q | full_q;
        full_d    = rd_ptr_q == 5'd30;
        incr      = 5'd1;
      end
      2'b10: begin
        // net read
        empty_d   = rd_ptr_q == 5'd1;
        err_und_d = err_und_q | empty_q;
        full_d    = 1'b0;
        incr      = -5'd1;
      end
    endcase // case ({rd_en,wr_en})
  end // always @ *

  assign rd_ptr_d = rd_ptr_q + incr;
  //------------------------------------------------------------------
  // instantiate SRL cells
  generate
    genvar b;
    for (b=0;b<WIDTH;b=b+1) begin: g_b
      SRLC32E dut
           (// Outputs
            .Q                          (q[b]),
            .Q31                        (),
            // Inputs
            .CE                         (wr_en),
            .CLK                        (clk),
            .D                          (d[b]),
            .A                          (rd_ptr_q));
    end // block: g_b
  endgenerate
  //------------------------------------------------------------------
  // outputs
  assign empty          = empty_q;
  assign err_ovr        = err_ovr_q;
  assign err_und        = err_und_q;
  assign full           = full_q;
endmodule // kv_srl_fifo
