// SPDX-License-Identifier: Apache-2.0
//
// meds_s1_dmi_core_if.sv
// [WIP -- dtm-01]
//
// core_clk-domain half of the DMI clock-domain crossing. One clock/reset
// at the port boundary (R-N6): clk_i/rst_ni here are core_clk / the
// external dmi_rst_ni. Internally derives a second, hardreset-aware reset
// via the shared meds_s1_dmi_rst_gen module (R-C4: no ad-hoc local reset
// logic -- a dedicated, reusable module owns it) for its own FSM/sync
// flops, while the hardreset receive chain itself must stay on the raw
// external reset to avoid a circular dependency.
//
// Owns: the request-valid receive synchronizer, the hardreset toggle
// receiver, the Bridge FSM (idle/access/completed, with the NOP
// fast-path), and the one-shot response capture register.

module meds_s1_dmi_core_if
  import s1_pkg::*;
(
  input  logic                     clk_i,   // core_clk
  input  logic                     rst_ni,  // external active-low reset (dmi_rst_ni)

  input  logic [DMI_REQ_W-1:0]     req_latch_i,         // quasi-static snapshot from tck_if
  input  logic                     req_valid_async_i,   // dmi_req_valid_q level, async
  input  logic                     hardreset_toggle_i,  // toggle bit from tck_if

  output logic                     resp_valid_async_o,  // level, async to tck_if's synchronizer
  output logic [DMI_RESP_W-1:0]    resp_data_o,         // quasi-static resp bus

  output logic [DMI_ABITS-1:0]     dm_addr_o,
  output logic [DMI_DATA_W-1:0]    dm_wdata_o,
  output logic                     dm_write_o,
  output logic                     dm_read_o,
  input  logic [DMI_DATA_W-1:0]    dm_rdata_i,
  input  logic                     dm_ready_i
);

  // ---------------------------------------------------------------------
  // Hardreset receive chain: MUST use the raw external reset (rst_ni),
  // never the derived reset below -- using the derived reset here would
  // be circular (it depends on this chain's output).
  // ---------------------------------------------------------------------
  logic hardreset_pulse;

  meds_s1_cdc_toggle_dst u_hardreset_toggle_dst (
    .clk_i   (clk_i),
    .rst_ni  (rst_ni),
    .toggle_i(hardreset_toggle_i),
    .pulse_o (hardreset_pulse)
  );

  // ---------------------------------------------------------------------
  // Derived reset: clean, glitch-free reset for every other flop in this
  // module, asserted by either the external reset or a hardreset event.
  // ---------------------------------------------------------------------
  logic core_rst_n;

  meds_s1_dmi_rst_gen u_rst_gen (
    .clk_i            (clk_i),
    .rst_ni           (rst_ni),
    .hardreset_pulse_i(hardreset_pulse),
    .rst_no           (core_rst_n)
  );

  // ---------------------------------------------------------------------
  // Request-valid receive synchronizer (tck -> core_clk)
  // ---------------------------------------------------------------------
  logic core_req_valid;

  meds_s1_cdc_2ff #(
    .WIDTH (1)
  ) u_req_sync (
    .clk_i  (clk_i),
    .rst_ni (core_rst_n),
    .async_i(req_valid_async_i),
    .sync_o (core_req_valid)
  );

  // ---------------------------------------------------------------------
  // Bridge FSM
  // ---------------------------------------------------------------------
  typedef enum logic [1:0] { S_IDLE, S_ACCESS, S_COMPLETED } bridge_state_e;

  bridge_state_e state_q, state_d;

  dmi_op_e req_op;
  logic    req_is_nop;

  assign req_op      = dmi_op_e'(req_latch_i[DMI_REQ_OP_LSB +: DMI_OP_W]);
  assign dm_wdata_o   = req_latch_i[DMI_REQ_DATA_LSB +: DMI_DATA_W];
  assign dm_addr_o     = req_latch_i[DMI_REQ_ADDR_LSB +: DMI_ABITS];
  assign req_is_nop  = (req_op == DMI_OP_NOP);

  always_comb begin
    state_d = state_q;                 // R-C3: default before case
    unique case (state_q)
      S_IDLE:      if (core_req_valid)  state_d = req_is_nop ? S_COMPLETED : S_ACCESS;
      S_ACCESS:    if (dm_ready_i)      state_d = S_COMPLETED;
      S_COMPLETED: if (!core_req_valid) state_d = S_IDLE;
      default:                          state_d = S_IDLE;
    endcase
  end

  always_ff @(posedge clk_i or negedge core_rst_n) begin
    if (!core_rst_n) state_q <= S_IDLE;
    else              state_q <= state_d;
  end

  assign dm_read_o  = (state_q == S_ACCESS) && (req_op == DMI_OP_READ);
  assign dm_write_o = (state_q == S_ACCESS) && (req_op == DMI_OP_WRITE);

  logic resp_valid;
  assign resp_valid = (state_q == S_COMPLETED);
  assign resp_valid_async_o = resp_valid;

  // One-time capture on the transition edge into COMPLETED; status is
  // hardwired to success (no dm_error input exists on this interface).
  logic [DMI_RESP_W-1:0] resp_reg_q;

  always_ff @(posedge clk_i or negedge core_rst_n) begin
    if (!core_rst_n) begin
      resp_reg_q <= '0;
    end else if ((state_q == S_ACCESS) && dm_ready_i) begin
      resp_reg_q <= {dm_rdata_i, DMI_STATUS_SUCCESS};
    end else if ((state_q == S_IDLE) && core_req_valid && req_is_nop) begin
      resp_reg_q <= '0;
    end
  end

  assign resp_data_o = resp_reg_q;

endmodule : meds_s1_dmi_core_if
