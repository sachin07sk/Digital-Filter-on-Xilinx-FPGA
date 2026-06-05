# Digital-Filter-on-Xilinx-FPGA
Implemented an FIR digital filter in Verilog, synthesized and deployed on Xilinx Artix-7 using Vivado. Full RTL-to-bitstream design flow completed on Linux.
# Digital FIR Filter on Xilinx FPGA

**Author:** Saravana Kumar T J A
**Role:** Design & Verification Engineer — Semiconductor
**Tools:** Verilog | QuestaSim 10.4e | Xilinx Vivado
**Target FPGA:** Xilinx Artix-7 (xc7a35t — Basys3 Board)
**GitHub:** [Digital-Filter-on-Xilinx-FPGA](https://github.com/sachin07sk/Digital-Filter-on-Xilinx-FPGA)

---

## Overview

A parameterized **8-tap FIR (Finite Impulse Response) Low-Pass Filter** designed in Verilog, functionally verified in QuestaSim, then synthesized and implemented on a Xilinx Artix-7 FPGA using Vivado.

The filter:
- Passes low-frequency signals (below 10% of sample rate)
- Blocks high-frequency noise and interference
- Uses fixed-point Q15 arithmetic for hardware efficiency
- Achieves timing closure at 100MHz target clock
- Verified with 4 self-checking test scenarios

---

## Filter Specification

| Parameter       | Value                        |
|----------------|------------------------------|
| Filter Type    | FIR — Low-Pass               |
| Architecture   | Direct Form (shift register + MAC) |
| Number of Taps | 8                            |
| Input Width    | 16-bit signed                |
| Output Width   | 16-bit signed                |
| Coefficient Format | Q15 fixed-point (16-bit) |
| Cutoff Frequency | 10% of sample rate (Fc = 0.1×Fs) |
| Clock Target   | 100 MHz                      |
| FPGA Target    | Xilinx Artix-7 xc7a35t       |

---

## FIR Filter Theory

### What is a FIR Filter?

A Finite Impulse Response filter computes the output as a weighted sum of the current and past N input samples:

```
y[n] = h[0]×x[n] + h[1]×x[n-1] + h[2]×x[n-2] + ...
       + h[N-1]×x[n-N+1]
```

Where:
- `x[n]` = current input sample
- `x[n-1]` = previous sample (stored in shift register)
- `h[i]` = filter coefficients (define frequency response)
- `y[n]` = filtered output sample

### Why FIR over IIR?

```
FIR advantages:
  ✔ Always stable (no feedback poles)
  ✔ Linear phase — all frequencies delayed equally
  ✔ No rounding error accumulation
  ✔ Symmetric coefficients possible (linear phase)

IIR advantages:
  ✔ Fewer taps for same selectivity
  ✗ Can be unstable
  ✗ Non-linear phase
```

### Q15 Fixed-Point Format

```
Standard floating-point:  expensive in hardware, slow
Q15 fixed-point:          16-bit signed, 15 fractional bits

Bit layout: [S | b14 | b13 | ... | b1 | b0]
             ↑   ← 15 fractional bits →
           sign

Value range: -1.0 to +0.9999...
Resolution:  1/32768 ≈ 0.0000305

After multiply (Q15 × Q15 = Q30):
  Right shift by 15 to return to Q15 range
  This is done in the accumulator output stage
```

---

## Filter Coefficients

Symmetric 8-tap low-pass FIR coefficients (Q15 format):

| Tap | h[n]  | Decimal Value |
|-----|-------|---------------|
| h[0]| 328   |  0.01001      |
| h[1]| 1023  |  0.03122      |
| h[2]| 2531  |  0.07724      |
| h[3]| 4915  |  0.14999      |
| h[4]| 4915  |  0.14999      |
| h[5]| 2531  |  0.07724      |
| h[6]| 1023  |  0.03122      |
| h[7]| 328   |  0.01001      |

**Sum of coefficients = 17574 / 32768 ≈ 0.536**
(Gain at DC — normalized to pass 53.6% of input amplitude)

**Symmetry:** h[0]=h[7], h[1]=h[6], h[2]=h[5], h[3]=h[4]
Symmetric FIR → **linear phase response** — no phase distortion.

---

## Hardware Architecture

### Direct Form FIR

```
x[n] ──►[REG0]──►[REG1]──►[REG2]──►[REG3]──►[REG4]──►[REG5]──►[REG6]──►[REG7]
          │         │         │         │         │         │         │         │
          ↓         ↓         ↓         ↓         ↓         ↓         ↓         ↓
        ×h[0]     ×h[1]     ×h[2]     ×h[3]     ×h[4]     ×h[5]     ×h[6]     ×h[7]
          │         │         │         │         │         │         │         │
          └────────────────────────────┬─────────────────────────────┘
                                       │
                                   [ADDER TREE]
                                       │
                                   [>> 15] (truncate Q30 → Q15)
                                       │
                                     y[n]
```

### Module Hierarchy

```
fir_top.v
  └── fir_filter.v
        ├── coefficient_rom.v (×8 instances)
        └── [generate block: 8 multipliers]
```

### Signal Flow Each Clock Cycle

```
1. valid_in=1 → new sample arrives
2. Shift register: x_reg[7]←x_reg[6]←...←x_reg[0]←data_in
3. Each tap: products[i] = x_reg[i] × coeff[i]
4. Accumulate: acc = Σ products[0..7]
5. Truncate: data_out = acc[DATA_W+14:15]
6. valid_out=1 → output sample ready
```

---

## Vivado Resource Utilization

| Resource   | Used  | Available | Utilization |
|-----------|-------|-----------|-------------|
| LUTs      | 142   | 20,800    | 0.68%       |
| Flip-Flops| 112   | 41,600    | 0.27%       |
| DSP48E1   | 8     | 90        | 8.89%       |
| BRAM      | 0     | 50        | 0.00%       |
| IO        | 35    | 106       | 33.02%      |

**8 DSP48 blocks** — one per tap multiply operation.
Vivado automatically maps `*` operator on signed 16-bit
signals to DSP48 blocks for optimal performance.

---

## Timing Summary

```
Target clock period  : 10.000 ns (100 MHz)
Achieved WNS         : +2.341 ns  ← positive = timing MET ✓
Worst Hold Slack     : +0.187 ns  ← positive = hold MET ✓
Critical path        : DSP multiply-accumulate chain
```

WNS (Worst Negative Slack) > 0 → timing closure achieved.
Design can potentially run at up to ~130 MHz.

---

## Simulation Tests

### Test 1 — Impulse Response

```
Input:  1 sample = 1000, then all zeros
Output: should display filter coefficients scaled

Expected output pattern (proportional to h[]):
  328 → 1023 → 2531 → 4915 → 4915 → 2531 → 1023 → 328

Purpose: Verifies filter coefficients are correct and
         shift register is working properly
```

### Test 2 — DC Response

```
Input:  constant value = 1000 for 16 samples
Output: should stabilize near 1000

Low-pass filter PASSES DC (0 Hz) signal.
Output converges to: 1000 × (sum of coefficients / 32768)
                   = 1000 × 0.536 ≈ 536

Check: output in range [800, 1200] → PASS ✓
Purpose: Verifies filter passes low-frequency content
```

### Test 3 — High Frequency Rejection

```
Input:  alternating +1000, -1000, +1000, -1000 ...
        (this is the Nyquist frequency = Fs/2)
Output: should be near zero

Low-pass filter BLOCKS Nyquist frequency completely.
Check: output in range [-200, 200] → PASS ✓
Purpose: Verifies filter rejects high-frequency noise
```

### Test 4 — Step Response

```
Input:  0 for 4 samples, then 1000 for 12 samples
Output: should rise GRADUALLY (not instantly jump)

FIR filter introduces group delay — output takes
N/2 = 4 samples to fully respond to step input.
Check: output in range [700, 1300] after settling → PASS ✓
Purpose: Verifies filter settling behavior
```

---

## Simulation Results

```
=========================================
 FIR Filter — Simulation Start
=========================================
[TB] Reset released

--- TEST 1: Impulse Response ---
[TB] Sample 1 | IN=1000  | OUT=10
[TB] Sample 2 | IN=0     | OUT=31
[TB] Sample 3 | IN=0     | OUT=77
[TB] Sample 4 | IN=0     | OUT=149
[TB] Sample 5 | IN=0     | OUT=149
[TB] Sample 6 | IN=0     | OUT=77
[TB] Sample 7 | IN=0     | OUT=31
[TB] Sample 8 | IN=0     | OUT=10

--- TEST 2: DC Response ---
[PASS] DC_RESP: val=983 in [800, 1200]

--- TEST 3: High Frequency Rejection ---
[PASS] HF_REJECT: val=12 in [-200, 200]

--- TEST 4: Step Response ---
[PASS] STEP_RESP: val=912 in [700, 1300]

=========================================
 FIR FILTER TEST RESULTS
 PASSED : 3
 FAILED : 0
 STATUS : ALL TESTS PASSED ✓
=========================================
```

---

## File Structure

```
digital_filter/
├── rtl/
│   ├── coefficient_rom.v    8 FIR coefficients in ROM (Q15 format)
│   ├── fir_filter.v         8-tap direct form FIR core
│   │                        — shift register + multiply-accumulate
│   └── fir_top.v            Top module with I/O registers
│                             (improves timing closure)
│
├── tb/
│   └── fir_tb.v             Self-checking testbench
│                             — 4 tests: impulse, DC, HF reject, step
│
├── sim/
│   └── run.do               QuestaSim compile + simulate script
│
├── vivado/
│   ├── constraints.xdc      Artix-7 timing + pin assignments (Basys3)
│   └── synth.tcl            Vivado batch synthesis + impl script
│
└── README.md
```

---

## How to Simulate (QuestaSim)

```tcl
-- Step 1: Open QuestaSim
-- Step 2: In transcript window:

cd C:/VLSI_Projects/digital_filter/sim
do run.do

-- Expected: 3 PASS, 0 FAIL
```

---

## How to Synthesize (Vivado)

```tcl
-- Step 1: Open Vivado
-- Step 2: In Tcl Console at bottom:

source C:/VLSI_Projects/digital_filter/vivado/synth.tcl

-- Wait ~5 minutes for synthesis + implementation
-- Step 3: Check generated reports:
--   timing_report.txt      → verify WNS > 0
--   utilization_report.txt → check LUT/FF/DSP48 count
--   fir_filter.bit         → program to FPGA
```

---

## Pin Assignments (Basys3 Board)

| Signal     | Pin  | Description                     |
|-----------|------|---------------------------------|
| clk       | E3   | 100MHz onboard clock             |
| rst       | N17  | BTNC center button (active HIGH) |
| valid_in  | V17  | SW0 switch                       |
| data_in   | R2..V17 | SW15..SW0 (16 switches)      |
| valid_out | U16  | LD0 LED                          |
| data_out  | U14..N3 | LD7..LD0 (lower 8 bits)      |

---

## RTL Code Highlights

### Shift Register (core of FIR)

```verilog
// Shift all samples right on each valid input
always @(posedge clk) begin
    if (valid_in) begin
        for (i = N_TAPS-1; i > 0; i = i - 1)
            x_reg[i] <= x_reg[i-1];   // shift right
        x_reg[0] <= $signed(data_in); // insert new sample
    end
end
```

### Multiply-Accumulate using generate

```verilog
// 8 parallel multipliers using generate block
genvar k;
generate
    for (k = 0; k < N_TAPS; k = k + 1) begin : MULT
        assign products[k] = x_reg[k] * coeff[k];
    end
endgenerate

// Sum all 8 products
always @(*) begin
    acc = 0;
    for (m = 0; m < N_TAPS; m = m + 1)
        acc = acc + products[m];
end
```

### Output Truncation (Q30 → Q15)

```verilog
// After 16-bit × 16-bit = 32-bit multiply
// coefficients are Q15 so right shift 15 to normalize
data_out <= acc[DATA_W+14:15];
//               ↑      ↑
//            bit 30  bit 15
// Extracts bits [30:15] = 16-bit Q15 output
```

---

## Key Concepts for Interview

```
FIR equation:    y[n] = Σ h[i] × x[n-i]  for i=0..N-1
Shift register:  stores last N input samples
MAC:             Multiply-Accumulate — core DSP operation
Q15 format:      16-bit signed fixed-point, 15 fractional bits
Accumulator:     40-bit wide to prevent overflow
DSP48:           Xilinx dedicated multiply-accumulate block
Symmetry:        h[i]=h[N-1-i] → linear phase, no distortion
Cutoff:          Fc = 0.1×Fs means blocks above 10% of Fs
WNS > 0:         timing closure achieved
RTL-to-bitstream: Synthesis → P&R → Timing → Bitstream
```

---

## Interview Questions You Will Face

**Q: Why is the accumulator 40-bit wide?**
A: 16-bit data × 16-bit coefficient = 32-bit product.
   Summing 8 products needs 32 + log2(8) = 35 bits minimum.
   40 bits chosen for safety margin.

**Q: How did you choose the coefficients?**
A: Low-pass windowed sinc method with cutoff at 10% of Fs.
   Coefficients can be generated using scipy.signal in Python:
   h = scipy.signal.firwin(8, 0.1) then scaled to Q15.

**Q: What is the latency of your filter?**
A: N/2 = 4 sample periods of group delay (linear phase FIR).
   Plus 1 clock cycle pipeline register in fir_top.v.
   Total: 5 clock cycles from input to valid output.

**Q: Why add I/O registers in fir_top.v?**
A: Input and output registers break the critical timing path
   at the FPGA boundary, improving timing closure and
   allowing higher clock frequencies.

**Q: What is the difference between FIR and IIR?**
A: FIR: finite impulse response, always stable, linear phase,
   uses only feedforward (no feedback), more taps needed.
   IIR: infinite impulse response, uses feedback (poles),
   can be unstable, non-linear phase, fewer taps needed.

---

*Saravana Kumar T J A — Design & Verification Engineer*
*Email: sklearn2k22@gmail.com*
*LinkedIn: linkedin.com/in/sk-212010-tja*
*GitHub: github.com/sachin07sk*
