# Execution FSM-Based Processor Subsystem

This repository contains a hardware design for a **modular processor subsystem** implemented in **SystemVerilog**.  
The architecture is based on a **centralized finite state machine (FSM)** that manages instruction execution, memory access, ALU operations, and writeback over a shared **256-bit bus**.

The system integrates multiple computational modules, including a **4×4 matrix co-processor** and an **integer arithmetic unit**, executing a programmable sequence of operations defined in instruction memory.

---

## Features

### Central Execution Engine
A synchronous FSM controls the complete instruction lifecycle:
- Instruction fetch and decode  
- Operand request and dispatch  
- ALU invocation  
- Writeback  
- Program counter update  

**Conditional Branch Support:** `BEQ`, `BNE`, `BLT`, `BGT`

---

### 256-Bit Shared Data Bus
- Active-low read and write signaling  
- 16-bit address bus (upper bits used for module ID)  
- Tri-state arbitration ensures a single active driver at any time  

---

### Matrix Co-Processor
Operates on **4×4, 16-bit matrices** packed into 256-bit words.

**Supported Operations:**
- Matrix multiply  
- Scalar multiply  
- Add / Subtract  
- Transpose  

Results are written back to the shared bus when addressed.

---

### Integer ALU
Performs arithmetic on **16-bit scalar values**.

**Supported Operations:**
- Add  
- Subtract  
- Multiply  
- Divide  

---

### Memory and Register Organization
- Main memory with 256-bit entries  
- Internal register file with synchronous updates  
- Instruction ROM preloaded with a test program  

---

## Instruction Flow

The processor executes a structured sequence of operations, including:
1. Matrix addition and scalar multiplication  
2. Integer arithmetic operations and comparisons  
3. Conditional branch evaluation  
4. Final matrix multiplication  

Branch execution occurs:
- During **decode** when operands are already available, or  
- After **memory loads** when operands must be fetched.  

---

## Simulation and Runtime Behavior

- Total simulation runtime: **10 microseconds**  
- Handshake logic operated correctly during the initial execution cycle  
- A failure occurred in the second cycle due to a **memory value not cleared after writeback**  

This stale data led to incorrect comparison results and **unintended branching behavior**.  
The issue highlights the need for **explicit memory reset or invalidation mechanisms** in multi-cycle execution flows.

Waveforms illustrating **bus activity**, **ALU operations**, and **writeback timing** are provided in the `/docs` directory.

---

## Directory Structure
/src
  Execution.sv
  MatrixAlu.sv
  IntegerAlu.sv
  MainMemory.sv
  InstructionMemory.sv
  top.sv

/docs
  report.pdf
  waveforms/
