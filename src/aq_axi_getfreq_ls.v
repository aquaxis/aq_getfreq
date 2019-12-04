/*
 * Copyright (C)2014-2017 AQUAXIS TECHNOLOGY.
 *  Don't remove this header.
 * When you use this source, there is a need to inherit this header.
 *
 * License
 *  For no commercial -
 *   License:     The Open Software License 3.0
 *   License URI: http://www.opensource.org/licenses/OSL-3.0
 *
 *  For commmercial -
 *   License:     AQUAXIS License 1.0
 *   License URI: http://www.aquaxis.com/licenses
 *
 * For further information please contact.
 *	URI:    http://www.aquaxis.com/
 *	E-Mail: info(at)aquaxis.com
 */
module aq_axi_getfreq_ls
  (
   // AXI4 Lite Interface
   input         ARESETN,
   input         ACLK,

    // Write Address Channel
   input [15:0]  S_AXI_AWADDR,
   input [3:0]   S_AXI_AWCACHE, // 4'b0011
   input [2:0]   S_AXI_AWPROT, // 3'b000
   input         S_AXI_AWVALID,
   output        S_AXI_AWREADY,

   // Write Data Channel
   input [31:0]  S_AXI_WDATA,
   input [3:0]   S_AXI_WSTRB,
   input         S_AXI_WVALID,
   output        S_AXI_WREADY,

   // Write Response Channel
   output        S_AXI_BVALID,
   input         S_AXI_BREADY,
   output [1:0]  S_AXI_BRESP,

   // Read Address Channel
   input [15:0]  S_AXI_ARADDR,
   input [3:0]   S_AXI_ARCACHE, // 4'b0011
   input [2:0]   S_AXI_ARPROT, // 3'b000
   input         S_AXI_ARVALID,
   output        S_AXI_ARREADY,

   // Read Data Channel
   output [31:0] S_AXI_RDATA,
   output [1:0]  S_AXI_RRESP,
   output        S_AXI_RVALID,
   input         S_AXI_RREADY,

   // Local Interface
   output        AQ_LOCAL_CLK,
   output        AQ_LOCAL_CS,
   output        AQ_LOCAL_RNW,
   input         AQ_LOCAL_ACK,
   output [31:0] AQ_LOCAL_ADDR,
   output [3:0]  AQ_LOCAL_BE,
   output [31:0] AQ_LOCAL_WDATA,
   input [31:0]  AQ_LOCAL_RDATA,

   output [31:0] DEBUG
  );

   /*
    CACHE[3:0]
    WA RA C  B
    0  0  0  0 Noncacheable and nonbufferable
    0  0  0  1 Bufferable only
    0  0  1  0 Cacheable, but do not allocate
    0  0  1  1 Cacheable and Bufferable, but do not allocate
    0  1  1  0 Cacheable write-through, allocate on reads only
    0  1  1  1 Cacheable write-back, allocate on reads only
    1  0  1  0 Cacheable write-through, allocate on write only
    1  0  1  1 Cacheable write-back, allocate on writes only
    1  1  1  0 Cacheable write-through, allocate on both reads and writes
    1  1  1  1 Cacheable write-back, allocate on both reads and writes

    PROR
    [2]:0:Data Access
        1:Instruction Access
    [1]:0:Secure Access
        1:NoSecure Access
    [0]:0:Privileged Access
        1:Normal Access

    RESP
    00: OK
    01: EXOK
    10: SLVERR
    11: DECERR
    */

   localparam S_IDLE   = 2'd0;
   localparam S_WRITE  = 2'd1;
   localparam S_WRITE2 = 2'd2;
   localparam S_READ   = 2'd3;

   reg [1:0]     state;
   reg           reg_rnw;
   reg [15:0]    reg_addr;
   reg [31:0]    reg_wdata;
   reg [3:0]     reg_be;
   reg           reg_wallready;

   always @( posedge ACLK or negedge ARESETN ) begin
      if( !ARESETN ) begin
         state     <= S_IDLE;
         reg_rnw   <= 1'b0;
         reg_addr  <= 16'd0;
         reg_wdata <= 32'd0;
         reg_be    <= 4'd0;
         reg_wallready <= 1'b0;
      end else begin
         if( S_AXI_WVALID ) begin
            reg_wdata <= S_AXI_WDATA;
            reg_be    <= S_AXI_WSTRB;
            reg_wallready <= 1'b1;
         end else if( AQ_LOCAL_ACK & S_AXI_BREADY ) begin
            reg_wallready <= 1'b0;
         end

         case( state )
           S_IDLE: begin
              if( S_AXI_AWVALID ) begin
                 reg_rnw   <= 1'b0;
                 reg_addr  <= S_AXI_AWADDR;
                 state     <= S_WRITE;
              end else if( S_AXI_ARVALID ) begin
                 reg_rnw   <= 1'b1;
                 reg_addr  <= S_AXI_ARADDR;
                 state     <= S_READ;
              end
           end
           S_WRITE: begin
//              if( S_AXI_WVALID ) begin
              if( reg_wallready ) begin
                 state     <= S_WRITE2;
//                 reg_wdata <= S_AXI_WDATA;
//                 reg_be    <= S_AXI_WSTRB;
              end
           end
           S_WRITE2: begin
              if( AQ_LOCAL_ACK & S_AXI_BREADY ) begin
                 state     <= S_IDLE;
              end
           end
           S_READ: begin
              if( AQ_LOCAL_ACK & S_AXI_RREADY ) begin
                 state     <= S_IDLE;
              end
           end
           default: begin
              state        <= S_IDLE;
           end
         endcase
      end
   end

   // Local Interface
   assign AQ_LOCAL_CLK      = ACLK;
   assign AQ_LOCAL_CS       = (( state == S_WRITE2 )?1'b1:1'b0) | (( state == S_READ )?1'b1:1'b0) | 1'b0;
   assign AQ_LOCAL_RNW      = reg_rnw;
   assign AQ_LOCAL_ADDR     = reg_addr;
   assign AQ_LOCAL_BE       = reg_be;
   assign AQ_LOCAL_WDATA    = reg_wdata;

   // Write Channel
   assign S_AXI_AWREADY  = ( state == S_WRITE || state == S_IDLE )?1'b1:1'b0;
   assign S_AXI_WREADY   = ( state == S_WRITE || state == S_IDLE )?1'b1:1'b0;
   assign S_AXI_BVALID   = ( state == S_WRITE2 )?AQ_LOCAL_ACK:1'b0;
   assign S_AXI_BRESP    = 2'b00;

   // Read Channel
   assign S_AXI_ARREADY  = ( state == S_READ  || state == S_IDLE )?1'b1:1'b0;
   assign S_AXI_RVALID   = ( state == S_READ )?AQ_LOCAL_ACK:1'b0;
   assign S_AXI_RRESP    = 2'b00;
   assign S_AXI_RDATA    = ( state == S_READ )?AQ_LOCAL_RDATA:32'd0;

   // Debug
   assign DEBUG[31:0]    = {24'd0, 1'd0, S_AXI_RVALID, S_AXI_ARREADY, AQ_LOCAL_ACK, AQ_LOCAL_RNW, S_AXI_WREADY, S_AXI_WVALID};
endmodule
