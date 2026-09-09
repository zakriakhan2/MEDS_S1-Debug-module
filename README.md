# RISC-V JTAG Debug Module Interface (DMI) Bridge

<div align="center">
  <h3><strong>Hardware implementation of a Debug Transport Module (DTM) and DMI Bridge</strong></h3>
</div>

## 📌 Overview
This repository contains the hardware implementation of a synchronization and communication interface between the IEEE 1149.1 standard JTAG (`TCK`) clock domain and the internal RISC-V processor Core clock domain. Designed in SystemVerilog, this bridge strictly adheres to the **RISC-V External Debug Support Specification**, handling asynchronous clock boundary crossings, serial-to-parallel translation, and processor bus handshaking.

---

## 🏗️ System Architecture

The DMI Bridge is split into two primary asynchronous clock domains:

### 1. JTAG / TCK Domain
Handles the standard 16-state TAP (Test Access Port) Controller and serial data routing.
*   **TDI (Test Data In):** A 1-bit serial input line broadcast to all shift registers. Data is sampled on the **rising edge** of `TCK`.
*   **TDO (Test Data Out):** A 1-bit serial output line. Output bits are updated on the **falling edge** of `TCK` to meet strict setup/hold times and prevent data corruption across a JTAG daisy chain.
*   **MUX Controller:** A central multiplexer routes the active register's serial output to the `TDO` pin based on decoded instruction `Sel_*` lines or the `Shift_IR` state override.

### 2. Core Clock Domain
Handles the execution of read/write commands to the internal processor Debug Module via a highly optimized 3-state Mealy finite state machine (FSM).

---

## 🗺️ Register Map

The design implements parallel-load shift registers sized according to JTAG and RISC-V specifications.

| Register | Width | Opcode (IR) | Description |
| :--- | :---: | :---: | :--- |
| **Instruction (IR)** | 5-bit | N/A | Captures 5-bit opcodes to drive the `Sel_*` instruction decoder lines. |
| **IDCODE** | 32-bit | `0x01` | Hardcoded 32-bit manufacturer and part identification number. |
| **DTMCS** | 32-bit | `0x10` | Debug Transport Module Control and Status flags. |
| **DMI** | 41-bit | `0x11` | Main interface register for capturing requests and emitting responses. |
| **BYPASS** | 1-bit | `0x1F` | Standard 1-cycle minimum delay path for bypassing the chip. |

---

## 📦 DMI Packet Specification

Communication with the core utilizes an asymmetrical packet design to optimize serial bandwidth.

### Request Packet (41-bit `dmi_req`)
Shifted *into* the DMI register from the JTAG debugger:
*   `[40:39]` **op:** 2-bit operation command (`00`=NOP, `01`=Read, `10`=Write).
*   `[38:7]` **data:** 32-bit payload data for write operations.
*   `[6:0]` **addr:** 7-bit destination address inside the internal Debug Module.

### Response Packet (34-bit `dmi_resp`)
Shifted *out* to the JTAG debugger after core execution:
*   `[33:2]` **data:** 32-bit payload data returned from a read operation.
*   `[1:0]` **status:** 2-bit completion status (`00`=Success, `10`=Failed, `11`=Busy).

---

## ⚙️ Core Domain Control (Mealy FSM)

The processor-side interface relies on a 3-state Mealy state machine. Using a Mealy architecture allows the bridge to drive the internal bus signals (`dm_read`, `dm_write`) immediately upon entering the `ACCESS` state by combinatorially decoding the request payload.

### FSM State Definitions
*   **`IDLE`**: The resting state. Transitions to `ACCESS` when `core_req_valid` is asserted high by the JTAG domain.
*   **`ACCESS`**: Decodes the operation and drives the core bus. Remains here until the core asserts `dm_ready`.
*   **`COMPLETE`**: Asserts `resp_valid` to latch the 34-bit response packet. Returns to `IDLE` once `core_req_valid` falls low to close the asynchronous handshake loop.

### SystemVerilog Implementation Snippet

```systemverilog
typedef enum logic [1:0] {
    IDLE     = 2'b00,
    ACCESS   = 2'b01,
    COMPLETE = 2'b10
} state_t;

state_t current_state, next_state;

always_comb begin
    // Default assignments to prevent latches
    next_state = current_state;
    dm_read    = 1'b0;
    dm_write   = 1'b0;
    resp_valid = 1'b0;
    
    case (current_state)
        IDLE: begin
            if (core_req_valid) begin
                next_state = ACCESS;
            end
        end
        
        ACCESS: begin
            // Mealy outputs: Drive bus based on requested operation
            dm_read  = (req_op == 2'b01);
            dm_write = (req_op == 2'b10);
            
            // Wait for internal Debug Module to acknowledge
            if (dm_ready) begin
                next_state = COMPLETE;
            end
        end
        
        COMPLETE: begin
            // Signal back to JTAG domain that response is ready
            resp_valid = 1'b1;
            
            // Wait for JTAG domain to clear the request
            if (!core_req_valid) begin
                next_state = IDLE;
            end
        end
    endcase
end
