# rtl/debug — DTM / DMI

JTAG Debug Transport Module (DTM) and DMI clock-domain-crossing bridge for
the custom RISC-V core, implemented per the RISC-V External Debug Support
Specification and the project's `BlockDiagram DTM` / `DataPathDTM` /
`BlockDiagram DMI` / `FSM DMI` / `DatapathDiagram DMI` design diagrams.

This block covers **DTM and DMI only**. The Debug Module (DM) itself is out
of scope and is treated as a black box behind `dm_addr_o` / `dm_wdata_o` /
`dm_write_o` / `dm_read_o` / `dm_rdata_i` / `dm_ready_i`.

---

## 1. Directory contents

| File | Domain | Status |
|---|---|---|
| `s1_pkg.sv` | n/a (package) | [WIP -- dtm-01] |
| `rtl/common/meds_s1_cdc_2ff.sv` | destination clk only | [COMPLETE -- REFERENCE] |
| `rtl/common/meds_s1_cdc_toggle_src.sv` | source clk only | [COMPLETE -- REFERENCE] |
| `rtl/common/meds_s1_cdc_toggle_dst.sv` | destination clk only | [COMPLETE -- REFERENCE] |
| `rtl/common/meds_s1_dmi_rst_gen.sv` | single clk | [COMPLETE -- REFERENCE] |
| `rtl/debug/meds_s1_dtm_tap.sv` | tck | [WIP -- dtm-01] |
| `rtl/debug/meds_s1_dtm_dr_regs.sv` | tck | [WIP -- dtm-01] |
| `rtl/debug/meds_s1_dmi_tck_if.sv` | tck | [WIP -- dtm-01] |
| `rtl/debug/meds_s1_dmi_core_if.sv` | core_clk | [WIP -- dtm-01] |
| `rtl/debug/meds_s1_dtm_top.sv` | both (structural only) | [WIP -- dtm-01] |

### What does not live here
- The Debug Module (DM) — a separate, not-yet-written block.
- Generic CDC synchronizers belong in `rtl/common/`, not `rtl/debug/`, since
  they are reusable across the SoC (R-C9).

### How to add something
New debug-infrastructure RTL should get its own directory with its own
README and compose with `meds_s1_dtm_top`, rather than being folded into
this one. Any new cross-domain signal must go through an existing
`rtl/common/` synchronizer — do not hand-roll a new 2-flop or toggle
synchronizer inline (R-C9).

---

## 2. Build / lint / simulate

### Project-standard flow
```bash
make check      # structure + lint (scripts/check_structure.py + linter)
make test-unit  # runs verif/unit/tb_<module>.sv testbenches
```

### Standalone elaboration (until the above Makefile targets are wired up
for this block)
Compile in dependency order — the package first, then the common
synchronizers, then the DTM/DMI modules, with the top-level last:

```
s1_pkg.sv
rtl/common/meds_s1_cdc_2ff.sv
rtl/common/meds_s1_cdc_toggle_src.sv
rtl/common/meds_s1_cdc_toggle_dst.sv
rtl/common/meds_s1_dmi_rst_gen.sv
rtl/debug/meds_s1_dtm_tap.sv
rtl/debug/meds_s1_dtm_dr_regs.sv
rtl/debug/meds_s1_dmi_tck_if.sv
rtl/debug/meds_s1_dmi_core_if.sv
rtl/debug/meds_s1_dtm_top.sv
```

Example with Verilator (lint-only, no testbench):
```bash
verilator --lint-only -Wall --timing \
  s1_pkg.sv \
  rtl/common/meds_s1_cdc_2ff.sv \
  rtl/common/meds_s1_cdc_toggle_src.sv \
  rtl/common/meds_s1_cdc_toggle_dst.sv \
  rtl/common/meds_s1_dmi_rst_gen.sv \
  rtl/debug/meds_s1_dtm_tap.sv \
  rtl/debug/meds_s1_dtm_dr_regs.sv \
  rtl/debug/meds_s1_dmi_tck_if.sv \
  rtl/debug/meds_s1_dmi_core_if.sv \
  rtl/debug/meds_s1_dtm_top.sv \
  --top-module meds_s1_dtm_top
```

