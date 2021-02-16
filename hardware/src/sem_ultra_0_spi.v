/////////////////////////////////////////////////////////////////////////////
//
//
//
/////////////////////////////////////////////////////////////////////////////
//   ____  ____
//  /   /\/   /
// /___/  \  /
// \   \   \/    Core:          sem_ultra
//  \   \        Module:        sem_ultra_0_spi
//  /   /        Filename:      sem_ultra_0_spi.v
// /___/   /\    Purpose:       SPI-flash master helper block.
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
// This module is a SPI-flash master implementation for data retrieval
// from external SPI Flash.  When external storage is required, the controller
// accesses the external storage through the SPI-flash master helper block.
// This helper block may be replaced with a custom user-supplied design to
// enable data retrieval from other sources.
//
/////////////////////////////////////////////////////////////////////////////
//
// Port Definition:
//
// Name                          Type   Description
// ============================= ====== ====================================
// icap_clk                      input  The system clock signal.
//
// spi_c                         output SPI bus clock.  When running, this
//                                      clock is locked in frequency to one
//                                      half the icap_clk frequency.  This
//                                      signal is synchronous to icap_clk.
//
// spi_d                         output SPI bus data, master to slave.
//                                      Synchronous to icap_clk.
//
// spi_s_n                       output SPI bus slave select.  Synchronous
//                                      to icap_clk.
//
// spi_q                         input  SPI bus data, slave to master.
//                                      Synchronous to icap_clk.
//
// fetch_txdata[7:0]             input  Output data from controller,
//                                      qualified by fetch_txwrite.
//                                      Synchronous to icap_clk.
//
// fetch_txwrite                 input  Write strobe, used by peripheral
//                                      to capture data.  Synchronous to
//                                      icap_clk.
//
// fetch_txfull                  output Flow control signal indicating the
//                                      peripheral is not ready to receive
//                                      additional data writes.  Synchronous
//                                      to icap_clk.
//
// fetch_rxdata[7:0]             output Input data to controller qualified by
//                                      fetch_rxread. Synchronous to icap_clk.
//
// fetch_rxread                  input  Read strobe, used by peripheral
//                                      to change state.  Synchronous to
//                                      icap_clk.
//
// fetch_rxempty                 output Flow control signal indicating the
//                                      peripheral is not ready to service
//                                      additional data reads.  Synchronous
//                                      to icap_clk.
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
// B_ISSUE_WREN                  int    Indicates if a write enable command
//                                      must be issued prior to issue of any
//                                      other commands that modify the device
//                                      behavior.
//
// B_ISSUE_WVCR                  int    Indicates if a write volatile config
//                                      register command must be issued to
//                                      explicitly set the fast read dummy
//                                      byte count to one.
//
// B_ISSUE_EN4B                  int    Indicates if an enable four-byte
//                                      addressing command must be issued to
//                                      explicitly set the addressing mode.
//
/////////////////////////////////////////////////////////////////////////////
//
// Module Dependencies:
//
// sem_ultra_0_spi
// |
// +- sem_ultra_0_spi_byte
// |
// +- FDS (unisim)
// |
// \- FD (unisim)
//
//
/////////////////////////////////////////////////////////////////////////////

