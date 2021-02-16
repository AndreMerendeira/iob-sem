/////////////////////////////////////////////////////////////////////////////
//
//
//
/////////////////////////////////////////////////////////////////////////////
//   ____  ____
//  /   /\/   /
// /___/  \  /
// \   \   \/    Core:          sem_ultra
//  \   \        Module:        sem_ultra_0_spi_byte
//  /   /        Filename:      sem_ultra_0_spi_byte.v
// /___/   /\    Purpose:       SPI-flash master byte transfer FSM.
// \   \  /  \
//  \___\/\___\
//
/////////////////////////////////////////////////////////////////////////////
//
// (c) Copyright 2014-2020 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
/////////////////////////////////////////////////////////////////////////////
//
// Module Description:
//
// This module is a byte transfer state machine used by the SPI-flash master
// helper block main state machine to move bytes on the SPI bus.  The SPI bus
// is byte oriented so this state machine is activated multiple times in
// succession to create a longer transaction.
//
/////////////////////////////////////////////////////////////////////////////
//
// Port Definition:
//
// Name                          Type   Description
// ============================= ====== ====================================
// icap_clk                      input  The system clock signal.
//
// reset                         input  Reset signal to put the byte fsm
//                                      back into idle.  Synchronous to
//                                      icap_clk.
//
// tx[7:0]                       input  Transmit byte data.  Synchronous
//                                      to icap_clk.
//
// sta                           input  State machine start signal.  This
//                                      is only observed when the state
//                                      machine is in idle or at the end
//                                      of a byte, deciding to return to
//                                      idle.  At other times, it is not
//                                      observed.  Synchronous to icap_clk.
//
// rx[7:0]                       output Receive byte data.  Synchronous
//                                      to icap_clk.
//
// rxv                           output Receive byte valid strobe to qualify
//                                      rx output.  As rx output is from a
//                                      shift register, it must be captured
//                                      when valid otherwise it is lost.
//                                      Synchronous to icap_clk.
//
// stp_a1                        output Byte transfer complete indication
//                                      advanced by one clock cycle.
//                                      Synchronous to icap_clk.
//
// spi_c                         output SPI bus clock.  When running, this
//                                      clock is locked in frequency to one
//                                      half the icap_clk frequency.  This
//                                      signal is synchronous to icap_clk.
//
// spi_d                         output SPI bus data, master to slave.
//                                      Synchronous to icap_clk.
//
// spi_q                          input  SPI bus data, slave to master.
//                                      Synchronous to icap_clk.
//
/////////////////////////////////////////////////////////////////////////////
//
// Module Dependencies:
//
// sem_ultra_0_spi_byte
// |
// +- FDRE (unisim)
// |
// \- FDR (unisim)
//
/////////////////////////////////////////////////////////////////////////////

