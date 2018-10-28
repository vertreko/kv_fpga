//--------------------------------------------------------------------
// Copyright 2014 by Keith Vertrees
// Use however you like

`timescale 1ps/1ps

module test;
  //------------------------------------------------------------------
  // parameters
  localparam            DONE    = 1;
  localparam            PER     = 10000;
  localparam            DEL_1   = PER / 2;
  localparam            DEL_2   = DEL_1 / 2;
  localparam            DEL_3   = PER - DEL_1 - DEL_2;
  localparam            TIMEOUT = 1000;
  //------------------------------------------------------------------
  // dut inputs
  /*AUTOREGINPUT*/
  // Beginning of automatic reg inputs (for undeclared instantiated-module inputs)
  reg                   clk;                    // To dut of kv_srl_fifo.v
  reg [7:0]             d;                      // To dut of kv_srl_fifo.v
  reg                   rd_en;                  // To dut of kv_srl_fifo.v
  reg                   rst;                    // To dut of kv_srl_fifo.v
  reg                   wr_en;                  // To dut of kv_srl_fifo.v
  // End of automatics
  //------------------------------------------------------------------
  // dut outputs
  /*AUTOWIRE*/
  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire                  empty;                  // From dut of kv_srl_fifo.v
  wire                  err_ovr;                // From dut of kv_srl_fifo.v
  wire                  err_und;                // From dut of kv_srl_fifo.v
  wire                  full;                   // From dut of kv_srl_fifo.v
  wire [7:0]            q;                      // From dut of kv_srl_fifo.v
  // End of automatics

  reg [31:0]            done_flags = 0;
  event                 io;
  reg                   fail       = 0;
  integer               nclocks    = 0;

  task automatic verify
    (// inputs
     input [8*20:1] name_str,
     input integer  got,
     input integer  expected);
    if (got !== expected) begin
      $display("%t(%m) %s: got %d expected %d",
               $time,name_str,got,expected);
      fail <= 1;
    end
  endtask // verify

  task fifo_io
    (//---------------------------------------------------------------
     // inputs
     input [8*5:1] which,
     input [7:0]   write_data,
     //---------------------------------------------------------------
     // outputs
     output [7:0]  read_data);
    begin
      case (which)
        "READ" : begin
          // $display("%t(%m) READ",$time);
          rd_en = 1'b1;
        end
        "WRITE": begin
          // $display("%t(%m) WRITE",$time);
          d     = write_data;
          wr_en = 1'b1;
        end
        "RW"   : begin
          // $display("%t(%m) RW",$time);
          d     = write_data;
          rd_en = 1'b1;
          wr_en = 1'b1;
        end
      endcase // case (which)
      @(io);
      rd_en     = 1'b0;
      read_data = q;
      wr_en     = 1'b0;
    end
  endtask // fifo_io

  initial begin: p_main
    $timeformat(-9, 3, " ns", 15);
/* -----\/----- EXCLUDED -----\/-----
    $dumpfile("xsim.vcd");
    $dumpvars(1,test);
 -----/\----- EXCLUDED -----/\----- */

    clk                 = 1'b0;
    d                   = 8'd0;
    rd_en               = 1'b0;
    rst                 = 1'b1;
    wr_en               = 1'b0;

    fork
      begin: p_clock
        #PER;
        while ((done_flags != DONE) && (nclocks < TIMEOUT)) begin
          clk  = 1'b1;
          nclocks = nclocks + 1;
          #DEL_1;
          clk = 1'b0;
          #DEL_2;
          -> io;
          #DEL_3;
          if (fail) $stop;
        end
        $display("%t(%m): ran for %d clocks",$time,nclocks);
        if (nclocks == TIMEOUT) begin
          $display("%t(%m): SIM TIMEOUT",$time);
          $stop;
        end
      end // block: p_clock
      begin: p_stim
        reg [7:0] read_data;
        integer   i;
        @io;
        rst = 1'b0;
        //------------------------------------------------------------
        // write until FIFO full
        for (i=0;i<31;i=i+1) begin
          fifo_io("WRITE",i+128,read_data);
        end
        verify("full=1",full,1);
        //------------------------------------------------------------
        // do some read/writes while FIFO full
        for (i=31;i<40;i=i+1) begin
          fifo_io("RW",i+128,read_data);
          verify("full reads",read_data,i+128-31);
          verify("err_ovr=0 a",err_ovr,0);
        end
        //------------------------------------------------------------
        // read FIFO to empty & verify output
        for (i=40;i<71;i=i+1) begin
          fifo_io("READ",0,read_data);
          verify("reads",read_data,i+128-31);
        end
        verify("empty=1 a",empty,1);
        //------------------------------------------------------------
        // verify read/write with FIFO empty
        fifo_io("RW",255,read_data);
        verify("empty=1 b",empty,1);
        verify("empty read",read_data,255);
        verify("err_und=0",err_und,0);
        //------------------------------------------------------------
        // read while empty, causing underflow
        fifo_io("READ",0,read_data);
        verify("err_und=1",err_und,1);
        rst = 1;
        @io;
        rst = 0;
        i = 0;
        //------------------------------------------------------------
        // write until FIFO full
        while (!full) begin
          fifo_io("WRITE",i,read_data);
          i = i + 1;
        end
        //------------------------------------------------------------
        // write while full, causing overflow
        verify("err_ovr=0 b",err_ovr,0);
        fifo_io("WRITE",i,read_data);
        verify("err_ovr=1",err_ovr,1);
        rst = 1;
        @io;
        rst = 0;
        i = 0;
        //------------------------------------------------------------
        // fill FIFO while reading at half speed
        while (!full) begin
          if (i[0])
            fifo_io("WRITE",i,read_data);
          else begin
            fifo_io("RW",i,read_data);
            verify("slow read a",read_data,i/2);
          end
          i = i + 1;
        end
        //------------------------------------------------------------
        // finish reading FIFO
        i = i / 2;
        while (!empty) begin
          fifo_io("READ",255,read_data);
          verify("slow read b",read_data,i);
          i = i + 1;
        end
        @io;
        done_flags[0] = 1'b1;
      end // block: p_stim
    join
    $display("%t(%m): SIM PASSED",$time);
  end // block: p_main

  kv_srl_fifo #(.WIDTH(8)) dut
    (/*AUTOINST*/
     // Outputs
     .empty                             (empty),
     .err_ovr                           (err_ovr),
     .err_und                           (err_und),
     .full                              (full),
     .q                                 (q[7:0]),
     // Inputs
     .clk                               (clk),
     .d                                 (d[7:0]),
     .rd_en                             (rd_en),
     .wr_en                             (wr_en),
     .rst                               (rst));

endmodule // test
// Local Variables:
// verilog-library-directories:("../../../rtl")
// End:
