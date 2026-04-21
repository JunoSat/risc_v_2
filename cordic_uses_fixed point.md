Great question — this is a fundamental hardware design decision worth understanding deeply.

## Why the CORDIC Doesn't Use Floating Point Internally

The CORDIC algorithm is inherently a **shift-and-add** machine. Every iteration does:
```
x_next = x - d * (y >> i)
y_next = y + d * (x >> i)
z_next = z - d * atan_lut[i]
```

The `>> i` (right shift by i bits) is what makes CORDIC computationally cheap — it's a **free operation in hardware** (just wire rerouting). If you used IEEE-754 floats, each iteration would require a full floating-point adder, multiplier, and exponent normalizer — roughly **50× more logic** per stage. You'd essentially be reimplementing an FPU inside your FPU.

**Fixed-point is the universal industry standard for CORDIC implementations.** Every chip — from ARM's Cortex-M DSP extensions to Xilinx's CORDIC IP core — uses fixed-point internally.

## So How Do You Use It with Floats?

The answer is: **the CPU handles the float↔fixed conversion, the hardware does the computation.**

```
CPU (software)          AXI Bus            CORDIC (hardware)
─────────────          ─────────          ─────────────────
float angle;     →    [Q4.28 int]   →    shift-add iterations
                                    ←    [Q4.28 int]   ←    sin/cos fixed result
float sin_result ←
```

Your pipeline already has an FPU (`fpu.v`) handling `FCVT.W.S` and `FCVT.S.W` instructions. So the conversion is a **single hardware instruction**, not a software loop:

```c
// The compiler generates FCVT.W.S (float → int) and FCVT.S.W (int → float)
// Both run through your actual fpu.v hardware — NOT software!

int32_t to_q4_28(float radians) {
    return (int32_t)(radians * 268435456.0f);  // → FMUL.S + FCVT.W.S
}

float from_q4_28(int32_t q) {
    return (float)q / 268435456.0f;            // → FCVT.S.W + FDIV.S (or FMUL.S by reciprocal)
}
```

So the complete floating-point-in, floating-point-out workflow is:

```c
float angle = 1.5707963f;  // π/2, stored in f-register as IEEE-754

// Step 1: FPU converts float → Q4.28 int (FMUL.S + FCVT.W.S)  ~2 cycles
int32_t q = to_q4_28(angle);

// Step 2: CPU writes Q4.28 int over AXI to CORDIC (SW instruction)
*CORDIC_ANGLE = q;
while (*CORDIC_STATUS == 0);  // Wait ~32 cycles for CORDIC iterations

// Step 3: CPU reads raw fixed-point result (LW instruction)
int32_t sin_raw = *CORDIC_SINE;

// Step 4: FPU converts Q4.28 int → float (FCVT.S.W + FMUL.S)  ~2 cycles
float sin_float = from_q4_28(sin_raw);
```

## What Would "Native Float CORDIC" Actually Cost?

If you wanted internal float computation in hardware, you'd need:

| Resource | Fixed-Point CORDIC | Float CORDIC |
|---|---|---|
| Adder per iteration | 32-bit integer add | 32-bit IEEE-754 FP add (~200 gates) |
| Shifter | Free (wire rerouting) | Full barrel shifter + exponent logic |
| LUT usage (est.) | ~150 LUTs | ~3,000+ LUTs |
| Clock cycles | 32 | 32 × ~8 = 256+ |

The Q4.28 scheme gives you **32-bit precision** in the range `[-8.0, +8.0]`, which comfortably covers the `[-π, π]` input domain. The rounding error is `1/2^28 ≈ 3.7 × 10⁻⁹` — better than IEEE-754 single precision's `~1.2 × 10⁻⁷`.

**The fixed-point CORDIC is actually more precise than your FPU for this specific operation**, while using a fraction of the silicon area. This is by design, not a limitation.
