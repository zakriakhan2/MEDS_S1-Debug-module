// SPDX-License-Identifier: Apache-2.0
//
// meds_s1_dmi_rst_gen.sv
// [COMPLETE -- REFERENCE]
//
// Shared reset generator: async assert, sync de-assert, active-low (R-C4).
// Asserts rst_no whenever the external reset is asserted OR a single-cycle
// hardreset_pulse_i fires, then releases it two clk_i cycles later so every
// downstream flop sees a clean, glitch-free de-assert edge.
//
// Exists specifically so consuming modules never generate reset logic
// locally (R-C4 explicitly forbids that) -- they simply instantiate this
// and use rst_no like any ordinary reset.

module meds_s1_dmi_rst_gen (
  input  logic clk_i,
  input  logic rst_ni,             // external async active-low reset
  input  logic hardreset_pulse_i,  // single clk_i-wide pulse, already synchronized
  output logic rst_no
);

  logic rst_assert_n;
  assign rst_assert_n = rst_ni & ~hardreset_pulse_i;

  logic sync1_q, sync2_q;

  always_ff @(posedge clk_i or negedge rst_assert_n) begin
    if (!rst_assert_n) begin
      sync1_q <= 1'b0;
      sync2_q <= 1'b0;
    end else begin
      sync1_q <= 1'b1;
      sync2_q <= sync1_q;
    end
  end

  assign rst_no = sync2_q;

endmodule : meds_s1_dmi_rst_gen