Example with a generic `vlog` (ModelSim/Questa-style) flow:
```bash
vlog -sv s1_pkg.sv
vlog -sv rtl/common/meds_s1_cdc_2ff.sv rtl/common/meds_s1_cdc_toggle_src.sv \
          rtl/common/meds_s1_cdc_toggle_dst.sv rtl/common/meds_s1_dmi_rst_gen.sv
vlog -sv rtl/debug/meds_s1_dtm_tap.sv rtl/debug/meds_s1_dtm_dr_regs.sv \
          rtl/debug/meds_s1_dmi_tck_if.sv rtl/debug/meds_s1_dmi_core_if.sv \
          rtl/debug/meds_s1_dtm_top.sv
vsim meds_s1_dtm_top
```

These commands are provided as a starting point; they have not been run
against your actual toolchain/Makefile, so file paths and flags may need
adjusting to match your repo layout.

### Known gaps against the standard (not yet done)
- **No testbenches yet.** R-V1/V3/V4/V5 require `verif/unit/tb_<module>.sv`
  for each module above, printing `=== PASS : <n> checks ===` and using
  `$urandom`. Section 8 of the coding standard blocks PRs without these.
- **No `docs/modules/*.md` pages yet (R-D3)** — blocked on a copy of
  `docs/modules/TEMPLATE.md`, which has not been supplied.
- **SPDX identifier is a placeholder.** Every file currently carries
  `// SPDX-License-Identifier: Apache-2.0`; confirm or correct this against
  the project's actual license.
- **Project-id placeholder.** All status tags/commit-subject examples use
  `dtm-01`; replace with the real tracker ID once assigned.

---

## 3. Shared package: `s1_pkg.sv`

Holds every DTM/DMI constant and type so no RTL file below contains a
magic number (R-C7) and so modules that must agree on a bus shape get that
shape from one place (R-C8).

