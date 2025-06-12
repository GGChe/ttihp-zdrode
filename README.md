![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Tiny Tapeout Factory Test (IHP)

- [Read the documentation for project](docs/info.md)

## What is Tiny Tapeout?

Tiny Tapeout is an educational project that aims to make it easier and cheaper than ever to get your digital and analog designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.

## Set up your Verilog project

1. Add your Verilog files to the `src` folder.
2. Edit the [info.yaml](info.yaml) and update information about your project, paying special attention to the `source_files` and `top_module` properties. If you are upgrading an existing Tiny Tapeout project, check out our [online info.yaml migration tool](https://tinytapeout.github.io/tt-yaml-upgrade-tool/).
3. Edit [docs/info.md](docs/info.md) and add a description of your project.
4. Adapt the testbench to your design. See [test/README.md](test/README.md) for more information.

The GitHub action will automatically build the ASIC files using [OpenLane](https://www.zerotoasiccourse.com/terminology/openlane/).

## Enable GitHub actions to build the results page

- [Enabling GitHub Pages](https://tinytapeout.com/faq/#my-github-action-is-failing-on-the-pages-part)

## Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
- [Join the community](https://tinytapeout.com/discord)
- [Build your design locally](https://www.tinytapeout.com/guides/local-hardening/)

## What next?

- [Submit your design to the next shuttle](https://app.tinytapeout.com/).
- Edit [this README](README.md) and explain your design, how it works, and how to test it.
- Share your project on your social network of choice:
  - LinkedIn [#tinytapeout](https://www.linkedin.com/search/results/content/?keywords=%23tinytapeout) [@TinyTapeout](https://www.linkedin.com/company/100708654/)
  - Mastodon [#tinytapeout](https://chaos.social/tags/tinytapeout) [@matthewvenn](https://chaos.social/@matthewvenn)
  - X (formerly Twitter) [#tinytapeout](https://twitter.com/hashtag/tinytapeout) [@tinytapeout](https://twitter.com/tinytapeout)


# Project interface

## tt_um_example – Interface Specification

### Overview

`tt_um_example` is a Tiny Tapeout–compatible top-level wrapper.  
It accepts a stream of 16-bit samples, routes each sample to one of *N* internal processing units, and reports per-unit spike/event flags on an 8-bit output port. THe 16 bit input samples are fed in two clock cycles. First byte stored in the MSB and the next 8 bit in the LSB. 

    ```verilog
    default_nettype none
    module tt_um_example #(
        parameter integer NUM_UNITS  = 4,   // number of processing channels
        parameter integer DATA_WIDTH = 16   // sample word length (bits)
    ) ( ... );
    ```

---

## Parameters

| Parameter | Default | Notes |
|-----------|---------|-------|
| `NUM_UNITS`  | 4  | Number of independent processing channels (`≥ 1`). |
| `DATA_WIDTH` | 16 | Width of each assembled sample word (recommended 8 – 32 bits). |

---

## Ports

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `ui_in`  | in  | 8 | Control bus.  bits [1:0] = `selected_unit` (0 … `NUM_UNITS-1`)  bit 2 = `byte_valid` (high for one cycle while `uio_in` is valid)  bits [7:3] = unused. More can be used if more processing units are needed. |
| `uo_out` | out | 8 | Status word.  bit 0 = spike flag of selected unit  bits [2:1] = 2-bit event code of selected unit  bits [7:3] = 0 |
| `uio_in` | in  | 8 | Serialised sample bytes (first MSB, then LSB). |
| `uio_out`| out | 8 | Unused; driven to `8'h00`. |
| `uio_oe` | out | 8 | Tristate enables for `uio_out`; always `8'h00` (input-only). |
| `ena`    | in  | 1 | Global user enable; ignored. |
| `clk`    | in  | 1 | Rising-edge system clock. |
| `rst_n`  | in  | 1 | Asynchronous reset, active low. |

---

## Data-Flow Timing

1. **Byte ingestion**  
   On each rising edge of `clk` with `byte_valid = 1`:  
   • first asserted cycle → byte latched into sample bits [15:8]  
   • second asserted cycle → byte latched into bits [7:0] and `sample_wr_en` pulses high for one cycle. This writes into RAM.

2. **Sample dispatch**  
   Completed 16-bit sample is broadcast to all `NUM_UNITS`; each unit processes it independently.

3. **Flag multiplexing**  
   Combinational logic selects spike/event flags of `selected_unit`, pads with zeros, and drives the 8-bit result on `uo_out`.

---


