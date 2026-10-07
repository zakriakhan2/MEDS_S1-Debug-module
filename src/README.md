# rtl/debug — DTM / DMI

JTAG Debug Transport Module and DMI bridge for the custom RISC-V core, per
the RISC-V External Debug Support Specification and `docs/design/dtm_*`
(block/datapath diagrams, FSM diagram).

## What lives here

| File | Domain | Status |
|---|---|---|
| `meds_s1_dtm_tap.sv` | tck | [WIP -- dtm-01] |
| `meds_s1_dtm_dr_regs.sv` | tck | [WIP -- dtm-01] |
| `meds_s1_dmi_tck_if.sv` | tck | [WIP -- dtm-01] |
| `meds_s1_dmi_core_if.sv` | core_clk | [WIP -- dtm-01] |
| `meds_s1_dtm_top.sv` | both (structural only) | [WIP -- dtm-01] |

Shared CDC primitives used by the above live in `rtl/common/` instead
(`meds_s1_cdc_2ff.sv`, `meds_s1_cdc_toggle_src.sv`,
`meds_s1_cdc_toggle_dst.sv`, `meds_s1_dmi_rst_gen.sv`), per R-C9 — they are
reusable across the SoC and are not debug-specific.

DTM/DMI widths, encodings, IR opcodes and DTMCS field positions live in
`s1_pkg.sv` (R-C7/R-C8), not in these files.

## What does not live here

- The Debug Module (DM) itself — out of scope for this block. `dm_addr_o`
  / `dm_wdata_o` / `dm_write_o` / `dm_read_o` / `dm_rdata_i` / `dm_ready_i`
  are the boundary; the DM is a black box from this directory's point of
  view.
- Generic CDC synchronizers — see `rtl/common/` above.

## How to add something

New debug-infrastructure RTL (e.g. a future DM) should get its own
directory with its own README, instantiating and composing with
`meds_s1_dtm_top` rather than being folded into this one. Any new
cross-domain signal added to the tck_if/core_if split must go through an
existing `rtl/common/` synchronizer (R-C9) — do not hand-roll a new
2-flop or toggle synchronizer inline.

## Status

Reviewed against the RISC-V External Debug Support Specification and the
project's design diagrams; not yet simulated. See `verif/unit/` for the
per-module testbenches required by R-V1.