| Name | Value / meaning |
|---|---|
| `DTM_IR_W` | 5 — instruction register width |
| `DTM_DTMCS_W`, `DTM_IDCODE_W` | 32 each |
| `DMI_ABITS` | 7 — `dm_addr` width |
| `DMI_DATA_W` | 32 — `dm_wdata`/`dm_rdata` width |
| `DMI_OP_W` | 2 — request op / response status width |
| `DMI_REQ_W` | 41 = `DMI_ABITS + DMI_DATA_W + DMI_OP_W` |
| `DMI_RESP_W` | 34 = `DMI_DATA_W + DMI_OP_W` |
| `DTM_IR_IDCODE/DTMCS/DMI/BYPASS` | 5-bit IR opcodes (`00001`/`10000`/`10001`/`11111`) |
| `DTM_IR_RESET_VAL` | IR value after reset = `DTM_IR_IDCODE` |
| `DTM_IR_CAPTURE_VAL` | fixed Capture-IR pattern `00001` (satisfies 1149.1's mandatory `[1:0]==01`) |
| `DTMCS_*_LSB` / `DTMCS_*_BIT` | bit positions of each DTMCS field (version, abits, dmistat, idle, dmireset, dmihardreset) |
| `dmi_op_e` | `DMI_OP_NOP (00)` / `DMI_OP_READ (01)` / `DMI_OP_WRITE (10)` |
| `dmi_status_e` | `DMI_STATUS_SUCCESS (00)` / `DMI_STATUS_FAILED (10)` / `DMI_STATUS_BUSY (11)` |
| `DMI_REQ_ADDR_LSB/DATA_LSB/OP_LSB` | bit-slice offsets into the 41-bit request |
| `DMI_RESP_DATA_LSB/STATUS_LSB` | bit-slice offsets into the 34-bit response |
| `DTM_IDCODE_DEFAULT` | placeholder 32-bit IDCODE, override via module parameter |

**Bit layout** (LSB shifts out to TDO first, per spec):
```
DMI request  (41b): [40:34] addr | [33:2] wdata | [1:0] op
DMI response (34b): [33:2]  rdata | [1:0] status
```

---

## 4. `rtl/common/meds_s1_cdc_2ff.sv` — generic 2-flop synchronizer

**Status:** [COMPLETE -- REFERENCE]
**Clock/reset:** destination domain's `clk_i`/`rst_ni` only.

Parameterized-width (`WIDTH`) double-flop metastability synchronizer for
**level** (held) signals. Two-cycle latency. Not valid for single-cycle
pulses narrower than the destination clock period — use the toggle pair
below for those. Used throughout the DTM/DMI block instead of hand-rolled
flops, per R-C9.

| Port | Dir | Width | Meaning |
|---|---|---|---|
| `clk_i`, `rst_ni` | in | 1 | destination-domain clock/reset |
| `async_i` | in | `WIDTH` | asynchronous source-domain input |
| `sync_o` | out | `WIDTH` | synchronized, destination-domain output |

---

## 5. `rtl/common/meds_s1_cdc_toggle_src.sv` + `..._dst.sv` — rate-independent pulse sync

**Status:** [COMPLETE -- REFERENCE]
**Clock/reset:** each module is single-domain (R-N6); `_src` runs on the
source clock, `_dst` runs on the destination clock.

Together these replace a plain level synchronizer for signals that must
never be missed regardless of the clk ratio between domains (e.g. a core
clock that has been scaled down far below `tck`). `_src` flips an internal
toggle bit on every `pulse_i`. `_dst` internally instantiates
`meds_s1_cdc_2ff` to synchronize that toggle bit, then edge-detects it to
regenerate exactly one `pulse_o`-wide pulse per source-side toggle event.

`meds_s1_cdc_toggle_src`:
| Port | Dir | Meaning |
|---|---|---|
| `clk_i`, `rst_ni` | in | source-domain clock/reset |
| `pulse_i` | in | single-cycle source-domain pulse to cross |
| `toggle_o` | out | toggle bit, async to the destination domain |

`meds_s1_cdc_toggle_dst`:
| Port | Dir | Meaning |
|---|---|---|
| `clk_i`, `rst_ni` | in | destination-domain clock/reset |
| `toggle_i` | in | toggle bit from `_src` |
| `pulse_o` | out | single destination-clock-wide pulse, one per source event |

---

## 6. `rtl/common/meds_s1_dmi_rst_gen.sv` — reset generator

**Status:** [COMPLETE -- REFERENCE]
**Clock/reset:** single domain.

Produces a clean, glitch-free active-low reset: **async assert / sync
de-assert** (R-C4), asserted whenever the external `rst_ni` is low *or*
`hardreset_pulse_i` (already synchronized into this clock domain) fires.
Exists so that no consuming module ever generates reset logic inline —
R-C4 explicitly forbids "local reset generation inside a leaf module"; this
is the one shared, auditable place that logic lives.

| Port | Dir | Meaning |
|---|---|---|
| `clk_i` | in | clock |
| `rst_ni` | in | external async active-low reset |
| `hardreset_pulse_i` | in | single-cycle pulse requesting an extra reset event |
| `rst_no` | out | combined, cleanly de-asserted active-low reset |

---

## 7. `rtl/debug/meds_s1_dtm_tap.sv` — TAP controller + IR + decoder

**Status:** [WIP -- dtm-01]
**Clock/reset:** `clk_i` = `tck`, `rst_ni` = `trst_ni` (async).

Standard IEEE 1149.1 16-state TAP FSM, a 5-bit instruction register, and
the instruction decoder (BYPASS/DTMCS/DMI/IDCODE select lines).

**Behavior:**
- FSM state register and all shift/capture activity update on `posedge
  clk_i`; the FSM's `capture_dr_o`/`shift_dr_o`/`update_dr_o` and IR
  equivalents are pure Moore decodes of the current state.
- The IR shift register (`ir_shift_q`) captures the fixed pattern
  `DTM_IR_CAPTURE_VAL` on Capture-IR and shifts `tdi_i` in on Shift-IR.
- The IR "update"/architectural register (`ir_reg`, what the decoder
  reads) latches on `negedge clk_i`, so it settles before the next rising
  edge, consistent with TDO changing on the falling edge.
- Any IR value other than IDCODE/DTMCS/DMI (including the literal BYPASS
  opcode and any reserved/unimplemented encoding) decodes to
  `sel_bypass_o`.
- `ir_shift_tdo_o` exposes the IR shift register's LSB so the central TDO
  mux in `meds_s1_dtm_dr_regs` can route it during Shift-IR, since IR and
  DR share one physical serial path to TDO.

| Port | Dir | Meaning |
|---|---|---|
| `clk_i`, `rst_ni` | in | tck / trst_ni |
| `tms_i`, `tdi_i` | in | JTAG inputs |
| `capture_dr_o`/`shift_dr_o`/`update_dr_o` | out | DR control strobes |
| `shift_ir_o`, `ir_shift_tdo_o` | out | IR shift strobe + serial-out bit |
| `sel_bypass_o`/`sel_dtmcs_o`/`sel_dmi_o`/`sel_idcode_o` | out | one-hot instruction decode |

---

## 8. `rtl/debug/meds_s1_dtm_dr_regs.sv` — DR data path

**Status:** [WIP -- dtm-01]
**Clock/reset:** `clk_i` = `tck`, `rst_ni` = `trst_ni`.

BYPASS (1b), DTMCS (32b), IDCODE (32b, parameterized value), and the
unified DMI (41b) shift registers, the `dmistat` sticky error tracker, the
response hold register, and the central TDO mux + output flop.

**Behavior:**
- All four shift registers share one hold-mux rule: update only on
  `(sel_x && capture_dr_i)` [parallel load] or `(sel_x && shift_dr_i)`
  [serial shift]; otherwise retain value.
- **DTMCS** capture value always reads `dmireset`/`dmihardreset` back as
  `0` per spec. Both fields are derived combinationally from the *stable*
  shift-register contents, gated to exactly the `update_dr_i` cycle — no
  literal 32-bit "update FF" is built for two write-1-to-trigger bits.
- **`dmistat`** (2 bits) is a sticky, first-error-wins flag: cleared by
  `dmireset`/`dmihardreset`; otherwise set once to `BUSY (11)` on an
  overrun (`update_dr_i && sel_dmi_i && req_pending_i`) or to `FAILED
  (10)` on a failed response (detected via a local `tck_ack_i` rising-edge
  detector); never touched by a success response. While `dmistat != 0`,
  all new DMI requests are silently dropped (see `dmi_req_trigger_o`
  below) and Capture_DR loads the sticky status in place of the real
  response.
- **`dmi_resp_hold_q`** latches the incoming 34-bit response on the rising
  edge of `tck_ack_i` and holds it indefinitely, so Capture_DR sees a
  stable value no matter how many `clk_i` cycles pass before the debugger
  actually performs the capture.
- **DMI register capture:** on `sel_dmi_i && capture_dr_i`, bits `[33:0]`
  load either the held response or the sticky `dmistat` (status-only, data
  zeroed); bits `[40:34]` (address) are never written in that branch, so
  they hold their last-shifted value by construction.
- **`dmi_req_trigger_o`** pulses for exactly one `clk_i` cycle
  (`update_dr_i`'s width) only when `dmistat_q == SUCCESS` and
  `!req_pending_i` — i.e. a clean Update_DR with no error latched and no
  transaction already in flight. This is the only way a request reaches
  `meds_s1_dmi_tck_if`; a blocked request is dropped here and never
  crosses the clock boundary.
- **Central TDO mux**: `shift_ir_i` takes priority over the DR `sel_*`
  lines, since those still reflect the *previous* instruction while a new
  one is being shifted in.

| Port | Dir | Meaning |
|---|---|---|
| `clk_i`, `rst_ni`, `tdi_i` | in | tck domain inputs |
| `capture_dr_i`/`shift_dr_i`/`update_dr_i` | in | from `meds_s1_dtm_tap` |
| `shift_ir_i`, `ir_shift_tdo_i` | in | from `meds_s1_dtm_tap` |
| `sel_bypass_i`/`sel_dtmcs_i`/`sel_dmi_i`/`sel_idcode_i` | in | from `meds_s1_dtm_tap` |
| `stable_dmi_resp_i` | in | 34b response bus from `meds_s1_dmi_core_if` (quasi-static) |
| `tck_ack_i` | in | synchronized ack level from `meds_s1_dmi_tck_if` |
| `req_pending_i` | in | from `meds_s1_dmi_tck_if`, gates `dmi_req_trigger_o` |
| `tdo_o` | out | physical TDO pin |
| `stable_dmi_req_o` | out | live 41b DMI shift-register contents |
| `dmi_req_trigger_o` | out | 1-cycle "accept this request" pulse |
| `dmihardreset_pulse_o` | out | 1-cycle pulse, tck domain |

Parameter: `IDCODE_VALUE` (default `s1_pkg::DTM_IDCODE_DEFAULT`).

---

## 9. `rtl/debug/meds_s1_dmi_tck_if.sv` — TCK-domain CDC half

**Status:** [WIP -- dtm-01]
**Clock/reset:** `clk_i` = `tck`, `rst_ni` = `trst_ni`.

Owns the 4-phase handshake's initiator state, the request snapshot
register, and the hardreset toggle source.

**Behavior:**
- Internally instantiates `meds_s1_cdc_2ff` to synchronize the raw
  `resp_valid_async_i` from `meds_s1_dmi_core_if` into `tck_ack_o` — the
  synchronizer for a given signal always lives in the *receiving* domain's
  module, per R-N6.
- `dmi_req_valid_q` (exported as `req_valid_o`) is set by `req_trigger_i`
  and cleared as soon as the synchronized `tck_ack` is seen high.
- `req_pending_o = dmi_req_valid_q | tck_ack` — covers the **entire**
  round trip, not just the request half. Without the `tck_ack` term, a new
  request could be accepted while the previous ack is still unwinding
  through the synchronizer on the other side, wedging the Bridge FSM
  permanently in `COMPLETED`.
- `req_latch_q` (exported as `req_latch_o`) snapshots `dmi_req_i` at the
  instant `req_trigger_i` fires, so a debugger continuing to shift the DMI
  register mid-transaction cannot mutate an in-flight address/data.
- The hardreset pulse is handed to `meds_s1_cdc_toggle_src` rather than a
  plain level synchronizer, so it survives even if `core_clk` is far
  slower than `tck`.

| Port | Dir | Meaning |
|---|---|---|
| `clk_i`, `rst_ni` | in | tck / trst_ni |
| `dmi_req_i` | in | live 41b DMI register contents, from `meds_s1_dtm_dr_regs` |
| `req_trigger_i` | in | 1-cycle "accept" pulse, from `meds_s1_dtm_dr_regs` |
| `hardreset_pulse_i` | in | 1-cycle pulse, from `meds_s1_dtm_dr_regs` |
| `resp_valid_async_i` | in | raw core-domain `resp_valid`, async |
| `req_pending_o` | out | to `meds_s1_dtm_dr_regs`, gates `dmi_req_trigger_o` there |
| `tck_ack_o` | out | synchronized ack level |
| `req_latch_o` | out | stable 41b snapshot, to `meds_s1_dmi_core_if` |
| `req_valid_o` | out | handshake level, async to `meds_s1_dmi_core_if`'s synchronizer |
| `hardreset_toggle_o` | out | to `meds_s1_cdc_toggle_dst` in `meds_s1_dmi_core_if` |

---

## 10. `rtl/debug/meds_s1_dmi_core_if.sv` — core_clk-domain CDC half + Bridge FSM

**Status:** [WIP -- dtm-01]
**Clock/reset:** `clk_i` = `core_clk`, `rst_ni` = `dmi_rst_ni` (external,
raw).

Owns the request-valid receive synchronizer, the hardreset toggle
receiver + derived reset, and the Bridge FSM that drives the DM interface.

**Behavior:**
- Instantiates `meds_s1_cdc_toggle_dst` (fed with the **raw** `rst_ni`,
  not the derived reset below — using the derived reset here would be
  circular, since it depends on this chain's output) to recover a clean
  `hardreset_pulse` in the core domain.
- Instantiates `meds_s1_dmi_rst_gen` to combine the raw external reset
  with `hardreset_pulse` into `core_rst_n`, which every *other* flop in
  this module uses (R-C4: the derived reset comes from a shared module,
  not inline logic).
- Instantiates `meds_s1_cdc_2ff` to synchronize `req_valid_async_i` into
  `core_req_valid`.
- **Bridge FSM** (`S_IDLE -> S_ACCESS -> S_COMPLETED -> S_IDLE`):
  - `S_IDLE -> S_ACCESS` on `core_req_valid`, **unless** the latched
    request's op is `DMI_OP_NOP`, in which case it goes directly to
    `S_COMPLETED` (NOP fast-path) — a plain DM interface with no error
    path has no reason to ever assert `dm_ready_i` for a request it was
    never asked to perform, so NOPs are terminated without touching the DM.
  - `S_ACCESS -> S_COMPLETED` on `dm_ready_i`.
  - `S_COMPLETED -> S_IDLE` once `core_req_valid` drops (the far side of
    the 4-phase handshake unwinding).
  - `dm_read_o`/`dm_write_o` are driven combinationally throughout
    `S_ACCESS` from the latched request's op field — the request is
    already guaranteed stable for the whole transaction by the TCK-domain
    snapshot register, so no extra holding register is needed here.
  - `resp_valid_async_o` is high for the entire `S_COMPLETED` state.
  - The 34-bit response register captures once, on the transition edge
    into `S_COMPLETED` (either `{dm_rdata_i, SUCCESS}` on a real access,
    or all-zero on a NOP), then holds statically for the rest of that
    state. Status is hardwired to `SUCCESS` since this interface has no
    `dm_error` input.
- `resp_data_o` crosses back to the TCK domain as a **quasi-static bus**,
  not synchronized bit-by-bit — it is only sampled by
  `meds_s1_dtm_dr_regs` once `tck_ack_i` (which *is* properly
  synchronized) confirms it is stable.

| Port | Dir | Meaning |
|---|---|---|
| `clk_i`, `rst_ni` | in | core_clk / dmi_rst_ni (raw, external) |
| `req_latch_i` | in | stable 41b request snapshot, from `meds_s1_dmi_tck_if` |
| `req_valid_async_i` | in | handshake level, async |
| `hardreset_toggle_i` | in | from `meds_s1_dmi_tck_if` |
| `resp_valid_async_o` | out | handshake level, async to `meds_s1_dmi_tck_if`'s synchronizer |
| `resp_data_o` | out | 34b response bus, quasi-static |
| `dm_addr_o`/`dm_wdata_o`/`dm_write_o`/`dm_read_o` | out | to the DM |
| `dm_rdata_i`/`dm_ready_i` | in | from the DM |

---

## 11. `rtl/debug/meds_s1_dtm_top.sv` — structural top

**Status:** [WIP -- dtm-01]
**Clock/reset:** both domains meet here only as port-level wiring between
the single-domain leaf modules above; this file contains no logic of its
own.

Instantiates `meds_s1_dtm_tap`, `meds_s1_dtm_dr_regs`,
`meds_s1_dmi_tck_if` and `meds_s1_dmi_core_if` and wires them together
exactly per the signal names documented in sections 7–10 above.

| Port | Dir | Domain | Meaning |
|---|---|---|---|
| `tck_i`, `trst_ni`, `tms_i`, `tdi_i` | in | tck | JTAG pins |
| `tdo_o` | out | tck | JTAG pin |
| `core_clk_i`, `dmi_rst_ni` | in | core_clk | clock/reset |
| `dm_addr_o`/`dm_wdata_o`/`dm_write_o`/`dm_read_o` | out | core_clk | to the DM |
| `dm_rdata_i`/`dm_ready_i` | in | core_clk | from the DM |

Parameter: `IDCODE_VALUE`, forwarded to `meds_s1_dtm_dr_regs`.

---

## 12. Design-diagram cross-reference

| Diagram | What it became |
|---|---|
| `BlockDiagram DTM` | `meds_s1_dtm_tap.sv` (TAP/IR/decoder) + the mux/TDO portion of `meds_s1_dtm_dr_regs.sv` |
| `DataPathDTM` | the 3:1-mux/Shift-FF/Update-FF structure in `meds_s1_dtm_dr_regs.sv`; settled the DMI register as one unified 41-bit bidirectional shift register (not two separate shifters) |
| `BlockDiagram DMI` | `meds_s1_dmi_tck_if.sv` + `meds_s1_dmi_core_if.sv` (the CDC bridge, now split per R-N6) |
| `FSM DMI` | the Bridge FSM in `meds_s1_dmi_core_if.sv`, with one deliberate addition: the NOP fast-path (not drawn, added during design review) |
| `DatapathDiagram DMI` | superseded in part: its bus-splitter field ordering and its separate 34-bit output shifter were both corrected against the spec text during design review (see `s1_pkg.sv`'s bit-layout comment) |

