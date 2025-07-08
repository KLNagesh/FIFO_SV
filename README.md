# FIFO_SV
FIFO (First-In First-Out)Design in SystemVerilog This repository contains a synchronous FIFO buffer implemented in SystemVerilog. FIFO follows the First-In First-Out principle, where the earliest written data is read first. The design supports reset, write/read operations, and status flags like full and empty.

**Features:**
  Parameterized FIFO depth and data width
  Supports write, read, reset, full, and empty logic
  Handles back-to-back read/write operations
  Testbench included with randomized inputs and status checks

**Tools Used:**
ModelSim – For simulation and debugging
Xilinx Vivado – For synthesis and behavioral simulation
EDA Playground – For quick testing and online collaboration

**Challenges Overcome:**
  Ensuring proper synchronization between read and write pointers
  Avoiding data corruption during full/empty boundary conditions
  Creating an efficient and reusable testbench using classes
  Debugging using waveform analysis when dout was not updating correctly

