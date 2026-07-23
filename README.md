# ntt256-asic-accelerator
RTL adaptation and ASIC physical implementation of an NTT-256 hardware accelerator with SRAM-based architecture in SCL 180 nm CMOS.
# NTT-256 Hardware Accelerator — ASIC Implementation

## Overview

This project presents the **RTL adaptation and ASIC physical implementation of a 256-point Number Theoretic Transform (NTT) hardware accelerator** targeting **SCL 180 nm CMOS technology**.

The design was adapted from an open-source parameterized NTT architecture and re-engineered into a **fixed NTT-256 Verilog RTL implementation** for ASIC synthesis and physical design.

The ASIC architecture integrates **three SRAM macros**:
- 2 SRAMs for NTT data storage
- 1 SRAM for twiddle-factor storage

The design was synthesized and physically implemented targeting an operating frequency of **100 MHz**.

---

## Design Specifications

| Parameter | Specification |
|---|---|
| Architecture | 256-point NTT |
| Technology | SCL 180 nm CMOS |
| Target Frequency | 100 MHz |
| HDL | Verilog HDL |
| Memory | 3 SRAM Macros |
| Data Memory | 2 SRAMs |
| Twiddle-Factor Memory | 1 SRAM |
| Standard Cells | ~2–3K |
| Standard-Cell Area | ~78,000 µm² |
| Synthesis | Cadence Genus |
| Physical Design | Cadence Innovus |

---

## My Contribution

The original open-source implementation provides a generalized and parameterized NTT architecture.

For this project, the design was adapted and restructured into a **fixed NTT-256 implementation** for the target ASIC flow.

The work included:

- Specializing the parameterized architecture for NTT-256
- Restructuring and modifying Verilog RTL for ASIC implementation
- RTL functional verification and testbench validation
- Integration of 3 SRAM macros for data and twiddle-factor storage
- Logic synthesis using Cadence Genus
- Floorplanning and SRAM macro placement
- Placement and Clock Tree Synthesis (CTS)
- Routing and Static Timing Analysis (STA)
- Physical implementation targeting 100 MHz in SCL 180 nm CMOS

---

## Physical Design

The NTT-256 accelerator was implemented using **Cadence Genus and Cadence Innovus**.

The final physical implementation contains approximately **2–3K standard cells**, in addition to three SRAM macros, and targets an operating frequency of **100 MHz**.

![NTT-256 Physical Design](images/Physical_design/Screenshot 2026-07-04 202606.png)

---

## Repository Contents

- `rtl/` — Modified NTT-256 Verilog RTL source files
- `verification/` — RTL testbench and verification files
- `images/` — Final ASIC physical-design image

---

## SRAM / Foundry File Notice

The ASIC implementation uses **three foundry SRAM macros: two data SRAMs and one twiddle-factor SRAM**.

The SRAM RTL/models, timing libraries, LEF files, and other foundry-specific technology files are **not included in this repository due to confidentiality and licensing restrictions**.

As a result, the publicly available RTL may require equivalent memory models or user-defined SRAM replacements for standalone simulation or implementation.

No proprietary **SCL 180 nm PDK, standard-cell library, SRAM macro, or foundry technology files** are distributed in this repository.

---

## Original Project and Attribution

This work is based on the open-source **Parametric NTT** project by the original authors:

**Original Repository:** acmert/parametric-ntt

The original project provides a configurable NTT hardware architecture. This repository documents my work in **adapting and specializing the architecture into a fixed NTT-256 implementation and taking it through an ASIC synthesis and physical-design flow**.

Please refer to the original repository for the original source, documentation, authorship, and applicable license.

---

## Tools

- Verilog HDL
- Cadence Genus
- Cadence Innovus
- SCL 180 nm CMOS