`timescale 1 ps / 1 ps

/////////////////////////////////////////////////////////////////////////////
// Module
/////////////////////////////////////////////////////////////////////////////

module sem_ultra_0_spi_byte (
  input  wire        icap_clk,
  input  wire        reset,
  input  wire  [7:0] tx,
  input  wire        sta,
  output wire  [7:0] rx,
  output wire        rxv,
  output wire        stp_a1,
  output wire        spi_d,
  output wire        spi_c,
  input  wire        spi_q
  );

  ///////////////////////////////////////////////////////////////////////////
  // Define local constants.
  ///////////////////////////////////////////////////////////////////////////

  localparam TCQ = 1;

  // Byte transfer FSM state names.
  // The bit assignments are:
  //
  // state[4] = active flag
  // state[3:1] = bit index
  // state[0] = bus clock value
  //
  // The state progression is generally by
  // increment except where exiting or
  // entering the idle state.

  localparam [4:0] S_RST_CL = 5'b0_0000;
  localparam [4:0] S_TX7_CL = 5'b1_0000;
  localparam [4:0] S_TX7_CH = 5'b1_0001;
  localparam [4:0] S_TX6_CL = 5'b1_0010;
  localparam [4:0] S_TX6_CH = 5'b1_0011;
  localparam [4:0] S_TX5_CL = 5'b1_0100;
  localparam [4:0] S_TX5_CH = 5'b1_0101;
  localparam [4:0] S_TX4_CL = 5'b1_0110;
  localparam [4:0] S_TX4_CH = 5'b1_0111;
  localparam [4:0] S_TX3_CL = 5'b1_1000;
  localparam [4:0] S_TX3_CH = 5'b1_1001;
  localparam [4:0] S_TX2_CL = 5'b1_1010;
  localparam [4:0] S_TX2_CH = 5'b1_1011;
  localparam [4:0] S_TX1_CL = 5'b1_1100;
  localparam [4:0] S_TX1_CH = 5'b1_1101;
  localparam [4:0] S_TX0_CL = 5'b1_1110;
  localparam [4:0] S_TX0_CH = 5'b1_1111;

  ///////////////////////////////////////////////////////////////////////////
  // Declare signals.
  ///////////////////////////////////////////////////////////////////////////

  (* dont_touch = "true" *) reg   [4:0] state = S_RST_CL;
  (* dont_touch = "true" *) reg   [4:0] next_state;
  reg   [7:1] q_del = 7'b0000000;
  reg         q_vld = 1'b0;
  wire        stp_a0;
  wire        q_ifd_int;
  wire  [2:0] bitsel;
  wire        ns_c_ofd;
  wire        ns_d_ofd;
  wire        ce_q_ifd;

  ///////////////////////////////////////////////////////////////////////////
  // Implement the byte transfer FSM sequential logic.
  ///////////////////////////////////////////////////////////////////////////

  always @(posedge icap_clk)
  begin
    if (reset)
      state <= #TCQ S_RST_CL;
    else
      state <= #TCQ next_state;
  end

  ///////////////////////////////////////////////////////////////////////////
  // Implement the byte transfer FSM combinational (next state) logic.  This
  // FSM is binary counter-based with each bit assigned a specific function.
  // Consult the product guide for additional information about this FSM.
  ///////////////////////////////////////////////////////////////////////////

  always @*
  begin
    case (state)
      S_RST_CL: begin
                  // look at start signal to
                  // determine if we exit idle
                  if (sta)
                    next_state = S_TX7_CL;
                  else
                    next_state = S_RST_CL;
                end
      S_TX7_CL: next_state = S_TX7_CH;
      S_TX7_CH: next_state = S_TX6_CL;
      S_TX6_CL: next_state = S_TX6_CH;
      S_TX6_CH: next_state = S_TX5_CL;
      S_TX5_CL: next_state = S_TX5_CH;
      S_TX5_CH: next_state = S_TX4_CL;
      S_TX4_CL: next_state = S_TX4_CH;
      S_TX4_CH: next_state = S_TX3_CL;
      S_TX3_CL: next_state = S_TX3_CH;
      S_TX3_CH: next_state = S_TX2_CL;
      S_TX2_CL: next_state = S_TX2_CH;
      S_TX2_CH: next_state = S_TX1_CL;
      S_TX1_CL: next_state = S_TX1_CH;
      S_TX1_CH: next_state = S_TX0_CL;
      S_TX0_CL: next_state = S_TX0_CH;
      S_TX0_CH: begin
                  // look at start signal to
                  // determine if we loop or
                  // go back to idle
                  if (sta)
                    next_state = S_TX7_CL;
                  else
                    next_state = S_RST_CL;
                end
      default:  next_state = 5'bxxxxx;
    endcase
  end

  ///////////////////////////////////////////////////////////////////////////
  // Decode advanced notice of end condition and create data valid strobe.
  ///////////////////////////////////////////////////////////////////////////

  // stop condition, advanced 0 cycles
  assign stp_a0 = (state == S_TX0_CH);

  // stop condition, advanced 1 cycle
  assign stp_a1 = (state == S_TX0_CL);

  // data is valid at end of byte
  // transfer sequence, as marked
  // by a delayed stp_a0 signal

  always @(posedge icap_clk)
  begin
    if (reset)
      q_vld <= #TCQ 1'b0;
    else
      q_vld <= #TCQ stp_a0;
  end

  assign rxv = q_vld;

  ///////////////////////////////////////////////////////////////////////////
  // Implement receive shift register; the first bit is located in I/O with
  // the rest of the bits in regular flip flops.  The shift register is
  // enabled every other cycle (when active) based on state[0] which is
  // a mirror of what is on the bus clock signal externally.
  ///////////////////////////////////////////////////////////////////////////

  always @(posedge icap_clk)
  begin
    if (reset)
      q_del <= #TCQ 7'b0000000;
    else if (state[0])
      q_del <= #TCQ {q_del[6:1], q_ifd_int};
  end

  assign rx = {q_del, q_ifd_int};

  ///////////////////////////////////////////////////////////////////////////
  // Implement flip flops intended for packing in I/O.
  ///////////////////////////////////////////////////////////////////////////

  // mux select signal to get
  // msb of byte transmit first

  assign bitsel = ~next_state[3:1];

  assign ns_c_ofd = next_state[0];
  assign ce_q_ifd = state[0];

  // 8:1 mux with enable to
  // select transmit data

  assign ns_d_ofd = next_state[4] ? tx[bitsel] : 1'b0;

  FDR spi_d_ofd (
    .Q(spi_d),
    .D(ns_d_ofd),
    .R(reset),
    .C(icap_clk));

  FDR spi_c_ofd (
    .Q(spi_c),
    .D(ns_c_ofd),
    .R(reset),
    .C(icap_clk));

  FDRE spi_q_ifd (
    .Q(q_ifd_int),
    .D(spi_q),
    .R(reset),
    .CE(ce_q_ifd),
    .C(icap_clk));

  ///////////////////////////////////////////////////////////////////////////
  //
  ///////////////////////////////////////////////////////////////////////////

endmodule

/////////////////////////////////////////////////////////////////////////////
//
/////////////////////////////////////////////////////////////////////////////
