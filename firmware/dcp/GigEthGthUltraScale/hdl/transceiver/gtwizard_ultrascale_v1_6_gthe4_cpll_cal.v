//------------------------------------------------------------------------------
//  (c) Copyright 2013-2015 Xilinx, Inc. All rights reserved.
//
//  This file contains confidential and proprietary information
//  of Xilinx, Inc. and is protected under U.S. and
//  international copyright and other intellectual property
//  laws.
//
//  DISCLAIMER
//  This disclaimer is not a license and does not grant any
//  rights to the materials distributed herewith. Except as
//  otherwise provided in a valid license issued to you by
//  Xilinx, and to the maximum extent permitted by applicable
//  law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
//  WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
//  AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
//  BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
//  INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
//  (2) Xilinx shall not be liable (whether in contract or tort,
//  including negligence, or under any other theory of
//  liability) for any loss or damage of any kind or nature
//  related to, arising under or in connection with these
//  materials, including for any direct, or any indirect,
//  special, incidental, or consequential loss or damage
//  (including loss of data, profits, goodwill, or any type of
//  loss or damage suffered as a result of any action brought
//  by a third party) even if such damage or loss was
//  reasonably foreseeable or Xilinx had been advised of the
//  possibility of the same.
//
//  CRITICAL APPLICATIONS
//  Xilinx products are not designed or intended to be fail-
//  safe, or for use in any application requiring fail-safe
//  performance, such as life-support or safety devices or
//  systems, Class III medical devices, nuclear facilities,
//  applications related to the deployment of airbags, or any
//  other applications that could lead to death, personal
//  injury, or severe property or environmental damage
//  (individually and collectively, "Critical
//  Applications"). Customer assumes the sole risk and
//  liability of any use of Xilinx products in Critical
//  Applications, subject only to applicable laws and
//  regulations governing limitations on product liability.
//
//  THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
//  PART OF THIS FILE AT ALL TIMES.
//------------------------------------------------------------------------------

// ***************************
// * DO NOT MODIFY THIS FILE *
// ***************************

