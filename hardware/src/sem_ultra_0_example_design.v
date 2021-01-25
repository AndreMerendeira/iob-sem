/////////////////////////////////////////////////////////////////////////////
//
//
//
/////////////////////////////////////////////////////////////////////////////
//   ____  ____
//  /   /\/   /
// /___/  \  /
// \   \   \/    Core:          sem_ultra
//  \   \        Module:        sem_ultra_0_example_design
//  /   /        Filename:      sem_ultra_0_example_design.v
// /___/   /\    Purpose:       Example top level.
// \   \  /  \
//  \___\/\___\
//
/////////////////////////////////////////////////////////////////////////////
//
// (c) Copyright 2014-2017 Xilinx, Inc. All rights reserved.
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
// This module instantiates the system level design example, which includes
// VIO cores as a convenience to demonstrate IP functionality. The VIO may
// be used to drive the IP inputs and monitor the IP outputs. An input clock
// buffer completes the example design.
//
/////////////////////////////////////////////////////////////////////////////
//
// Port Definition:
//
// Name                          Type   Description
// ============================= ====== ====================================
// uart_tx                       output UART status output.  Synchronous
//                                      to icap_clk_out, but received externally
//                                      by another device as an asynchronous
//                                      signal, perceived as lower bitrate.
//                                      Uses 8N1 protocol.
//
// uart_rx                        input UART command input.  Asynchronous
//                                      signal provided by another device at
//                                      a lower bitrate, synchronized to the
//                                      icap_clk and oversampled.  Uses 8N1
//                                      protocol.
//
// clk                           input  System clock; the entire system is
//                                      synchronized to this signal, which
//                                      is distributed on a global clock
//                                      buffer and referred to as icap_clk.
//
/////////////////////////////////////////////////////////////////////////////
//
// Parameter and Localparam Definition:
//
// Name                          Type   Description
// ============================= ====== ====================================
// TCQ                           int    Sets the clock-to-out for behavioral
//                                      descriptions of sequential logic.
//
/////////////////////////////////////////////////////////////////////////////
//
// Module Dependencies:
//
// sem_ultra_0_example_design
// |
// +- sem_ultra_0_support_wrapper  (SEM controller and helper blocks)
// |
// \- IBUF (unisim)
//
/////////////////////////////////////////////////////////////////////////////

`timescale 1 ps / 1 ps

/////////////////////////////////////////////////////////////////////////////
// Module
/////////////////////////////////////////////////////////////////////////////

module sem_ultra_0_example_design (
  input  wire        clk,


  output wire        uart_tx,
  input  wire        uart_rx
  );

  ///////////////////////////////////////////////////////////////////////////
  // Define local constants.
  ///////////////////////////////////////////////////////////////////////////

  localparam TCQ = 1;
  localparam COUNT_1SEC   = 100000000;
  localparam HB_COUNTER_WIDTH = LOGBASE2(COUNT_1SEC); 

  ///////////////////////////////////////////////////////////////////////////
  // Define local function.
  ///////////////////////////////////////////////////////////////////////////

  function integer LOGBASE2;
    input [31:0] val;
    integer width;
  begin
    width = val;
    for (LOGBASE2 = 0; width > 0; LOGBASE2 = LOGBASE2 + 1)
      width = width >> 1;
  end
  endfunction

  ///////////////////////////////////////////////////////////////////////////
  // Internal signals.
  ///////////////////////////////////////////////////////////////////////////

  wire        clk_ibufg;
  wire        icap_clk;


  wire        status_heartbeat;
  wire        status_initialization;
  wire        status_observation;
  wire        status_correction;
  wire        status_classification;
  wire        status_injection;
  wire        status_diagnostic_scan;
  wire        status_detect_only;
  wire        status_essential;
  wire        status_uncorrectable;

  //Status error signals
  wire heartbeat_valid;
  reg  [HB_COUNTER_WIDTH-1:0] heartbeat_cnt; 
  reg heartbeat_timeout;
  reg heartbeat_timeout_sticky;

  wire [3:0] status_sig; 
  reg status_irregular_sticky;
  reg status_halt;

  ///////////////////////////////////////////////////////////////////////////
  // Instantiate the input buffer for the clock
  ///////////////////////////////////////////////////////////////////////////
  IBUF example_ibuf (
    .I(clk),
    .O(clk_ibufg));

  ///////////////////////////////////////////////////////////////////////////
  // Instantiate the support wrapper layer, which includes the SEM 
  // controller, configuration primitives, and the IP helper blocks
  ///////////////////////////////////////////////////////////////////////////

  sem_ultra_0_support_wrapper example_support_wrapper (
    .clk (clk_ibufg),
    .status_heartbeat(status_heartbeat),
    .status_initialization(status_initialization),
    .status_observation(status_observation),
    .status_correction(status_correction),
    .status_classification(status_classification),
    .status_injection(status_injection),
    .status_diagnostic_scan(status_diagnostic_scan),
    .status_detect_only(status_detect_only), 
    .status_essential(status_essential),
    .status_uncorrectable(status_uncorrectable),
    .uart_tx(uart_tx),
    .uart_rx(uart_rx),
    .command_strobe(0),
    .command_busy(),
    .command_code(0),
    .icap_clk_out(icap_clk),
    .cap_rel(0),
    .cap_gnt(1),
    .cap_req(),
    .aux_error_cr_ne(0),
    .aux_error_cr_es(0),
    .aux_error_uc(0)
    );

  ///////////////////////////////////////////////////////////////////////////
  // Heartbeat watchdog logic
  // Expects heartbeat toggles once every 1 second in the following states:
  // observation, detect only and diagnostic scan
  //////////////////////////////////////////////////////////////////////////
  assign heartbeat_valid  = (status_observation || status_diagnostic_scan || status_detect_only);

  always@(posedge icap_clk)
  begin
    if (heartbeat_valid == 1'b0)
      heartbeat_cnt <= 'd0;
    else
    begin
      if (status_heartbeat == 1'b1)
        heartbeat_cnt <= 'd0;
      else        
        heartbeat_cnt <= heartbeat_cnt + 1;
    end

    if (heartbeat_cnt > COUNT_1SEC)
    begin
      heartbeat_timeout <= 1'b1;
      heartbeat_timeout_sticky <= 1'b1 | heartbeat_timeout_sticky;
    end
    else
      heartbeat_timeout <= 1'b0;
      
  end 

  ///////////////////////////////////////////////////////////////////////////
  // Verify other behaviors of the status signals that indicate the
  // current controller state.
  // status_irregular_sticky - sticky signal that asserts if more than
  //                           one status signal is asserted in the  
  //                           same clock cycle
  // status_halt             - asserts when IP is halted (all status
  //                           signals are asserted)
  //////////////////////////////////////////////////////////////////////////
  assign status_sig = status_observation + status_diagnostic_scan + status_detect_only + status_initialization + status_correction + status_classification + status_injection;

  always@(posedge icap_clk)
  begin

    // Make status_irregular sticky
    if (status_sig > 1)
      status_irregular_sticky <= 1'b1 | status_irregular_sticky;

    status_halt <= (status_observation && status_diagnostic_scan && status_detect_only && status_initialization && status_correction && status_classification && status_injection);

  end  

endmodule

/////////////////////////////////////////////////////////////////////////////
//
/////////////////////////////////////////////////////////////////////////////
