# RISC-V SoC Hardware Optimization

Hardware and software co-optimization projects on the Aquila RISC-V SoC platform, covering cache microarchitecture, RTOS profiling, and domain-specific accelerator design.

## Course Information

| | |
|---|---|
| **Course** | Microprocessor Systems: Principles and Implementation |
| **Institution** | National Yang Ming Chiao Tung University (NYCU) |
| **Instructor** | Prof. Chun-Jen Tsai |
| **Semester** | 2024 Fall |
| **Platform** | [Aquila SoC](https://github.com/eisl-nctu/aquila) — a RISC-V RV32IMA soft processor on Xilinx FPGA |

## Projects

### 1. [Cache Optimization](cache-optimization/)

Optimized the data cache of Aquila SoC to reduce miss latency and improve hit rate.

**What I built:**
- Custom `dcache_profiler.v` module for collecting cache hit/miss statistics
- Dirty bit management fix — the original design never cleared dirty bits, causing every miss to trigger an unnecessary write-back
- LRU replacement policy (`lru_matrix.v`) to replace the default FIFO
- FSM redesign — removed the redundant `WbToMemFinish` state to reduce stall cycles
- Stride-based prefetching algorithm with concurrent cache hit handling during prefetch

**Results:**
- Miss latency reduced by **19.87%** (54.58 → 43.73 cycles/op) through dirty bit + FSM optimization
- Best configuration (8 KB, 2-way, FIFO + dirty bit fix) achieved **16.11% overall speedup** (30,517 ms → 24,395 ms on π 5000-digit computation)

![FSM](cache-optimization/docs/FSM.png)

📄 [Full Report (PDF)](cache-optimization/docs/report.pdf)

---

### 2. [RTOS Profiling](rtos-profiling/)

Analyzed context switching and synchronization mechanisms of FreeRTOS running on Aquila.

**What I built:**
- Hardware profiler integrated into the Aquila SoC to measure context switching latency cycle-by-cycle
- Profiling of timer interrupt overhead across different time quantum settings (5 ms / 10 ms / 20 ms)
- Mutex take/give latency measurement for synchronization analysis

**Results:**
- Context switching overhead: **5.18‰** (5 ms quantum) → **1.28‰** (20 ms quantum) of total execution
- Latency per timer IRQ remained consistent (~1,000 cycles) regardless of quantum size
- Synchronization (mutex) overhead: **19.00‰** of total execution

![Context Switching](rtos-profiling/docs/context_switching.png)

📄 [Full Report (PDF)](rtos-profiling/docs/report.pdf)

---

### 3. [DSA Accelerator](dsa-accelerator/)

Designed a domain-specific accelerator and tightly coupled memory to speed up CNN-based handwritten character recognition.

**What I built:**
- DSA module for fused multiply-add operations using Xilinx floating-point IP, mapped to memory-mapped I/O
- 128 KB Tightly Coupled Memory (TCM) using block RAM for storing CNN weights and feature maps
- Embedded cycle profiler within the DSA to separate data feeding vs. computation time
- Software-side optimization: hardcoded padding/stride, moved data access from cached main memory to TCM

**Results:**
- DSA alone: **7.43x speedup** (25,483 ms → 3,431 ms)
- Full optimization (DSA + TCM + SW): **7.77x speedup** (25,483 ms → 3,278 ms)
- Profiler showed computation accounts for ~70% of DSA execution time, indicating room for further data feeding optimization

📄 [Full Report (PDF)](dsa-accelerator/docs/report.pdf)

---

## Tech Stack

- **HDL:** Verilog (RTL design, cache controller, DSA, TCM, profiler modules)
- **ISA:** RISC-V RV32IMA
- **FPGA:** Xilinx Vivado / Artix-7
- **OS:** FreeRTOS
- **Software:** C (bare-metal and RTOS applications), GCC 13.2.0

## Acknowledgement

These projects are built on the [Aquila SoC](https://github.com/eisl-nctu/aquila) platform developed by Prof. Chun-Jen Tsai and the Embedded Intelligent Systems Lab (EISL) at NYCU. The original hardware design is licensed under BSD-3-Clause.