`timescale 1ps/1ps

module gtwizard_ultrascale_v1_6_5_gthe4_cpll_cal # (
        parameter SIM_RESET_SPEEDUP = "TRUE",
        parameter C_PCIE_ENABLE = 1'b0,
        parameter integer C_PCIE_CORECLK_FREQ = 250,
        parameter REVISION = 2
)(
        // control signals
        input wire  [17:0] TXOUTCLK_PERIOD_IN,
        input wire  [15:0] WAIT_DEASSERT_CPLLPD_IN,
        input wire  [17:0] CNT_TOL_IN,
        input wire  [15:0] FREQ_COUNT_WINDOW_IN,
        // User Interface
        input wire         RESET_IN,
        input wire         CLK_IN,
        input wire         USER_TXPROGDIVRESET_IN,
        output reg         USER_TXPRGDIVRESETDONE_OUT,
        input wire  [2:0]  USER_TXOUTCLKSEL_IN,
        input wire         USER_TXOUTCLK_BUFG_CE_IN,
        input wire         USER_TXOUTCLK_BUFG_CLR_IN,
        output reg         USER_CPLLLOCK_OUT,
        input wire  [9:0]  USER_CHANNEL_DRPADDR_IN,
        input wire  [15:0] USER_CHANNEL_DRPDI_IN,
        input wire         USER_CHANNEL_DRPEN_IN,
        input wire         USER_CHANNEL_DRPWE_IN,
        output reg         USER_CHANNEL_DRPRDY_OUT,
        output reg [15:0]  USER_CHANNEL_DRPDO_OUT,
        // Debug Interface
        output wire        CPLL_CAL_FAIL,
        output wire        CPLL_CAL_DONE,
        output wire [15:0] DEBUG_OUT,
        output wire [17:0] CAL_FREQ_CNT,
        input       [3:0]  REPEAT_RESET_LIMIT,
        // GT Interface
        input wire         GTHE4_TXOUTCLK_IN,
        input wire         GTHE4_CPLLLOCK_IN,
        output wire        GTHE4_CPLLRESET_OUT,
        output wire        GTHE4_CPLLPD_OUT,
        output reg         GTHE4_TXPROGDIVRESET_OUT,
        output reg  [2:0]  GTHE4_TXOUTCLKSEL_OUT,
        input wire         GTHE4_TXPRGDIVRESETDONE_IN,
        output reg [9:0]   GTHE4_CHANNEL_DRPADDR_OUT,
        output reg [15:0]  GTHE4_CHANNEL_DRPDI_OUT,
        output reg         GTHE4_CHANNEL_DRPEN_OUT,
        output reg         GTHE4_CHANNEL_DRPWE_OUT,
        input wire         GTHE4_CHANNEL_DRPRDY_IN,
        input wire  [15:0] GTHE4_CHANNEL_DRPDO_IN
);


  //DRP FSM
  localparam DRP_WAIT      = 0;
  localparam DRP_READ      = 1;
  localparam DRP_READ_ACK  = 2;
  localparam DRP_MODIFY    = 3;
  localparam DRP_WRITE     = 4;
  localparam DRP_WRITE_ACK = 5;
  localparam DRP_DONE      = 6;


  localparam RESET                = 0;
  localparam READ_PROGCLK_SEL     = 1;
  localparam MODIFY_PROGCLK_SEL   = 2;
  localparam READ_PROGDIV         = 3;
  localparam MODIFY_PROGDIV       = 4;
  localparam MODIFY_TXOUTCLK_SEL  = 5;
  localparam ASSERT_CPLLPD        = 6;
  localparam DEASSERT_CPLLPD      = 7;
  localparam ASSERT_CPLLRESET     = 8;
  localparam DEASSERT_CPLLRESET   = 9;
  localparam WAIT_GTCPLLLOCK      = 10;
  localparam ASSERT_PROGDIVRESET  = 11;
  localparam WAIT_PRGDIVRESETDONE = 12;
  localparam CHECK_FREQ           = 13;
  localparam RESTORE_PROGDIV      = 14;
  localparam RESTORE_PROGCLK_SEL  = 15;
  localparam WAIT_GTCPLLLOCK2     = 16;
  localparam ASSERT_PROGDIVRESET2 = 17;
  localparam WAIT_PRGDIVRESETDONE2= 18;
  localparam CAL_FAIL             = 19;
  localparam CAL_DONE             = 20;
  
  
  reg [25:0] cpll_cal_state = 26'd0;
  wire [4:0] cpll_cal_state_bin;
  reg [6:0] drp_state = 7'd1;
  wire drp_done;
  reg [9:0] daddr = 10'd0;
  reg [15:0] di = 16'd0;
  wire drdy;
  wire [15:0] dout;
  reg den = 1'b0;
  reg dwe = 1'b0;
  reg wr = 1'b0;
  reg rd = 1'b0;
  reg [15:0] di_msk;
  reg [15:0] mask;
  reg [19:0] wait_ctr;
  reg [3:0] repeat_ctr;
  reg [1:0] progclk_sel_store = 2'b00;
  reg [15:0] progdiv_cfg_store = 16'd0;
  reg fboost_store = 1'b0;
  reg mask_user_in = 1'b0;
  reg cpllreset_int = 1'b0;
  reg cpllpd_int = 1'b0;
  reg txprogdivreset_int = 1'b0;
  reg [2:0] txoutclksel_int = 3'b000;
  reg cal_fail_store = 1'b0;

  localparam [19:0]  SIM_WAIT_ASSERT_CPLLRESET = 20'h2710;
  localparam [19:0]  SIM_WAIT_CPLLLOCK  = 20'h2710;
  localparam [15:0]  SIM_WAIT_DEASSERT_CPLLRESET = 16'd100;
  localparam [19:0]  SYNTH_WAIT_ASSERT_CPLLRESET = 20'h186A0;
  localparam [19:0]  SYNTH_WAIT_CPLLLOCK  = 20'h186A0;
  localparam [15:0]  SYNTH_WAIT_DEASSERT_CPLLRESET = 16'd10000;

  localparam [40:1] SIM_RESET_SPEEDUP_REG = SIM_RESET_SPEEDUP;
  localparam [4:0]  WAIT_WIDTH_PROGDIVRESET = 5'd10;
  localparam [19:0]  WAIT_ASSERT_CPLLRESET =
    //pragma translate_off
     (SIM_RESET_SPEEDUP_REG == "TRUE") ? SIM_WAIT_ASSERT_CPLLRESET  :
    //pragma translate_on
                                    SYNTH_WAIT_ASSERT_CPLLRESET;
  localparam [4:0]  WAIT_ASSERT_CPLLPD      = 5'd10;
  localparam [15:0]  WAIT_DEASSERT_CPLLRESET =  
    //pragma translate_off
     (SIM_RESET_SPEEDUP_REG == "TRUE" ) ? SIM_WAIT_DEASSERT_CPLLRESET :
    //pragma translate_on
                                      SYNTH_WAIT_DEASSERT_CPLLRESET;
  localparam [19:0]  WAIT_CPLLLOCK = 
    //pragma translate_off
     (SIM_RESET_SPEEDUP_REG == "TRUE" ) ? SIM_WAIT_CPLLLOCK :
    //pragma translate_on
                                    SYNTH_WAIT_CPLLLOCK;


  localparam [1:0]  MOD_PROGCLK_SEL = 2'b10;
  localparam [15:0] MOD_PROGDIV_CFG = 16'hE062; //divider 20
  localparam [2:0]  MOD_TXOUTCLK_SEL = 3'b101;
  localparam        MOD_FBOOST = 1'b1;
  localparam [9:0]  ADDR_TX_PROGCLK_SEL = 10'h00C;
  localparam [9:0]  ADDR_TX_PROGDIV_CFG = 10'h03e; //GTY /GTH addresses are different

  // Drive TXOUTCLK with BUFG_GT-buffered source clock, divider = 1
  wire txoutclkmon;
  //assign txoutclkmon = GTHE4_TXOUTCLK_IN;
  BUFG_GT bufg_gt_txoutclkmon_inst (
    .CE      (USER_TXOUTCLK_BUFG_CE_IN),
    .CEMASK  (1'b1),
    .CLR     (USER_TXOUTCLK_BUFG_CLR_IN),
    .CLRMASK (1'b1),
    .DIV     (3'b000),
    .I       (GTHE4_TXOUTCLK_IN),
    .O       (txoutclkmon)
  );

  wire reset_in_sync;
  gtwizard_ultrascale_v1_6_5_reset_synchronizer reset_synchronizer_resetin_inst (
    .clk_in (CLK_IN),
    .rst_in   (RESET_IN),
    .rst_out  (reset_in_sync)
  );

  wire gthe4_cplllock_sync;
  gtwizard_ultrascale_v1_6_5_bit_synchronizer bit_synchronizer_cplllock_inst (
    .clk_in (CLK_IN),
    .i_in   (GTHE4_CPLLLOCK_IN),
    .o_out  (gthe4_cplllock_sync)
  );

  wire user_txprogdivreset_sync;
  gtwizard_ultrascale_v1_6_5_bit_synchronizer bit_synchronizer_txprogdivreset_inst (
    .clk_in (CLK_IN),
    .i_in   (USER_TXPROGDIVRESET_IN),
    .o_out  (user_txprogdivreset_sync)
  );

  wire gthe4_txprgdivresetdone_sync;
  gtwizard_ultrascale_v1_6_5_bit_synchronizer bit_synchronizer_txprgdivresetdone_inst (
    .clk_in (CLK_IN),
    .i_in   (GTHE4_TXPRGDIVRESETDONE_IN),
    .o_out  (gthe4_txprgdivresetdone_sync)
  );

  wire [2:0] user_txoutclksel_sync;
  gtwizard_ultrascale_v1_6_5_bit_synchronizer bit_synchronizer_txoutclksel_inst0 (
    .clk_in (CLK_IN),
    .i_in   (USER_TXOUTCLKSEL_IN[0]),
    .o_out  (user_txoutclksel_sync[0])
  );
  gtwizard_ultrascale_v1_6_5_bit_synchronizer bit_synchronizer_txoutclksel_inst1 (
    .clk_in (CLK_IN),
    .i_in   (USER_TXOUTCLKSEL_IN[1]),
    .o_out  (user_txoutclksel_sync[1])
  );
  gtwizard_ultrascale_v1_6_5_bit_synchronizer bit_synchronizer_txoutclksel_inst2 (
    .clk_in (CLK_IN),
    .i_in   (USER_TXOUTCLKSEL_IN[2]),
    .o_out  (user_txoutclksel_sync[2])
  );

  assign GTHE4_CPLLRESET_OUT = cpllreset_int;
  assign GTHE4_CPLLPD_OUT = cpllpd_int;

  always @(posedge CLK_IN) begin
    if (mask_user_in | cpll_cal_state[CAL_FAIL] | cpll_cal_state[RESET] | reset_in_sync)
      USER_CPLLLOCK_OUT <= 1'b0;
    else
      USER_CPLLLOCK_OUT <= gthe4_cplllock_sync;
  end

  always @(posedge CLK_IN) begin
    if (mask_user_in)
      GTHE4_TXPROGDIVRESET_OUT <= txprogdivreset_int;
    else
      GTHE4_TXPROGDIVRESET_OUT <= user_txprogdivreset_sync;
  end

  always @(posedge CLK_IN) begin
    if (mask_user_in)
      GTHE4_TXOUTCLKSEL_OUT <= txoutclksel_int;
    else
      GTHE4_TXOUTCLKSEL_OUT <= user_txoutclksel_sync;
  end

  always @(posedge CLK_IN) begin
    if (mask_user_in)
      USER_TXPRGDIVRESETDONE_OUT <= 1'b0;
    else
      USER_TXPRGDIVRESETDONE_OUT <= gthe4_txprgdivresetdone_sync;
  end

  // frequency counter for txoutclk
  wire [17:0] txoutclk_freq_cnt;
  reg freq_counter_rst = 1'b1;
  wire freq_cnt_done;
  gtwizard_ultrascale_v1_6_5_gthe4_cpll_cal_freq_counter U_TXOUTCLK_FREQ_COUNTER
    (
      .freq_cnt_o(txoutclk_freq_cnt),
      .done_o(freq_cnt_done),
      .rst_i(freq_counter_rst),
      .test_term_cnt_i(FREQ_COUNT_WINDOW_IN),
      .ref_clk_i(CLK_IN),
      .test_clk_i(txoutclkmon)
    );

  //Debug signals
  assign DEBUG_OUT = {cpllreset_int,cpllpd_int,gthe4_cplllock_sync,1'b0,freq_cnt_done,freq_counter_rst,mask_user_in,cpll_cal_state_bin,repeat_ctr};
  assign CPLL_CAL_FAIL = cpll_cal_state[CAL_FAIL];
  assign CPLL_CAL_DONE = cpll_cal_state[CAL_DONE];
  assign CAL_FREQ_CNT = txoutclk_freq_cnt;

  //CPLL CAL FSM
  always @(posedge CLK_IN) begin
      if (reset_in_sync) begin
        cpll_cal_state <= 0;
        cpll_cal_state[RESET] <= 1'b1;
        cpllreset_int <= 1'b0;
        cpllpd_int <= 1'b0;
        txprogdivreset_int <= 1'b0;
        mask_user_in <= 1'b0;
        wr <= 1'b0;
        rd <= 1'b0;
      end
      else begin
         cpll_cal_state <= 0;
         case(1'b1) // synthesis parallel_case full_case
             cpll_cal_state[RESET]:
             begin
               wait_ctr <= 16'd0;
               repeat_ctr <= 4'd0;
               mask_user_in <= 1'b1;
               di_msk <= 16'b0000_0000_0000_0000;
               cpll_cal_state[READ_PROGCLK_SEL] <= 1'b1;
             end

             cpll_cal_state[READ_PROGCLK_SEL]:
             begin
               rd <= 1'b1;
               if (drp_done) begin
                 rd <= 1'b0;
                 
                 progclk_sel_store <= (C_PCIE_ENABLE) ? 2'b10 : dout[11:10];

                 cpll_cal_state[MODIFY_PROGCLK_SEL] <= 1'b1;
               end
               else begin
                 cpll_cal_state[READ_PROGCLK_SEL] <= 1'b1;
               end
             end

             cpll_cal_state[MODIFY_PROGCLK_SEL]:
             begin
               if (!drp_done) begin
                 wr <= 1'b1;
                 cpll_cal_state[MODIFY_PROGCLK_SEL] <= 1'b1;
               end
               else begin
                 wr <= 1'b0;
                 cpll_cal_state[READ_PROGDIV] <= 1'b1;
               end
               di_msk<= {4'd0,MOD_PROGCLK_SEL,10'd0};
             end

             cpll_cal_state[READ_PROGDIV]:
             begin
               rd <= 1'b1;
               if (drp_done) begin
                 rd <= 1'b0;
                 
                 progdiv_cfg_store <= (C_PCIE_ENABLE) ? ((C_PCIE_CORECLK_FREQ == 250) ? 16'hE060 : 16'hE078) : dout;

                 cpll_cal_state[MODIFY_PROGDIV] <= 1'b1;
               end
               else begin
                 cpll_cal_state[READ_PROGDIV] <= 1'b1;
               end
             end

             cpll_cal_state[MODIFY_PROGDIV]:
             begin
               if (!drp_done) begin
                 wr <= 1'b1;
                 cpll_cal_state[MODIFY_PROGDIV] <= 1'b1;
               end
               else begin
                 wr <= 1'b0;
                 cpll_cal_state[MODIFY_TXOUTCLK_SEL] <= 1'b1;
                 wait_ctr <= 16'd0;
               end
               di_msk<= MOD_PROGDIV_CFG;
             end

             cpll_cal_state[MODIFY_TXOUTCLK_SEL]:
             begin
               cpll_cal_state[ASSERT_CPLLPD] <= 1'b1;
             end
             
             cpll_cal_state[ASSERT_CPLLPD]:
             begin
               if (wait_ctr < WAIT_ASSERT_CPLLPD) begin
                 wait_ctr <= wait_ctr + 1'b1;
                 cpll_cal_state[ASSERT_CPLLPD] <= 1'b1;                 
               end
               else begin
                 cpllpd_int <= 1'b1;
                 cpll_cal_state[DEASSERT_CPLLPD] <= 1'b1;
                 wait_ctr <= 16'd0;
               end
             end
             
             cpll_cal_state[DEASSERT_CPLLPD]:
             begin
               if (wait_ctr < WAIT_DEASSERT_CPLLPD_IN) begin
                 wait_ctr <= wait_ctr + 1'b1;
                 cpll_cal_state[DEASSERT_CPLLPD] <= 1'b1;
               end
               else begin
                 cpllpd_int <= 1'b0;
                 cpll_cal_state[ASSERT_CPLLRESET] <= 1'b1;
                 wait_ctr <= 16'd0;
                 freq_counter_rst <= 1'b1;
               end
             end 
             
             cpll_cal_state[ASSERT_CPLLRESET]:
             begin
               if (wait_ctr < WAIT_ASSERT_CPLLRESET) begin
                 wait_ctr <= wait_ctr + 1'b1;
                 cpll_cal_state[ASSERT_CPLLRESET] <= 1'b1;
               end
               else begin
                 cpllreset_int <= 1'b1;
                 freq_counter_rst <= 1'b1;
                 cpll_cal_state[DEASSERT_CPLLRESET] <= 1'b1;
                 wait_ctr <= 16'd0;
               end
             end

             cpll_cal_state[DEASSERT_CPLLRESET]:
             begin
               if (wait_ctr < WAIT_DEASSERT_CPLLRESET) begin
                 wait_ctr <= wait_ctr + 1'b1;
                 cpll_cal_state[DEASSERT_CPLLRESET] <= 1'b1;
               end
               else begin
                 cpllreset_int <= 1'b0;
                 cpll_cal_state[WAIT_GTCPLLLOCK] <= 1'b1;
                 wait_ctr <= 16'd0;
               end
             end
             

             cpll_cal_state[WAIT_GTCPLLLOCK]:
             begin
               if(wait_ctr < WAIT_CPLLLOCK) begin
                 cpll_cal_state[WAIT_GTCPLLLOCK] <= 1'b1;
                 wait_ctr <= wait_ctr + 1'b1;
               end
               else begin
                 cpll_cal_state[ASSERT_PROGDIVRESET] <= 1'b1;
                 wait_ctr <= 16'd0;
               end
             end

             cpll_cal_state[ASSERT_PROGDIVRESET]:
             begin
               if (wait_ctr < WAIT_WIDTH_PROGDIVRESET) begin
                 wait_ctr <= wait_ctr + 1'b1;
                 txprogdivreset_int <= 1'b1;
                 cpll_cal_state[ASSERT_PROGDIVRESET] <= 1'b1;
               end
               else begin
                 txprogdivreset_int <= 1'b0;
                 cpll_cal_state[WAIT_PRGDIVRESETDONE] <= 1'b1;
                 wait_ctr <= 16'd0;
               end
             end

             cpll_cal_state[WAIT_PRGDIVRESETDONE]:
             begin
               if (gthe4_txprgdivresetdone_sync) begin
                 cpll_cal_state[CHECK_FREQ] <= 1'b1;
                 freq_counter_rst <= 1'b0;
               end
               else begin
                 cpll_cal_state[WAIT_PRGDIVRESETDONE] <= 1'b1;
               end
             end

             cpll_cal_state[CHECK_FREQ]:
             begin
               if(freq_cnt_done) begin
                 if ((txoutclk_freq_cnt >= (TXOUTCLK_PERIOD_IN - CNT_TOL_IN)) & (txoutclk_freq_cnt <= (TXOUTCLK_PERIOD_IN + CNT_TOL_IN))) begin
                 
                   cpll_cal_state[RESTORE_PROGDIV] <= 1'b1;
                   cal_fail_store <= 1'b0;
                 end
                 else begin
                   if (repeat_ctr < REPEAT_RESET_LIMIT) begin
                     cpll_cal_state[ASSERT_CPLLPD] <= 1'b1;
                     repeat_ctr <= repeat_ctr + 1'b1;
                   end
                   else begin
                     cpll_cal_state[RESTORE_PROGDIV] <= 1'b1;
                     cal_fail_store <= 1'b1;
                   end
                 end
               end
               else
                 cpll_cal_state[CHECK_FREQ] <= 1'b1;
             end

            cpll_cal_state[RESTORE_PROGDIV]:
             begin
               if (!drp_done) begin
                 wr <= 1'b1;
                 cpll_cal_state[RESTORE_PROGDIV] <= 1'b1;
               end
               else begin
                 wr <= 1'b0;
                 cpll_cal_state[RESTORE_PROGCLK_SEL] <= 1'b1;
               end
               di_msk<= progdiv_cfg_store;
             end

             cpll_cal_state[RESTORE_PROGCLK_SEL]:
             begin
               if (!drp_done) begin
                 wr <= 1'b1;
                 cpll_cal_state[RESTORE_PROGCLK_SEL] <= 1'b1;
               end
               else begin
                 wr <= 1'b0;
                 cpll_cal_state[WAIT_GTCPLLLOCK2] <= 1'b1;
               end
               di_msk<= {4'd0,progclk_sel_store,10'd0};
             end
            
             cpll_cal_state[WAIT_GTCPLLLOCK2]:
             begin
               cpll_cal_state[ASSERT_PROGDIVRESET2] <= 1'b1;
               if(!gthe4_cplllock_sync)
                  cal_fail_store <= 1'b1;
               else
                  cal_fail_store <= cal_fail_store;
                 //cpll_cal_state[ASSERT_PROGDIVRESET2] <= 1'b1;
               //else
                 //cpll_cal_state[WAIT_GTCPLLLOCK2] <= 1'b1;
             end

             cpll_cal_state[ASSERT_PROGDIVRESET2]:
             begin
               if (wait_ctr < WAIT_WIDTH_PROGDIVRESET) begin
                 wait_ctr <= wait_ctr + 1'b1;
                 txprogdivreset_int <= 1'b1;
                 cpll_cal_state[ASSERT_PROGDIVRESET2] <= 1'b1;
               end
               else begin
                 txprogdivreset_int <= 1'b0;
                 cpll_cal_state[WAIT_PRGDIVRESETDONE2] <= 1'b1;
                 wait_ctr <= 16'd0;
               end
             end

             cpll_cal_state[WAIT_PRGDIVRESETDONE2]:
             begin
               if (gthe4_txprgdivresetdone_sync) begin
                 if (cal_fail_store)
                   cpll_cal_state[CAL_FAIL] <= 1'b1;
                 else
                   cpll_cal_state[CAL_DONE] <= 1'b1;
               end
               else begin
                 cpll_cal_state[WAIT_PRGDIVRESETDONE2] <= 1'b1;
               end
             end

             cpll_cal_state[CAL_FAIL]:
             begin
               cpll_cal_state[CAL_FAIL] <= 1'b1;
               mask_user_in <= 1'b0;
             end

             cpll_cal_state[CAL_DONE]:
             begin
               cpll_cal_state[CAL_DONE] <= 1'b1;
               mask_user_in <= 1'b0;
             end
         endcase
       end
   end // always block

   always @(posedge CLK_IN) begin
     if (cpll_cal_state[RESET])
       txoutclksel_int <= 3'b0;
     else if (cpll_cal_state[MODIFY_TXOUTCLK_SEL])
       txoutclksel_int <= MOD_TXOUTCLK_SEL;
   end

   always @(posedge CLK_IN) begin
     if      (cpll_cal_state[RESET]) begin
       daddr <= 10'h000;
       mask  <= 16'b1111_1111_1111_1111;
     end
     else if (cpll_cal_state[READ_PROGCLK_SEL] | cpll_cal_state[MODIFY_PROGCLK_SEL] | cpll_cal_state[RESTORE_PROGCLK_SEL]) begin
       daddr <= ADDR_TX_PROGCLK_SEL;
       mask  <= 16'b1111_0011_1111_1111;
     end
     else if (cpll_cal_state[READ_PROGDIV] | cpll_cal_state[MODIFY_PROGDIV] | cpll_cal_state[RESTORE_PROGDIV]) begin
       daddr <= ADDR_TX_PROGDIV_CFG;
       mask  <= 16'b0000_0000_0000_0000;
     end

   end


  // DRP FSM
  always @(posedge CLK_IN) begin
    if (mask_user_in) begin
      GTHE4_CHANNEL_DRPADDR_OUT <= daddr;
      GTHE4_CHANNEL_DRPDI_OUT   <= di;
      GTHE4_CHANNEL_DRPEN_OUT   <= den;
      GTHE4_CHANNEL_DRPWE_OUT   <= dwe;
      USER_CHANNEL_DRPRDY_OUT   <= 1'b0;
      USER_CHANNEL_DRPDO_OUT    <= 16'd0;
    end
    else begin
      GTHE4_CHANNEL_DRPADDR_OUT <= USER_CHANNEL_DRPADDR_IN;
      GTHE4_CHANNEL_DRPDI_OUT   <= USER_CHANNEL_DRPDI_IN;
      GTHE4_CHANNEL_DRPEN_OUT   <= USER_CHANNEL_DRPEN_IN;
      GTHE4_CHANNEL_DRPWE_OUT   <= USER_CHANNEL_DRPWE_IN;
      USER_CHANNEL_DRPRDY_OUT   <= GTHE4_CHANNEL_DRPRDY_IN;
      USER_CHANNEL_DRPDO_OUT    <= GTHE4_CHANNEL_DRPDO_IN;
    end
  end
  assign drdy = GTHE4_CHANNEL_DRPRDY_IN;
  assign dout = GTHE4_CHANNEL_DRPDO_IN;

  always @(posedge CLK_IN or posedge reset_in_sync) begin
  if (reset_in_sync) begin
    den <= 1'b0;
    dwe <= 1'b0;
    di <= 16'h0000;
    drp_state <= 0;
    drp_state[DRP_WAIT] <= 1'b1;
  end
  else begin
    drp_state <= 0;
    case (1'b1) // synthesis parallel_case full_case
        drp_state[DRP_WAIT]:
        begin
          if (wr | rd) drp_state[DRP_READ] <= 1'b1;
          else         drp_state[DRP_WAIT] <= 1'b1;
        end
        drp_state[DRP_READ]:
        begin
          den <= 1'b1;
          drp_state[DRP_READ_ACK] <= 1'b1;
        end
        drp_state[DRP_READ_ACK]:
        begin
          den <= 1'b0;
          if (drdy == 1'b1) begin
            if (rd) drp_state[DRP_DONE] <= 1'b1;
            else    drp_state[DRP_MODIFY] <= 1'b1;
          end
          else      drp_state[DRP_READ_ACK] <= 1'b1;
        end
        drp_state[DRP_MODIFY]:
        begin
          di <= di_msk | (dout & mask);
          drp_state[DRP_WRITE] <= 1'b1;
        end
        drp_state[DRP_WRITE]:
        begin
          den <= 1'b1;
          dwe <= 1'b1;
          drp_state[DRP_WRITE_ACK] <= 1'b1;
        end
        drp_state[DRP_WRITE_ACK]:
        begin
          den <= 1'b0;
          dwe <= 1'b0;
          if (drdy == 1'b1) drp_state[DRP_DONE] <= 1'b1;
          else              drp_state[DRP_WRITE_ACK] <= 1'b1;
        end
        drp_state[DRP_DONE]:
        begin
          drp_state[DRP_WAIT] <= 1'b1;
        end
    endcase
  end
  end

  assign drp_done = drp_state[DRP_DONE];


  //debug logic - convert one hot state to binary
  genvar i,j;
  generate
    for (j=0; j<5; j=j+1)
    begin : jl
      wire [26-1:0] tmp_mask;
      for (i=0; i<26; i=i+1)
      begin : il
        assign tmp_mask[i] = i[j];
      end
      assign cpll_cal_state_bin[j] = |(tmp_mask & cpll_cal_state);
    end
  endgenerate

endmodule //CPLL_CAL
