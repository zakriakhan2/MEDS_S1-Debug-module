// SPDX-License-Identifier: Apache-2.0
//
// s1_pkg.sv
// [WIP -- dtm-01]
//
// Shared parameters, widths and types used across the core and platform.
// This pass adds the Debug Transport Module / DMI section only; other
// projects' constants may already live here or be added alongside this.
//
// Contract: RISC-V External Debug Support Specification (DTM/DMI chapter).

package s1_pkg;

  // ===================================================================
  // DTM / DMI -- widths
  // ===================================================================
  localparam int unsigned DTM_IR_W        = 5;
  localparam int unsigned DTM_DTMCS_W     = 32;
  localparam int unsigned DTM_IDCODE_W    = 32;
  localparam int unsigned DMI_ABITS       = 7;                 // dm_addr width
  localparam int unsigned DMI_DATA_W      = 32;                // dm_wdata/dm_rdata width
  localparam int unsigned DMI_OP_W        = 2;                 // req op / resp status width
  localparam int unsigned DMI_REQ_W       = DMI_ABITS + DMI_DATA_W + DMI_OP_W;  // 41
  localparam int unsigned DMI_RESP_W      = DMI_DATA_W + DMI_OP_W;              // 34

  // ===================================================================
  // DTM -- IR opcodes (5-bit)
  // ===================================================================
  localparam logic [DTM_IR_W-1:0] DTM_IR_IDCODE = 5'b00001;
  localparam logic [DTM_IR_W-1:0] DTM_IR_DTMCS  = 5'b10000;
  localparam logic [DTM_IR_W-1:0] DTM_IR_DMI    = 5'b10001;
  localparam logic [DTM_IR_W-1:0] DTM_IR_BYPASS = 5'b11111;

  // IR reset / Capture-IR fixed value. Both equal 5'b00001: reset defaults
  // to IDCODE (so a debugger can identify the chip without first loading an
  // instruction), and the capture pattern's mandatory [1:0]==2'b01 happens
  // to coincide with it.
  localparam logic [DTM_IR_W-1:0] DTM_IR_RESET_VAL   = DTM_IR_IDCODE;
  localparam logic [DTM_IR_W-1:0] DTM_IR_CAPTURE_VAL = 5'b00001;

  // ===================================================================
  // DTMCS -- field bit positions (spec-standard layout)
  // ===================================================================
  localparam int unsigned DTMCS_VERSION_LSB     = 0;
  localparam int unsigned DTMCS_ABITS_LSB       = 4;
  localparam int unsigned DTMCS_DMISTAT_LSB     = 10;
  localparam int unsigned DTMCS_IDLE_LSB        = 12;
  localparam int unsigned DTMCS_DMIRESET_BIT    = 16;
  localparam int unsigned DTMCS_DMIHARDRESET_BIT = 17;

  localparam logic [3:0] DTMCS_VERSION_VAL = 4'd1;   // spec 0.13/1.0
  localparam logic [5:0] DTMCS_ABITS_VAL   = DMI_ABITS[5:0];
  localparam logic [2:0] DTMCS_IDLE_VAL    = 3'b000;

  // ===================================================================
  // DMI -- request op / response status encodings
  // ===================================================================
  typedef enum logic [DMI_OP_W-1:0] {
    DMI_OP_NOP   = 2'b00,
    DMI_OP_READ  = 2'b01,
    DMI_OP_WRITE = 2'b10
    // 2'b11 reserved
  } dmi_op_e;

  typedef enum logic [DMI_OP_W-1:0] {
    DMI_STATUS_SUCCESS  = 2'b00,
    // 2'b01 reserved
    DMI_STATUS_FAILED   = 2'b10,
    DMI_STATUS_BUSY     = 2'b11
  } dmi_status_e;

  // ===================================================================
  // DMI -- 41-bit request / 34-bit response bit layout
  //   req : [40:34]=addr  [33:2]=wdata  [1:0]=op
  //   resp: [33:2]=rdata  [1:0]=status
  // ===================================================================
  localparam int unsigned DMI_REQ_ADDR_LSB  = DMI_OP_W + DMI_DATA_W;  // 34
  localparam int unsigned DMI_REQ_DATA_LSB  = DMI_OP_W;               // 2
  localparam int unsigned DMI_REQ_OP_LSB    = 0;

  localparam int unsigned DMI_RESP_DATA_LSB   = DMI_OP_W;             // 2
  localparam int unsigned DMI_RESP_STATUS_LSB = 0;

  // ===================================================================
  // IDCODE -- default placeholder (override via module parameter)
  // ===================================================================
  localparam logic [DTM_IDCODE_W-1:0] DTM_IDCODE_DEFAULT =
      {4'h1, 16'h1000, 11'h000, 1'b1};

endpackage : s1_pkg