`timescale 1 ps / 1 ps

/////////////////////////////////////////////////////////////////////////////
// Module
/////////////////////////////////////////////////////////////////////////////

module sem_ultra_0_spi (
  input  wire        icap_clk,
  output wire        spi_c,
  output wire        spi_d,
  output wire        spi_s_n,
  input  wire        spi_q,
  input  wire  [7:0] fetch_txdata,
  input  wire        fetch_txwrite,
  output wire        fetch_txfull,
  output wire  [7:0] fetch_rxdata,
  input  wire        fetch_rxread,
  output wire        fetch_rxempty
  );

  ///////////////////////////////////////////////////////////////////////////
  // Define local constants.
  ///////////////////////////////////////////////////////////////////////////

  localparam TCQ = 1;

  localparam B_ISSUE_WREN = 1;
  localparam B_ISSUE_WVCR = 1;
  localparam B_ISSUE_EN4B = 1;

  localparam [7:0] V_CMD_WREN = 8'h06;
  localparam [7:0] V_CMD_WVCR = 8'h81;
  localparam [7:0] V_DAT_WVCR = 8'h8b;
  localparam [7:0] V_CMD_EN4B = 8'hb7;
  localparam [7:0] V_CMD_FAST = 8'h0b;

  // Main transfer FSM state names.
  // The FSM commenting describes each state.

  localparam [4:0] S_ARBIDL = 5'b00000;
  localparam [4:0] S_MOVEW1 = 5'b00001;
  localparam [4:0] S_PADSW1 = 5'b00010;
  localparam [4:0] S_MOVEWV = 5'b00011;
  localparam [4:0] S_MOVECR = 5'b00100;
  localparam [4:0] S_PADSCR = 5'b00101;
  localparam [4:0] S_MOVEW2 = 5'b00110;
  localparam [4:0] S_PADSW2 = 5'b00111;
  localparam [4:0] S_MOVEEN = 5'b01000;
  localparam [4:0] S_PADSEN = 5'b01001;
  localparam [4:0] S_MOVEFR = 5'b01010;
  localparam [4:0] S_MOVEA3 = 5'b01011;
  localparam [4:0] S_WAITA2 = 5'b01100;
  localparam [4:0] S_MOVEA2 = 5'b01101;
  localparam [4:0] S_WAITA1 = 5'b01110;
  localparam [4:0] S_MOVEA1 = 5'b01111;
  localparam [4:0] S_WAITA0 = 5'b10000;
  localparam [4:0] S_MOVEA0 = 5'b10001;
  localparam [4:0] S_WAITL1 = 5'b10010;
  localparam [4:0] S_MOVEDM = 5'b10011;
  localparam [4:0] S_WAITL0 = 5'b10100;
  localparam [4:0] S_MOVERX = 5'b10101;
  localparam [4:0] S_PICKUP = 5'b10110;

  ///////////////////////////////////////////////////////////////////////////
  // Declare signals.
  ///////////////////////////////////////////////////////////////////////////

  wire        use_wren;
  wire        use_wvcr;
  wire        use_en4b;

  wire  [7:0] rx;
  reg   [7:0] tx;
  wire        rxv;
  wire        stp_a1;
  reg         rxvd = 1'b0;

  (* dont_touch = "true" *) reg   [4:0] state = S_ARBIDL;
  (* dont_touch = "true" *) reg   [4:0] ns_state;

  reg   [8:0] dat_len = 9'b000000000;
  reg         start = 1'b0;
  reg         sel_n = 1'b1;

  reg   [8:0] ns_dat_len;
  reg         ns_start;
  reg         ns_sel_n;

  reg         ns_txprocessed;
  reg         ns_rxprocessed;

  wire        reset;

  reg   [7:0] rx_mbox_src_data = 8'h00;
  reg   [7:0] rx_mbox_dst_data = 8'h00;
  reg         rx_mbox_src_write = 1'b0;
  reg         rx_mbox_dst_full = 1'b0;
  reg         rx_mbox_dst_read = 1'b0;
  reg         rx_mbox_src_read = 1'b0;
  reg         rx_mbox_dst_irq = 1'b0;
  reg         rx_mbox_src_irq = 1'b0;

  reg   [7:0] tx_mbox_src_data = 8'h00;
  reg   [7:0] tx_mbox_dst_data = 8'h00;
  reg         tx_mbox_src_write = 1'b0;
  reg         tx_mbox_dst_full = 1'b0;
  reg         tx_mbox_dst_read = 1'b0;
  reg         tx_mbox_src_full = 1'b0;

  ///////////////////////////////////////////////////////////////////////////
  // Parameter decode.
  ///////////////////////////////////////////////////////////////////////////

  assign use_wren = (B_ISSUE_WREN != 0);
  assign use_wvcr = (B_ISSUE_WVCR != 0);
  assign use_en4b = (B_ISSUE_EN4B != 0);

  ///////////////////////////////////////////////////////////////////////////
  // RX mailbox.
  ///////////////////////////////////////////////////////////////////////////

  always @(posedge icap_clk)
  begin
    rx_mbox_dst_irq <= #TCQ (fetch_rxread && !rx_mbox_dst_full);
    rx_mbox_src_irq <= #TCQ rx_mbox_dst_irq;
    if (reset)
    begin
      rx_mbox_src_data <= #TCQ 8'h00;
      rx_mbox_dst_data <= #TCQ 8'h00;
      rx_mbox_src_write <= #TCQ 1'b0;
      rx_mbox_dst_full <= #TCQ 1'b0;
      rx_mbox_dst_read <= #TCQ 1'b0;
      rx_mbox_src_read <= #TCQ 1'b0;
    end
    else
    begin
      rx_mbox_src_data <= #TCQ rx;
      rx_mbox_src_write <= #TCQ ns_rxprocessed;
      if (rx_mbox_src_write)
      begin
        rx_mbox_dst_data <= #TCQ rx_mbox_src_data;
        rx_mbox_dst_full <= #TCQ 1'b1;
      end
      else if (fetch_rxread)
      begin
        rx_mbox_dst_full <= #TCQ 1'b0;
      end
      rx_mbox_dst_read <= #TCQ fetch_rxread;
      rx_mbox_src_read <= #TCQ rx_mbox_dst_read;
    end
  end

  assign fetch_rxdata = rx_mbox_dst_data;
  assign fetch_rxempty = !rx_mbox_dst_full;

  ///////////////////////////////////////////////////////////////////////////
  // TX mailbox.
  ///////////////////////////////////////////////////////////////////////////

  always @(posedge icap_clk)
  begin
    if (reset)
    begin
      tx_mbox_src_data <= #TCQ 8'h00;
      tx_mbox_dst_data <= #TCQ 8'h00;
      tx_mbox_src_write <= #TCQ 1'b0;
      tx_mbox_dst_full <= #TCQ 1'b0;
      tx_mbox_dst_read <= #TCQ 1'b0;
      tx_mbox_src_full <= #TCQ 1'b0;
    end
    else
    begin
      tx_mbox_src_data <= #TCQ fetch_txdata;
      tx_mbox_src_write <= #TCQ fetch_txwrite;
      if (tx_mbox_src_write)
      begin
        tx_mbox_dst_data <= #TCQ tx_mbox_src_data;
        tx_mbox_dst_full <= #TCQ 1'b1;
      end
      else if (ns_txprocessed)
      begin
        tx_mbox_dst_full <= #TCQ 1'b0;
      end
      tx_mbox_dst_read <= #TCQ ns_txprocessed;
      if (fetch_txwrite)
      begin
        tx_mbox_src_full <= #TCQ 1'b1;
      end
      else if (tx_mbox_dst_read)
      begin
        tx_mbox_src_full <= #TCQ 1'b0;
      end
    end
  end

  assign fetch_txfull = tx_mbox_src_full;

  ///////////////////////////////////////////////////////////////////////////
  // Implement the main transfer FSM sequential logic.
  ///////////////////////////////////////////////////////////////////////////

  always @(posedge icap_clk)
  begin
    if (reset)
    begin
      state <= #TCQ S_ARBIDL;
      dat_len <= #TCQ 9'b000000000;
      start <= #TCQ 1'b0;
      sel_n <= #TCQ 1'b1;
    end
    else
    begin
      state <= #TCQ ns_state;
      dat_len <= #TCQ ns_dat_len;
      start <= #TCQ ns_start;
      sel_n <= #TCQ ns_sel_n;
    end
  end

  ///////////////////////////////////////////////////////////////////////////
  // Implement the main transfer FSM combinational (next state/output) logic.
  // Consult the product guide for additional information about this FSM.
  ///////////////////////////////////////////////////////////////////////////

  always @*
  begin
    case (state)
      S_ARBIDL: begin
                  // stay idle until a request arrives; if
                  // a request arrives, begin a transfer
                  if (tx_mbox_dst_full)
                  begin
                    // begin transfer
                    if (use_wren)
                    begin
                      if (use_wvcr)
                        ns_state = S_MOVEW1;
                      else if (use_en4b)
                        ns_state = S_MOVEW2;
                      else
                        ns_state = S_MOVEFR;
                    end
                    else
                    begin
                      if (use_wvcr)
                        ns_state = S_MOVEWV;
                      else if (use_en4b)
                        ns_state = S_MOVEEN;
                      else
                        ns_state = S_MOVEFR;
                    end
                  end
                  else
                  begin
                    // stay idle
                    ns_state = S_ARBIDL;
                  end
                  // preserve current dat_len contents
                  ns_dat_len = dat_len;
                  // do not start any spi transfer
                  ns_start = 1'b0;
                  // tell external device it is deselected
                  ns_sel_n = 1'b1;
                  // do not set rx flag register
                  ns_rxprocessed = 1'b0;
                  // do not clear tx flag register
                  ns_txprocessed = 1'b0;
                end
      S_MOVEW1: begin
                  // move write enable command state
                  // dwell until complete
                  ns_state = stp_a1 ? S_PADSW1 : S_MOVEW1;
                  // set dat_len for pad state cycle count
                  ns_dat_len = 9'b000010001;
                  // keep transfer running until complete
                  ns_start = stp_a1 ? 1'b0 : 1'b1;
                  // tell external device it is selected
                  ns_sel_n = 1'b0;
                  // do not set rx flag register
                  ns_rxprocessed = 1'b0;
                  // do not clear tx flag register
                  ns_txprocessed = 1'b0;
                end
      S_PADSW1: begin
                  // this state ensures select signal
                  // deasserts after previous command
                  // for adequate number of cycles
                  if (dat_len == 9'b000000000)
                  begin
                    ns_state = S_MOVEWV;
                  end
                  else
                  begin
                    ns_state = S_PADSW1;
                  end
                  // decrement current dat_len contents
                  ns_dat_len = dat_len - 9'b000000001;
                  // do not start any spi transfer
                  ns_start = 1'b0;
                  // tell external device it is deselected
                  ns_sel_n = !dat_len[4];
                  // do not set rx flag register
                  ns_rxprocessed = 1'b0;
                  // do not clear tx flag register
                  ns_txprocessed = 1'b0;
                end
      S_MOVEWV: begin
                  // move write volatile command state
                  // dwell until complete
                  ns_state = stp_a1 ? S_MOVECR : S_MOVEWV;
                  // set dat_len for pad state cycle count
                  ns_dat_len = 9'b000010001;
                  // keep transfer running until complete
                  ns_start = stp_a1 ? 1'b0 : 1'b1;
                  // tell external device it is selected
                  ns_sel_n = 1'b0;
                  // do not set rx flag register
                  ns_rxprocessed = 1'b0;
                  // do not clear tx flag register
                  ns_txprocessed = 1'b0;
                end
      S_MOVECR: begin
                  // move write volatile data state
                  // dwell until complete
                  ns_state = stp_a1 ? S_PADSCR : S_MOVECR;
                  // set dat_len for pad state cycle count
                  ns_dat_len = 9'b000010001;
                  // keep transfer running until complete
                  ns_start = stp_a1 ? 1'b0 : 1'b1;
                  // tell external device it is selected
                  ns_sel_n = 1'b0;
                  // do not set rx flag register
                  ns_rxprocessed = 1'b0;
                  // do not clear tx flag register
                  ns_txprocessed = 1'b0;
                end
      S_PADSCR: begin
                  // this state ensures select signal
                  // deasserts after previous command
                  // for adequate number of cycles
                  if (dat_len == 9'b000000000)
                  begin
                    if (use_wren)
                    begin
                      if (use_en4b)
                        ns_state = S_MOVEW2;
                      else
                        ns_state = S_MOVEFR;
                    end
                    else
                    begin
                      if (use_en4b)
                        ns_state = S_MOVEEN;
                      else
                        ns_state = S_MOVEFR;
                    end
                  end
                  else
                  begin
                    ns_state = S_PADSCR;
                  end
                  // decrement current dat_len contents
                  ns_dat_len = dat_len - 9'b000000001;
                  // do not start any spi transfer
                  ns_start = 1'b0;
                  // tell external device it is deselected
                  ns_sel_n = !dat_len[4];
                  // do not set rx flag register
                  ns_rxprocessed = 1'b0;
                  // do not clear tx flag register
                  ns_txprocessed = 1'b0;
                end
      S_MOVEW2: begin
                  // move write enable command state
                  // dwell until complete
                  ns_state = stp_a1 ? S_PADSW2 : S_MOVEW2;
                  // set dat_len for pad state cycle count
                  ns_dat_len = 9'b000010001;
                  // keep transfer running until complete
                  ns_start = stp_a1 ? 1'b0 : 1'b1;
                  // tell external device it is selected
                  ns_sel_n = 1'b0;
                  // do not set rx flag register
                  ns_rxprocessed = 1'b0;
                  // do not clear tx flag register
                  ns_txprocessed = 1'b0;
                end
      S_PADSW2: begin
                  // this state ensures select signal
                  // deasserts after previous command
                  // for adequate number of cycles
                  if (dat_len == 9'b000000000)
                  begin
                    ns_state = S_MOVEEN;
                  end
                  else
                  begin
                    ns_state = S_PADSW2;
                  end
                  // decrement current dat_len contents
                  ns_dat_len = dat_len - 9'b000000001;
                  // do not start any spi transfer
                  ns_start = 1'b0;
                  // tell external device it is deselected
                  ns_sel_n = !dat_len[4];
                  // do not set rx flag register
                  ns_rxprocessed = 1'b0;
                  // do not clear tx flag register
                  ns_txprocessed = 1'b0;
                end
      S_MOVEEN: begin
                  // move enable four-byte command state
                  // dwell until complete
                  ns_state = stp_a1 ? S_PADSEN : S_MOVEEN;
                  // set dat_len for pad state cycle count
                  ns_dat_len = 9'b000010001;
                  // keep transfer running until complete
                  ns_start = stp_a1 ? 1'b0 : 1'b1;
                  // tell external device it is selected
                  ns_sel_n = 1'b0;
                  // do not set rx flag register
                  ns_rxprocessed = 1'b0;
                  // do not clear tx flag register
                  ns_txprocessed = 1'b0;
                end
      S_PADSEN: begin
                  // this state ensures select signal
                  // deasserts after previous command
                  // for adequate number of cycles
                  if (dat_len == 9'b000000000)
                  begin
                    ns_state = S_MOVEFR;
                  end
                  else
                  begin
                    ns_state = S_PADSEN;
                  end
                  // decrement current dat_len contents
                  ns_dat_len = dat_len - 9'b000000001;
                  // do not start any spi transfer
                  ns_start = 1'b0;
                  // tell external device it is deselected
                  ns_sel_n = !dat_len[4];
                  // do not set rx flag register
                  ns_rxprocessed = 1'b0;
                  // do not clear tx flag register
                  ns_txprocessed = 1'b0;
                end
      S_MOVEFR: begin
                  // move fast read command state
                  // dwell until complete
                  if (use_en4b)
                    ns_state = stp_a1 ? S_MOVEA3 : S_MOVEFR;
                  else
                    ns_state = stp_a1 ? S_WAITA2 : S_MOVEFR;
                  // load dat_len from requesting buffer
                  ns_dat_len = {1'b0, tx_mbox_dst_data};
                  // keep transfer running until complete
                  ns_start = stp_a1 ? 1'b0 : 1'b1;
                  // tell external device it is selected
                  ns_sel_n = 1'b0;
                  // do not set rx flag register
                  ns_rxprocessed = 1'b0;
                  // clear tx flag register
                  ns_txprocessed = stp_a1;
                end
      S_MOVEA3: begin
                  // start a transmit of address byte 3
                  // dwell until complete
                  ns_state = stp_a1 ? S_WAITA2 : S_MOVEA3;
                  // preserve current dat_len contents
                  ns_dat_len = dat_len;
                  // keep transfer running until complete
                  ns_start = stp_a1 ? 1'b0 : 1'b1;
                  // tell external device it is selected
                  ns_sel_n = 1'b0;
                  // do not set rx flag register
                  ns_rxprocessed = 1'b0;
                  // do not clear tx flag register
                  ns_txprocessed = 1'b0;
                end
      S_WAITA2: begin
                  // wait for address byte 2 arrives
                  // dwell until complete
                  ns_state = tx_mbox_dst_full ? S_MOVEA2 : S_WAITA2;
                  // load dat_len from requesting buffer
                  ns_dat_len = {1'b0, tx_mbox_dst_data};
                  // do not start any spi transfer
                  ns_start = 1'b0;
                  // tell external device it is selected
                  ns_sel_n = 1'b0;
                  // do not set rx flag register
                  ns_rxprocessed = 1'b0;
                  // clear tx flag register
                  ns_txprocessed = tx_mbox_dst_full;
                end
      S_MOVEA2: begin
                  // start a transmit of address byte 2
                  // dwell until complete
                  ns_state = stp_a1 ? S_WAITA1 : S_MOVEA2;
                  // preserve current dat_len contents
                  ns_dat_len = dat_len;
                  // keep transfer running until complete
                  ns_start = stp_a1 ? 1'b0 : 1'b1;
                  // tell external device it is selected
                  ns_sel_n = 1'b0;
                  // do not set rx flag register
                  ns_rxprocessed = 1'b0;
                  // do not clear tx flag register
                  ns_txprocessed = 1'b0;
                end
      S_WAITA1: begin
                  // wait for address byte 1 arrives
                  // dwell until complete
                  ns_state = tx_mbox_dst_full ? S_MOVEA1 : S_WAITA1;
                  // load dat_len from requesting buffer
                  ns_dat_len = {1'b0, tx_mbox_dst_data};
                  // do not start any spi transfer
                  ns_start = 1'b0;
                  // tell external device it is selected
                  ns_sel_n = 1'b0;
                  // do not set rx flag register
                  ns_rxprocessed = 1'b0;
                  // clear tx flag register
                  ns_txprocessed = tx_mbox_dst_full;
                end
      S_MOVEA1: begin
                  // start a transmit of address byte 1
                  // dwell until complete
                  ns_state = stp_a1 ? S_WAITA0 : S_MOVEA1;
                  // preserve current dat_len contents
                  ns_dat_len = dat_len;
                  // keep transfer running until complete
                  ns_start = stp_a1 ? 1'b0 : 1'b1;
                  // tell external device it is selected
                  ns_sel_n = 1'b0;
                  // do not set rx flag register
                  ns_rxprocessed = 1'b0;
                  // do not clear tx flag register
                  ns_txprocessed = 1'b0;
                end
      S_WAITA0: begin
                  // wait for address byte 0 arrives
                  // dwell until complete
                  ns_state = tx_mbox_dst_full ? S_MOVEA0 : S_WAITA0;
                  // load dat_len from requesting buffer
                  ns_dat_len = {1'b0, tx_mbox_dst_data};
                  // do not start any spi transfer
                  ns_start = 1'b0;
                  // tell external device it is selected
                  ns_sel_n = 1'b0;
                  // do not set rx flag register
                  ns_rxprocessed = 1'b0;
                  // clear tx flag register
                  ns_txprocessed = tx_mbox_dst_full;
                end
      S_MOVEA0: begin
                  // start a transmit of address byte 0
                  // dwell until complete
                  ns_state = stp_a1 ? S_WAITL1 : S_MOVEA0;
                  // preserve current dat_len contents
                  ns_dat_len = dat_len;
                  // keep transfer running until complete
                  ns_start = stp_a1 ? 1'b0 : 1'b1;
                  // tell external device it is selected
                  ns_sel_n = 1'b0;
                  // do not set rx flag register
                  ns_rxprocessed = 1'b0;
                  // do not clear tx flag register
                  ns_txprocessed = 1'b0;
                end
      S_WAITL1: begin
                  // wait for length byte 1 arrives
                  // dwell until complete
                  ns_state = tx_mbox_dst_full ? S_MOVEDM : S_WAITL1;
                  // load dat_len from requesting buffer
                  ns_dat_len = {tx_mbox_dst_data[0], dat_len[7:0]};
                  // do not start any spi transfer
                  ns_start = 1'b0;
                  // tell external device it is selected
                  ns_sel_n = 1'b0;
                  // do not set rx flag register
                  ns_rxprocessed = 1'b0;
                  // clear tx flag register
                  ns_txprocessed = tx_mbox_dst_full;
                end
      S_MOVEDM: begin
                  // start a transmit of dummy byte
                  // dwell until complete
                  ns_state = stp_a1 ? S_WAITL0 : S_MOVEDM;
                  // preserve current dat_len contents
                  ns_dat_len = dat_len;
                  // keep transfer running until complete
                  ns_start = stp_a1 ? 1'b0 : 1'b1;
                  // tell external device it is selected
                  ns_sel_n = 1'b0;
                  // do not set rx flag register
                  ns_rxprocessed = 1'b0;
                  // do not clear tx flag register
                  ns_txprocessed = 1'b0;
                end
      S_WAITL0: begin
                  // wait for length byte 0 arrives
                  // dwell until complete
                  ns_state = tx_mbox_dst_full ? S_MOVERX : S_WAITL0;
                  // load dat_len from requesting buffer
                  ns_dat_len = {dat_len[8], tx_mbox_dst_data};
                  // do not start any spi transfer
                  ns_start = 1'b0;
                  // tell external device it is selected
                  ns_sel_n = 1'b0;
                  // do not set rx flag register
                  ns_rxprocessed = 1'b0;
                  // clear tx flag register
                  ns_txprocessed = tx_mbox_dst_full;
                end
      S_MOVERX: begin
                  // start a receive of data byte
                  // dwell until complete
                  ns_state = stp_a1 ? S_PICKUP : S_MOVERX;
                  // preserve current dat_len contents
                  ns_dat_len = dat_len;
                  // keep transfer running until complete
                  ns_start = stp_a1 ? 1'b0 : 1'b1;
                  // tell external device it is selected
                  ns_sel_n = 1'b0;
                  // do not set rx flag register
                  ns_rxprocessed = 1'b0;
                  // do not clear tx flag register
                  ns_txprocessed = 1'b0;
                end
      S_PICKUP: begin
                  // wait for data pickup then move
                  // more data or go idle based on
                  // the remaining transfer length
                  if (rx_mbox_src_read)
                  begin
                    if (dat_len == 9'b000000000)
                    begin
                      // done, return idle
                      ns_state = S_ARBIDL;
                    end
                    else
                    begin
                      // more data, move another byte
                      ns_state = S_MOVERX;
                    end
                    // do not set rx flag register
                    ns_rxprocessed = 1'b0;
                  end
                  else
                  begin
                    ns_state = S_PICKUP;
                    // set rx flag register
                    ns_rxprocessed = rxv;
                  end
                  // do not start any spi transfer
                  ns_start = 1'b0;
                  // decrement current dat_len contents
                  ns_dat_len = dat_len - {8'b0_0000_000, rxv};
                  // tell external device it is deselected
                  if (dat_len == 9'b000000000)
                  begin
                    ns_sel_n = rxvd ? 1'b1 : sel_n;
                  end
                  else
                  begin
                    ns_sel_n = 1'b0;
                  end
                  // do not clear tx flag register
                  ns_txprocessed = 1'b0;
                end
      default:  begin
                  ns_state = 5'bxxxxx;
                  ns_dat_len = 9'bxxxxxxxxx;
                  ns_start = 1'bx;
                  ns_sel_n = 1'bx;
                  ns_rxprocessed = 1'bx;
                  ns_txprocessed = 1'bx;
                end
    endcase
  end

  ///////////////////////////////////////////////////////////////////////////
  // Instantiate the byte transfer FSM.
  ///////////////////////////////////////////////////////////////////////////

  sem_ultra_0_spi_byte example_spi_byte (
    .tx(tx),
    .sta(start),
    .rx(rx),
    .rxv(rxv),
    .stp_a1(stp_a1),
    .icap_clk(icap_clk),
    .reset(reset),
    .spi_d(spi_d),
    .spi_c(spi_c),
    .spi_q(spi_q));

  always @(posedge icap_clk)
  begin
    rxvd <= #TCQ rxv;
  end

  ///////////////////////////////////////////////////////////////////////////
  // Select the outbound data value for serialization based on the FSM state.
  ///////////////////////////////////////////////////////////////////////////

  always @*
  begin
    case (state)
      S_MOVEW1: tx = V_CMD_WREN;
      S_MOVEWV: tx = V_CMD_WVCR;
      S_MOVECR: tx = V_DAT_WVCR;
      S_MOVEW2: tx = V_CMD_WREN;
      S_MOVEEN: tx = V_CMD_EN4B;
      S_MOVEFR: tx = V_CMD_FAST;
      S_MOVEDM: tx = 8'h00;
      S_MOVERX: tx = 8'h00;
      default : tx = dat_len[7:0];
    endcase
  end

  ///////////////////////////////////////////////////////////////////////////
  // Implement flip flop intended for packing in I/O.
  ///////////////////////////////////////////////////////////////////////////

  FDS spi_s_ofd (
    .Q(spi_s_n),
    .D(ns_sel_n),
    .S(reset),
    .C(icap_clk));

  ///////////////////////////////////////////////////////////////////////////
  // Synchronous start-up circuit.
  ///////////////////////////////////////////////////////////////////////////

  wire        q_sync_a;
  wire        q_sync_b;
  wire        q_sync_c;
  wire        q_sync_d;
  wire        q_sync_e;
  wire        q_sync_f;
  wire        q_sync_g;

  wire        q_sync_h;
  wire        q_sync_i;

  (* ASYNC_REG = "TRUE" *)
  FD sync_a (.C(icap_clk),.D(    1'b1),.Q(q_sync_a));
  (* ASYNC_REG = "TRUE" *)
  FD sync_b (.C(icap_clk),.D(q_sync_a),.Q(q_sync_b));
  (* ASYNC_REG = "TRUE" *)
  FD sync_c (.C(icap_clk),.D(q_sync_b),.Q(q_sync_c));
  (* ASYNC_REG = "TRUE" *)
  FD sync_d (.C(icap_clk),.D(q_sync_c),.Q(q_sync_d));
  (* ASYNC_REG = "TRUE" *)
  FD sync_e (.C(icap_clk),.D(q_sync_d),.Q(q_sync_e));
  (* ASYNC_REG = "TRUE" *)
  FD sync_f (.C(icap_clk),.D(q_sync_e),.Q(q_sync_f));
  (* ASYNC_REG = "TRUE" *)
  FD sync_g (.C(icap_clk),.D(q_sync_f),.Q(q_sync_g));

  FDS sync_h (.C(icap_clk),.D(!q_sync_g),.Q(q_sync_h),.S(rx_mbox_src_irq));
  FDS sync_i (.C(icap_clk),.D(q_sync_h),.Q(q_sync_i),.S(rx_mbox_src_irq));

  assign reset = q_sync_i;

  ///////////////////////////////////////////////////////////////////////////
  //
  ///////////////////////////////////////////////////////////////////////////

endmodule

/////////////////////////////////////////////////////////////////////////////
//
/////////////////////////////////////////////////////////////////////////////
