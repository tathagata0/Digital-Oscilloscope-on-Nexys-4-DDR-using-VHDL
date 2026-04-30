# Digital Oscilloscope on Nexys 4 DDR using VHDL

![Project Status](https://img.shields.io/badge/Status-Complete-brightgreen)
![Language](https://img.shields.io/badge/Language-VHDL--2008-blue)
![Platform](https://img.shields.io/badge/Platform-Nexys%204%20DDR%20(Artix--7)-orange)
![IDE](https://img.shields.io/badge/IDE-Vivado%202025.2-purple)

VHDL implementation of a Digital Storage Oscilloscope for the Artix-7 FPGA (Nexys 4 DDR). This project features a custom Direct Digital Synthesis (DDS) internal wave generator, dual-port BRAM memory buffering, real-time VGA output (640x480), and an interactive UI with 7-segment multiplexing for Trigger, VPOS, and Volts/Time scaling.

---

## 📌 Project Overview
This project converts a Nexys 4 DDR FPGA into a fully functional Digital Storage Oscilloscope (DSO). It runs completely in parallel without the use of a microprocessor.
*   **Analog Capture:** Utilizes the onboard Xilinx XADC to read physical real-world voltages from the JXADC header.
*   **Internal DDS Generator:** To test the logic without requiring external lab equipment, the system includes a mathematical Direct Digital Synthesis (DDS) generator capable of synthesizing perfect Sine, Square, Triangle, and Sawtooth waves internally.
*   **Memory & Display:** 12-bit data samples are buffered into Dual-Port Block RAM (BRAM) and rendered pixel-by-pixel to a standard 640x480 @ 60Hz VGA monitor, complete with a hardware trigger lock and On-Screen Display (OSD) text.

---

## 🎮 Hardware Operation Manual (How to Use It)

Once the bitstream is loaded onto the board, use the physical switches and buttons to control the oscilloscope.

### 1. Master Control & Wave Generation (The Switches)
The 16 slide switches (`SW0` to `SW15`) control the data input and run state.

*   **`SW0` (Master Run/Stop):** 
    *   ⬇️ DOWN: **RUN** Mode (Memory is actively recording).
    *   ⬆️ UP: **STOP** Mode (Screen freezes, memory stops writing).
*   **`SW15` (Input Selector):**
    *   ⬇️ DOWN: Listen to the physical **XADC** analog pins.
    *   ⬆️ UP: Ignore physical pins, turn on **Internal DDS Test Waves**.
*   **`SW11` & `SW10` (Wave Shape Selector):** *(Only works if SW15 is UP)*
    *   `SW11` ⬇️ | `SW10` ⬇️ = **Square Wave**
    *   `SW11` ⬇️ | `SW10` ⬆️ = **Sawtooth Wave**
    *   `SW11` ⬆️ | `SW10` ⬇️ = **Triangle Wave**
    *   `SW11` ⬆️ | `SW10` ⬆️ = **Sine Wave** (LUT-based)
*   **`SW13` (Force Trigger):**
    *   ⬆️ UP: Bypasses the trigger logic and forces the screen to draw immediately.

### 2. Menu Navigation (Buttons & LEDs)
We use the Center Button to cycle through menus, and the Up/Down buttons to change values. **Watch the Green LEDs above the switches to know what menu you are currently in!**

*   🔘 **Press `BTNC` (Center Button)** to cycle through the following 4 modes:

| Active LED(s) | Mode Name | What it does when you press `BTNU` (Up) or `BTND` (Down) |
| :--- | :--- | :--- |
| **🟢 LED 12** | **Trigger Level** | Moves the trigger threshold. The wave will only draw when it crosses this invisible line, locking it perfectly still on the screen. |
| **🟢 LED 13** | **VPOS (Vertical Position)** | Physically moves the wave up or down on the VGA monitor. |
| **🟢 LED 14** | **Volts / Div (Vertical Zoom)** | Zooms the wave's amplitude. Use this if the wave is too tall to fit on the screen. |
| **🟢 LEDs 12 & 14** | **Time / Div (Horizontal Zoom)** | Zooms the wave's frequency. Use this to squish a slow wave or stretch out a fast wave. |

*(The current values for Volts/Div, Time/Div, and Trigger are displayed on the 7-segment LEDs and the VGA screen).*

---

## 📂 Code Structure & Architecture

The source code (`src/`) is highly modular. Here is exactly what each file does:

*   **`oscilloscope_top.vhd`:** The master file. Wires all components together. Contains the mathematical DDS wave generators, the Volts/Div bit-shifting scaler, the Time/Div sampling counter, and the complex Trigger Finite State Machine (Armed vs. Fired logic).
*   **`block_ram.vhd`:** Infers Dual-Port Block RAM. Port A constantly writes the 640 voltage samples. Port B is simultaneously read by the VGA controller to prevent screen tearing.
*   **`vga_controller.vhd`:** Generates a 25MHz pixel clock and outputs mathematically perfect HSYNC and VSYNC pulses to drive a 640x480 @ 60Hz display.
*   **`oscilloscope_features.vhd`:** The User Interface brain. Contains hardware debouncing logic so a single physical button press doesn't register as 100 presses. Runs the Finite State Machine for the menu system (tracking BTNC presses).
*   **`display_decoder.vhd` & `seven_segment_driver.vhd`:** Controls the 8 glowing digits on the board. Uses Time-Division Multiplexing (sweeping across the digits at 1kHz) to trick the human eye into seeing all 8 digits glowing simultaneously using only 16 pins.
*   **`simple_text_display.vhd`:** A hardware graphics engine. Contains an internal ROM with 8x16 pixel bitmaps of ASCII characters to draw the text overlay directly onto the VGA signal.
*   **`xadc_module.vhd`:** Wraps the Xilinx IP Catalog `xadc_wiz_0` component. Handles the complex DRP addressing required to pull clean 12-bit digital numbers out of the physical analog silicon on the chip.

---

## 🔌 Physical Constraints (`nexys4_ddr.xdc`)

The `.xdc` file maps the VHDL to the physical board using the `LVCMOS33` standard.

*   **System Clock:** Pin `E3` (100MHz onboard oscillator).
*   **VGA Out:** Red (`A3, B4, C5, A4`), Green (`C6, A5, B6, A6`), Blue (`B7, C7, D7, D8`), HSYNC (`B11`), VSYNC (`B12`).
*   **Analog Input:** JXADC Pmod Header. Pin `A13` (`vauxp3` positive) and Pin `A14` (`vauxn3` negative ground).
