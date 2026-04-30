# Complete VHDL Source Code for FPGA Digital Oscilloscope

## block_ram.vhd

```vhdl

-- =============================================================================
-- block_ram.vhd
-- Simple dual-port synchronous block RAM.
-- Unchanged from reference design (works on both Basys3 & Nexys4 DDR).
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity block_ram is
    Generic (
        ADDR_WIDTH : integer := 10;    -- 2^10 = 1024 samples
        DATA_WIDTH : integer := 12     -- 12-bit ADC
    );
    Port (
        clk         : in  STD_LOGIC;
        write_en    : in  STD_LOGIC;
        write_addr  : in  STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
        write_data  : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
        read_addr   : in  STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
        read_data   : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0)
    );
end block_ram;

architecture Behavioral of block_ram is
    type ram_type is array (0 to (2**ADDR_WIDTH)-1) of STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    signal ram : ram_type := (others => (others => '0'));
    signal read_data_reg : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if write_en = '1' then
                ram(to_integer(unsigned(write_addr))) <= write_data;
            end if;
            read_data_reg <= ram(to_integer(unsigned(read_addr)));
        end if;
    end process;

    read_data <= read_data_reg;

end Behavioral;
```

## display_decoder.vhd

```vhdl

-- =============================================================================
-- display_decoder.vhd  (Nexys4 DDR version)
-- Converts the active control parameter into BCD digits for the 7-segment
-- display.  Extended to drive 8 digits on the Nexys4 DDR.
-- Upper 4 digits (7-4): unit label (V, mV, us, ms shown as hex letters)
-- Lower 4 digits (3-0): numeric value
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity display_decoder is
    Port (
        clk            : in  STD_LOGIC;
        reset          : in  STD_LOGIC;
        active_control : in  STD_LOGIC_VECTOR(2 downto 0);
        volts_per_div  : in  STD_LOGIC_VECTOR(3 downto 0);
        time_per_div   : in  STD_LOGIC_VECTOR(3 downto 0);
        trigger_level  : in  STD_LOGIC_VECTOR(11 downto 0);

        -- 8 digits for Nexys4 DDR (digit7 = leftmost, digit0 = rightmost)
        digit7  : out STD_LOGIC_VECTOR(3 downto 0);
        digit6  : out STD_LOGIC_VECTOR(3 downto 0);
        digit5  : out STD_LOGIC_VECTOR(3 downto 0);
        digit4  : out STD_LOGIC_VECTOR(3 downto 0);
        digit3  : out STD_LOGIC_VECTOR(3 downto 0);
        digit2  : out STD_LOGIC_VECTOR(3 downto 0);
        digit1  : out STD_LOGIC_VECTOR(3 downto 0);
        digit0  : out STD_LOGIC_VECTOR(3 downto 0);
        dp      : out STD_LOGIC_VECTOR(7 downto 0)
    );
end display_decoder;

architecture Behavioral of display_decoder is

    signal display_value : unsigned(13 downto 0) := (others => '0');
    signal dp_int        : STD_LOGIC_VECTOR(7 downto 0) := "00000000";

    -- Encoded unit for upper digit group
    -- 0=blank, 1=V, 2=mV, 3=us, 4=ms, 5=Hz
    signal unit_code : unsigned(2 downto 0) := (others => '0');

    -- BCD decomposition helpers
    signal thousands : unsigned(3 downto 0);
    signal hundreds  : unsigned(3 downto 0);
    signal tens      : unsigned(3 downto 0);
    signal ones      : unsigned(3 downto 0);

begin

    -- =========================================================================
    -- Decode active control into numeric value + unit
    -- =========================================================================
    process(clk)
        variable val : unsigned(13 downto 0);
        variable uc  : unsigned(2 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                display_value <= (others => '0');
                unit_code     <= (others => '0');
                dp_int        <= (others => '0');
            else
                val := (others => '0');
                uc  := (others => '0');

                case active_control is
                    -- "000" = trigger level (raw ADC counts â†’ show as decimal)
                    when "000" =>
                        val := resize(unsigned(trigger_level), 14);
                        uc  := "001"; -- V label

                    -- "001" = Volts/div
                    when "001" | "011" =>
                        case to_integer(unsigned(volts_per_div)) is
                            when 0 => val := to_unsigned(50,  14); uc := "010"; -- 50 mV
                            when 1 => val := to_unsigned(100, 14); uc := "010"; -- 100 mV
                            when 2 => val := to_unsigned(200, 14); uc := "010"; -- 200 mV
                            when 3 => val := to_unsigned(500, 14); uc := "010"; -- 500 mV
                            when 4 => val := to_unsigned(1,   14); uc := "001"; -- 1 V
                            when 5 => val := to_unsigned(2,   14); uc := "001"; -- 2 V
                            when 6 => val := to_unsigned(5,   14); uc := "001"; -- 5 V
                            when 7 => val := to_unsigned(10,  14); uc := "001"; -- 10 V
                            when others => val := (others => '0'); uc := (others => '0');
                        end case;

                    -- "100" = Time/div
                    when "100" =>
                        case to_integer(unsigned(time_per_div)) is
                            when 0  => val := to_unsigned(1,   14); uc := "011"; -- 1 Âµs
                            when 1  => val := to_unsigned(2,   14); uc := "011"; -- 2 Âµs
                            when 2  => val := to_unsigned(5,   14); uc := "011"; -- 5 Âµs
                            when 3  => val := to_unsigned(10,  14); uc := "011"; -- 10 Âµs
                            when 4  => val := to_unsigned(20,  14); uc := "011"; -- 20 Âµs
                            when 5  => val := to_unsigned(50,  14); uc := "011"; -- 50 Âµs
                            when 6  => val := to_unsigned(100, 14); uc := "011"; -- 100 Âµs
                            when 7  => val := to_unsigned(200, 14); uc := "011"; -- 200 Âµs
                            when 8  => val := to_unsigned(500, 14); uc := "011"; -- 500 Âµs
                            when 9  => val := to_unsigned(1,   14); uc := "100"; -- 1 ms
                            when 10 => val := to_unsigned(2,   14); uc := "100"; -- 2 ms
                            when 11 => val := to_unsigned(5,   14); uc := "100"; -- 5 ms
                            when 12 => val := to_unsigned(10,  14); uc := "100"; -- 10 ms
                            when 13 => val := to_unsigned(20,  14); uc := "100"; -- 20 ms
                            when 14 => val := to_unsigned(50,  14); uc := "100"; -- 50 ms
                            when 15 => val := to_unsigned(100, 14); uc := "100"; -- 100 ms
                            when others => val := (others => '0'); uc := (others => '0');
                        end case;

                    when others =>
                        val := (others => '0');
                        uc  := (others => '0');
                end case;

                display_value <= val;
                unit_code     <= uc;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- BCD decomposition (up to 9999)
    -- =========================================================================
    thousands <= to_unsigned(to_integer(display_value) / 1000, 4);
    hundreds  <= to_unsigned((to_integer(display_value) / 100) mod 10, 4);
    tens      <= to_unsigned((to_integer(display_value) / 10)  mod 10, 4);
    ones      <= to_unsigned( to_integer(display_value)        mod 10, 4);

    -- =========================================================================
    -- Drive 8 digits
    -- Upper nibble: unit label encoded as special hex codes
    --   digit7=0, digit6=0, digit5=unit-label, digit4=blank
    -- Lower nibble: numeric digits
    -- =========================================================================
    process(unit_code, thousands, hundreds, tens, ones)
    begin
        -- Upper 4 digits: show unit abbreviation
        digit7 <= "0000"; -- blank
        digit6 <= "0000"; -- blank
        -- Encode unit in digit5 as hex letter displayed by 7-seg:
        -- 0=blank, 1=V, 2=m, 3=u, 4=ms(show 'S')
        case unit_code is
            when "001" => digit5 <= "1010"; -- 'A' placeholder â†’ wire-decode below as 'V'
            when "010" => digit5 <= "1011"; -- 'b' â†’ 'm'
            when "011" => digit5 <= "1100"; -- 'C' â†’ 'u'
            when "100" => digit5 <= "1101"; -- 'd' â†’ 'm' (ms)
            when others => digit5 <= "0000";
        end case;
        digit4 <= "0000"; -- blank separator

        -- Lower 4 digits: numeric value
        digit3 <= std_logic_vector(thousands);
        digit2 <= std_logic_vector(hundreds);
        digit1 <= std_logic_vector(tens);
        digit0 <= std_logic_vector(ones);

        dp <= "00000000"; -- no decimal points by default
    end process;

end Behavioral;
```

## oscilloscope_features.vhd

```vhdl

-- =============================================================================
-- oscilloscope_features.vhd  (Nexys4 DDR version)
-- Button debounce + control state machine.
-- Identical logic to reference design; ported for Nexys4 DDR button layout.
--
-- Button mapping (Nexys4 DDR):
--   BTNL  = btn_left   (CPU_RESET is separate)
--   BTNR  = btn_right
--   BTNU  = btn_up
--   BTND  = btn_down
--   BTNC  = btn_center
--
-- Switch mapping:
--   SW0  = Stop (low) / Run (high)   [run_mode = NOT SW0]
--   SW12 = Auto-trigger mode
--   SW13 = Free-run mode
--   SW14 = Auto-scale mode
--   SW15 = Test waveform mode
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity oscilloscope_features is
    Port (
        clk           : in  STD_LOGIC;
        reset         : in  STD_LOGIC;

        btn_up        : in  STD_LOGIC;
        btn_down      : in  STD_LOGIC;
        btn_left      : in  STD_LOGIC;
        btn_right     : in  STD_LOGIC;
        btn_center    : in  STD_LOGIC;

        sw            : in  STD_LOGIC_VECTOR(15 downto 0);

        adc_valid_in  : in  STD_LOGIC;

        run_mode      : out STD_LOGIC;

        trigger_level    : out STD_LOGIC_VECTOR(11 downto 0);
        vertical_pos     : out STD_LOGIC_VECTOR(9 downto 0);
        horizontal_scale : out STD_LOGIC_VECTOR(3 downto 0);
        volts_per_div    : out STD_LOGIC_VECTOR(3 downto 0);
        time_per_div     : out STD_LOGIC_VECTOR(3 downto 0);

        status         : out STD_LOGIC_VECTOR(3 downto 0);
        active_control : out STD_LOGIC_VECTOR(2 downto 0);

        auto_trig_in   : in  STD_LOGIC_VECTOR(11 downto 0)
    );
end oscilloscope_features;

architecture Behavioral of oscilloscope_features is

    -- Debounced button signals
    signal btn_up_deb, btn_down_deb, btn_left_deb,
           btn_right_deb, btn_center_deb : STD_LOGIC := '0';

    signal btn_up_prev, btn_down_prev, btn_left_prev,
           btn_right_prev, btn_center_prev : STD_LOGIC := '0';

    signal btn_up_pulse, btn_down_pulse, btn_left_pulse,
           btn_right_pulse, btn_center_pulse : STD_LOGIC := '0';

    type debounce_array is array (4 downto 0) of unsigned(19 downto 0);
    signal debounce_counter : debounce_array := (others => (others => '0'));

    -- Control modes
    type mode_type is (MODE_NORMAL, MODE_TRIGGER, MODE_VPOS,
                       MODE_HSCALE, MODE_VOLTS_DIV, MODE_TIME_DIV);
    signal current_mode : mode_type := MODE_NORMAL;

    -- Parameter registers
    signal trigger_level_reg : unsigned(11 downto 0) := X"800";     -- mid-scale
    signal vertical_pos_reg  : unsigned(9 downto 0)  := to_unsigned(240, 10);
    signal horiz_scale_reg   : unsigned(3 downto 0)  := "0001";
    signal volts_per_div_reg : unsigned(3 downto 0)  := "0100";     -- 1 V/div
    signal time_per_div_reg  : unsigned(3 downto 0)  := "0110";     -- 100 Âµs/div
    signal run_mode_reg      : STD_LOGIC := '1';

    signal status_reg        : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    signal active_control_reg: STD_LOGIC_VECTOR(2 downto 0) := "000";

    signal auto_trigger_counter : unsigned(19 downto 0) := (others => '0');
    signal auto_mode_active     : STD_LOGIC := '0';

    -- Debounce threshold: 10 ms at 100 MHz = 1_000_000 cycles
    constant DEBOUNCE_LIMIT : unsigned(19 downto 0) := to_unsigned(999999, 20);

begin

    -- =========================================================================
    -- Debounce all five buttons
    -- =========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                for i in 0 to 4 loop
                    debounce_counter(i) <= (others => '0');
                end loop;
                btn_up_deb     <= '0';
                btn_down_deb   <= '0';
                btn_left_deb   <= '0';
                btn_right_deb  <= '0';
                btn_center_deb <= '0';
            else
                -- BTN_UP
                if btn_up = '1' then
                    if debounce_counter(0) < DEBOUNCE_LIMIT then
                        debounce_counter(0) <= debounce_counter(0) + 1;
                    else
                        btn_up_deb <= '1';
                    end if;
                else
                    debounce_counter(0) <= (others => '0');
                    btn_up_deb <= '0';
                end if;
                -- BTN_DOWN
                if btn_down = '1' then
                    if debounce_counter(1) < DEBOUNCE_LIMIT then
                        debounce_counter(1) <= debounce_counter(1) + 1;
                    else
                        btn_down_deb <= '1';
                    end if;
                else
                    debounce_counter(1) <= (others => '0');
                    btn_down_deb <= '0';
                end if;
                -- BTN_LEFT
                if btn_left = '1' then
                    if debounce_counter(2) < DEBOUNCE_LIMIT then
                        debounce_counter(2) <= debounce_counter(2) + 1;
                    else
                        btn_left_deb <= '1';
                    end if;
                else
                    debounce_counter(2) <= (others => '0');
                    btn_left_deb <= '0';
                end if;
                -- BTN_RIGHT
                if btn_right = '1' then
                    if debounce_counter(3) < DEBOUNCE_LIMIT then
                        debounce_counter(3) <= debounce_counter(3) + 1;
                    else
                        btn_right_deb <= '1';
                    end if;
                else
                    debounce_counter(3) <= (others => '0');
                    btn_right_deb <= '0';
                end if;
                -- BTN_CENTER
                if btn_center = '1' then
                    if debounce_counter(4) < DEBOUNCE_LIMIT then
                        debounce_counter(4) <= debounce_counter(4) + 1;
                    else
                        btn_center_deb <= '1';
                    end if;
                else
                    debounce_counter(4) <= (others => '0');
                    btn_center_deb <= '0';
                end if;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- Rising-edge pulse detection
    -- =========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            btn_up_prev     <= btn_up_deb;
            btn_down_prev   <= btn_down_deb;
            btn_left_prev   <= btn_left_deb;
            btn_right_prev  <= btn_right_deb;
            btn_center_prev <= btn_center_deb;

            btn_up_pulse     <= btn_up_deb     and not btn_up_prev;
            btn_down_pulse   <= btn_down_deb   and not btn_down_prev;
            btn_left_pulse   <= btn_left_deb   and not btn_left_prev;
            btn_right_pulse  <= btn_right_deb  and not btn_right_prev;
            btn_center_pulse <= btn_center_deb and not btn_center_prev;
        end if;
    end process;

    -- =========================================================================
    -- Main control state machine
    -- =========================================================================
    process(clk)
        variable next_trigger_level : unsigned(11 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                current_mode      <= MODE_NORMAL;
                trigger_level_reg <= X"800";
                vertical_pos_reg  <= to_unsigned(240, 10);
                horiz_scale_reg   <= "0001";
                volts_per_div_reg <= "0100";
                time_per_div_reg  <= "0110";
                run_mode_reg      <= '1';
                status_reg        <= "0000";
                active_control_reg<= "000";
                auto_trigger_counter <= (others => '0');
                auto_mode_active  <= '0';
            else
                auto_mode_active <= sw(12);
                run_mode_reg     <= not sw(0);   -- SW0=1 â†’ STOP

                next_trigger_level := trigger_level_reg;

                -- Auto-trigger: slowly track signal midpoint
                if auto_mode_active = '1' then
                    if auto_trigger_counter < 1000 then
                        auto_trigger_counter <= auto_trigger_counter + 1;
                    else
                        auto_trigger_counter <= (others => '0');
                        next_trigger_level := unsigned(auto_trig_in);
                    end if;
                else
                    auto_trigger_counter <= (others => '0');

                    -- Mode cycling via BTNC
                    if btn_center_pulse = '1' then
                        case current_mode is
                            when MODE_NORMAL =>
                                current_mode       <= MODE_TRIGGER;
                                status_reg         <= "0001";
                                active_control_reg <= "000";
                            when MODE_TRIGGER =>
                                current_mode       <= MODE_VPOS;
                                status_reg         <= "0010";
                                active_control_reg <= "001";
                            when MODE_VPOS =>
                                current_mode       <= MODE_VOLTS_DIV;
                                status_reg         <= "0100";
                                active_control_reg <= "011";
                            when MODE_HSCALE =>
                                current_mode       <= MODE_VOLTS_DIV;
                                status_reg         <= "0100";
                                active_control_reg <= "011";
                            when MODE_VOLTS_DIV =>
                                current_mode       <= MODE_TIME_DIV;
                                status_reg         <= "0101";
                                active_control_reg <= "100";
                            when MODE_TIME_DIV =>
                                current_mode       <= MODE_NORMAL;
                                status_reg         <= "0000";
                                active_control_reg <= "000";
                        end case;
                    end if;

                    -- Parameter adjustment
                    case current_mode is
                        when MODE_NORMAL => null;

                        when MODE_TRIGGER =>
                            if btn_up_pulse = '1' then
                                if next_trigger_level < 4000 then
                                    next_trigger_level := next_trigger_level + 50;
                                end if;
                            elsif btn_down_pulse = '1' then
                                if next_trigger_level > 50 then
                                    next_trigger_level := next_trigger_level - 50;
                                end if;
                            end if;

                        when MODE_VPOS =>
                            if btn_up_pulse = '1' then
                                if vertical_pos_reg > 20 then
                                    vertical_pos_reg <= vertical_pos_reg - 5;
                                end if;
                            elsif btn_down_pulse = '1' then
                                if vertical_pos_reg < 460 then
                                    vertical_pos_reg <= vertical_pos_reg + 5;
                                end if;
                            end if;

                        when MODE_HSCALE => null;

                        when MODE_VOLTS_DIV =>
                            if btn_up_pulse = '1' then
                                if volts_per_div_reg < 7 then
                                    volts_per_div_reg <= volts_per_div_reg + 1;
                                end if;
                            elsif btn_down_pulse = '1' then
                                if volts_per_div_reg > 0 then
                                    volts_per_div_reg <= volts_per_div_reg - 1;
                                end if;
                            end if;

                        when MODE_TIME_DIV =>
                            if btn_right_pulse = '1' then
                                if time_per_div_reg < 15 then
                                    time_per_div_reg <= time_per_div_reg + 1;
                                end if;
                            elsif btn_left_pulse = '1' then
                                if time_per_div_reg > 0 then
                                    time_per_div_reg <= time_per_div_reg - 1;
                                end if;
                            end if;
                    end case;
                end if;

                trigger_level_reg <= next_trigger_level;
            end if;
        end if;
    end process;

    -- Outputs
    trigger_level    <= std_logic_vector(trigger_level_reg);
    vertical_pos     <= std_logic_vector(vertical_pos_reg);
    horizontal_scale <= std_logic_vector(horiz_scale_reg);
    volts_per_div    <= std_logic_vector(volts_per_div_reg);
    time_per_div     <= std_logic_vector(time_per_div_reg);
    run_mode         <= run_mode_reg;
    status           <= status_reg;
    active_control   <= active_control_reg;

end Behavioral;
```

## oscilloscope_top.vhd

```vhdl

-- =============================================================================
-- oscilloscope_top.vhd (Nexys4 DDR Version)
-- Main top-level module connecting all sub-modules for the FPGA oscilloscope.
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity oscilloscope_top is
    Port ( 
        clk           : in  STD_LOGIC;                    -- 100 MHz clock
        reset         : in  STD_LOGIC;                    -- CPU_RESET (active low on board, usually)
        
        -- Nexys4 DDR Buttons
        btnU          : in  STD_LOGIC;                     
        btnD          : in  STD_LOGIC;                    
        btnL          : in  STD_LOGIC;                    
        btnR          : in  STD_LOGIC;                     
        btnC          : in  STD_LOGIC;                     
        
        -- Nexys4 DDR Switches (16)
        sw            : in  STD_LOGIC_VECTOR(15 downto 0); 
  
        -- Analog Inputs (VAUX3)
        vauxp3        : in  STD_LOGIC;                     
        vauxn3        : in  STD_LOGIC;                   
        
        -- VGA Outputs
        vga_hsync     : out STD_LOGIC;                     
        vga_vsync     : out STD_LOGIC;                     
        vga_red       : out STD_LOGIC_VECTOR(3 downto 0);  
        vga_green     : out STD_LOGIC_VECTOR(3 downto 0);  
        vga_blue      : out STD_LOGIC_VECTOR(3 downto 0);  
        
        -- Nexys4 DDR LEDs (16)
        led           : out STD_LOGIC_VECTOR(15 downto 0); 
        
        -- 8-digit 7-segment display
        seg           : out STD_LOGIC_VECTOR(6 downto 0);  
        dp_out        : out STD_LOGIC;                     
        an            : out STD_LOGIC_VECTOR(7 downto 0)   
    );
end oscilloscope_top;

architecture Behavioral of oscilloscope_top is
 
    -- Components
    component xadc_module is
        Port ( 
            clk         : in  STD_LOGIC;
            reset       : in  STD_LOGIC;
            vauxp3      : in  STD_LOGIC;
            vauxn3      : in  STD_LOGIC;
            vp_in       : in  STD_LOGIC := '0';
            vn_in       : in  STD_LOGIC := '0';
            adc_data    : out STD_LOGIC_VECTOR(11 downto 0);
            adc_valid   : out STD_LOGIC
        );
    end component;
    
    component vga_controller is
        Port (
            clk           : in  STD_LOGIC;
            reset         : in  STD_LOGIC;
            vga_hsync     : out STD_LOGIC;
            vga_vsync     : out STD_LOGIC;
            vga_red       : out STD_LOGIC_VECTOR(3 downto 0);
            vga_green     : out STD_LOGIC_VECTOR(3 downto 0);
            vga_blue      : out STD_LOGIC_VECTOR(3 downto 0);
            pixel_x       : out STD_LOGIC_VECTOR(9 downto 0);
            pixel_y       : out STD_LOGIC_VECTOR(9 downto 0);
            pixel_active  : out STD_LOGIC
        );
    end component;
    
    component block_ram is
        Generic (
            ADDR_WIDTH : integer := 10;
            DATA_WIDTH : integer := 12
        );
        Port (
            clk         : in  STD_LOGIC;
            write_en    : in  STD_LOGIC;
            write_addr  : in  STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
            write_data  : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
            read_addr   : in  STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
            read_data   : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0)
        );
    end component;
    
    component oscilloscope_features is
        Port ( 
            clk            : in  STD_LOGIC;
            reset          : in  STD_LOGIC;
            btn_up         : in  STD_LOGIC;
            btn_down       : in  STD_LOGIC;
            btn_left       : in  STD_LOGIC;
            btn_right      : in  STD_LOGIC;
            btn_center     : in  STD_LOGIC;
            sw             : in  STD_LOGIC_VECTOR(15 downto 0);
            adc_valid_in   : in  STD_LOGIC;
            run_mode       : out STD_LOGIC;
            trigger_level  : out STD_LOGIC_VECTOR(11 downto 0);
            vertical_pos   : out STD_LOGIC_VECTOR(9 downto 0);
            horizontal_scale : out STD_LOGIC_VECTOR(3 downto 0);
            volts_per_div  : out STD_LOGIC_VECTOR(3 downto 0);
            time_per_div   : out STD_LOGIC_VECTOR(3 downto 0);
            status         : out STD_LOGIC_VECTOR(3 downto 0);
            active_control : out STD_LOGIC_VECTOR(2 downto 0);
            auto_trig_in   : in  STD_LOGIC_VECTOR(11 downto 0)  
        );
    end component;
    
    component seven_segment_driver is
        Port ( 
            clk          : in  STD_LOGIC;
            reset        : in  STD_LOGIC;
            digit7       : in  STD_LOGIC_VECTOR(3 downto 0);
            digit6       : in  STD_LOGIC_VECTOR(3 downto 0);
            digit5       : in  STD_LOGIC_VECTOR(3 downto 0);
            digit4       : in  STD_LOGIC_VECTOR(3 downto 0);
            digit3       : in  STD_LOGIC_VECTOR(3 downto 0);
            digit2       : in  STD_LOGIC_VECTOR(3 downto 0);
            digit1       : in  STD_LOGIC_VECTOR(3 downto 0);
            digit0       : in  STD_LOGIC_VECTOR(3 downto 0);
            dp           : in  STD_LOGIC_VECTOR(7 downto 0);
            seg          : out STD_LOGIC_VECTOR(6 downto 0);
            dp_out       : out STD_LOGIC;
            an           : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;
    
    component display_decoder is
        Port ( 
            clk             : in  STD_LOGIC;
            reset           : in  STD_LOGIC;
            active_control  : in  STD_LOGIC_VECTOR(2 downto 0);
            volts_per_div   : in  STD_LOGIC_VECTOR(3 downto 0);
            time_per_div    : in  STD_LOGIC_VECTOR(3 downto 0);
            trigger_level   : in  STD_LOGIC_VECTOR(11 downto 0);
            digit7          : out STD_LOGIC_VECTOR(3 downto 0);
            digit6          : out STD_LOGIC_VECTOR(3 downto 0);
            digit5          : out STD_LOGIC_VECTOR(3 downto 0);
            digit4          : out STD_LOGIC_VECTOR(3 downto 0);
            digit3          : out STD_LOGIC_VECTOR(3 downto 0);
            digit2          : out STD_LOGIC_VECTOR(3 downto 0);
            digit1          : out STD_LOGIC_VECTOR(3 downto 0);
            digit0          : out STD_LOGIC_VECTOR(3 downto 0);
            dp              : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;
    
    component simple_text_display is
        Port ( 
            clk          : in  STD_LOGIC;
            reset        : in  STD_LOGIC;
            pixel_x      : in  STD_LOGIC_VECTOR(9 downto 0);
            pixel_y      : in  STD_LOGIC_VECTOR(9 downto 0);
            text_enable  : in  STD_LOGIC;
            volts_per_div : in STD_LOGIC_VECTOR(3 downto 0);
            time_per_div : in STD_LOGIC_VECTOR(3 downto 0);
            trigger_level : in STD_LOGIC_VECTOR(11 downto 0);
            is_running   : in STD_LOGIC;
            draw_text    : out STD_LOGIC;
            text_rgb     : out STD_LOGIC_VECTOR(11 downto 0)
        );
    end component;

    -- Constants
    constant RAM_ADDR_WIDTH : integer := 10;
    constant RAM_DATA_WIDTH : integer := 12;
    
    constant COLOR_BACKGROUND : STD_LOGIC_VECTOR(11 downto 0) := X"111";
    constant COLOR_GRID       : STD_LOGIC_VECTOR(11 downto 0) := X"33F";
    constant COLOR_AXIS       : STD_LOGIC_VECTOR(11 downto 0) := X"77F";
    constant COLOR_WAVEFORM   : STD_LOGIC_VECTOR(11 downto 0) := X"0F0";
    constant COLOR_TRIGGER    : STD_LOGIC_VECTOR(11 downto 0) := X"F00";
    
    -- Scales (Imported from Basys3 repo logic)
    type volts_array is array(0 to 15) of unsigned(12 downto 0);
    constant VOLTS_SCALE : volts_array := (
        to_unsigned(4095, 13),  -- 0: 0.05V/div
        to_unsigned(2048, 13),  -- 1: 0.1V/div 
        to_unsigned(1024, 13),  -- 2: 0.2V/div
        to_unsigned(410, 13),   -- 3: 0.5V/div
        to_unsigned(205, 13),   -- 4: 1V/div
        to_unsigned(102, 13),   -- 5: 2V/div
        to_unsigned(41, 13),    -- 6: 5V/div
        to_unsigned(20, 13),    -- 7: 10V/div 
        others => to_unsigned(205, 13)
    );

    type time_array is array(0 to 15) of unsigned(16 downto 0);
    constant TIME_SCALE : time_array := (
        to_unsigned(10, 17),      -- 0: 1us/div 
        to_unsigned(20, 17),      
        to_unsigned(50, 17),      
        to_unsigned(100, 17),     
        to_unsigned(200, 17),     
        to_unsigned(500, 17),     
        to_unsigned(1000, 17),    
        to_unsigned(2000, 17),    
        to_unsigned(5000, 17),    
        to_unsigned(10000, 17),   
        to_unsigned(20000, 17),   
        to_unsigned(50000, 17),   
        to_unsigned(100000, 17),  
        to_unsigned(20000, 17),   
        to_unsigned(50000, 17),   
        to_unsigned(100000, 17)   
    );

    -- Signals
    signal adc_data       : STD_LOGIC_VECTOR(11 downto 0);
    signal adc_valid      : STD_LOGIC;
    signal pixel_x        : STD_LOGIC_VECTOR(9 downto 0);
    signal pixel_y        : STD_LOGIC_VECTOR(9 downto 0);
    signal pixel_active   : STD_LOGIC;
    
    signal ram_write_en   : STD_LOGIC := '0';
    signal ram_write_addr : STD_LOGIC_VECTOR(RAM_ADDR_WIDTH-1 downto 0);
    signal ram_write_data : STD_LOGIC_VECTOR(RAM_DATA_WIDTH-1 downto 0);
    signal ram_read_addr  : STD_LOGIC_VECTOR(RAM_ADDR_WIDTH-1 downto 0);
    signal ram_read_data  : STD_LOGIC_VECTOR(RAM_DATA_WIDTH-1 downto 0);
    
    signal run_mode       : STD_LOGIC;
    signal trigger_level  : STD_LOGIC_VECTOR(11 downto 0);
    signal vertical_pos   : STD_LOGIC_VECTOR(9 downto 0);
    signal volts_per_div  : STD_LOGIC_VECTOR(3 downto 0);
    signal time_per_div   : STD_LOGIC_VECTOR(3 downto 0);
    signal status         : STD_LOGIC_VECTOR(3 downto 0);
    signal active_control : STD_LOGIC_VECTOR(2 downto 0);
    
    signal digit7, digit6, digit5, digit4, digit3, digit2, digit1, digit0 : STD_LOGIC_VECTOR(3 downto 0);
    signal decimal_points : STD_LOGIC_VECTOR(7 downto 0);
    
    signal text_draw      : STD_LOGIC;
    signal text_rgb       : STD_LOGIC_VECTOR(11 downto 0);
    
    -- Internal Control Logic
    signal sample_counter : unsigned(19 downto 0) := (others => '0');
    signal write_ptr      : unsigned(RAM_ADDR_WIDTH-1 downto 0) := (others => '0');
    signal trigger_ptr_cap: unsigned(RAM_ADDR_WIDTH-1 downto 0) := (others => '0');
    signal display_ptr_base: unsigned(RAM_ADDR_WIDTH-1 downto 0) := (others => '0');
    signal trigger_fired  : STD_LOGIC := '0';
    signal trigger_armed  : STD_LOGIC := '1';
    signal data_written   : STD_LOGIC := '0';
    signal data_count     : unsigned(RAM_ADDR_WIDTH-1 downto 0) := (others => '0');
    
    -- Waveform Display
    type waveform_buffer_type is array(0 to 639) of unsigned(9 downto 0);
    signal waveform_buffer : waveform_buffer_type := (others => (others => '0'));
    signal waveform_valid  : STD_LOGIC_VECTOR(639 downto 0) := (others => '0');
    
    signal scaled_adc     : unsigned(9 downto 0);
    signal scaled_trigger : unsigned(9 downto 0);
    
    signal test_wave      : unsigned(11 downto 0) := (others => '0');
    signal debug_counter  : unsigned(23 downto 0) := (others => '0');
    signal triangle_dir   : std_logic := '0';

    type sine_lut_type is array (0 to 31) of unsigned(11 downto 0);
    constant SINE_LUT : sine_lut_type := (
        to_unsigned(2048, 12), to_unsigned(2447, 12), to_unsigned(2831, 12), to_unsigned(3185, 12), 
        to_unsigned(3495, 12), to_unsigned(3750, 12), to_unsigned(3939, 12), to_unsigned(4056, 12), 
        to_unsigned(4095, 12), to_unsigned(4056, 12), to_unsigned(3939, 12), to_unsigned(3750, 12), 
        to_unsigned(3495, 12), to_unsigned(3185, 12), to_unsigned(2831, 12), to_unsigned(2447, 12), 
        to_unsigned(2048, 12), to_unsigned(1649, 12), to_unsigned(1265, 12), to_unsigned(911, 12), 
        to_unsigned(601, 12), to_unsigned(346, 12), to_unsigned(157, 12), to_unsigned(40, 12), 
        to_unsigned(0, 12), to_unsigned(40, 12), to_unsigned(157, 12), to_unsigned(346, 12), 
        to_unsigned(601, 12), to_unsigned(911, 12), to_unsigned(1265, 12), to_unsigned(1649, 12)
    );

    signal scaled_wave_val : std_logic_vector(11 downto 0);
    signal scaled_trig_val : std_logic_vector(11 downto 0);

    -- Auto Scale / Trig
    signal auto_trigger_level : std_logic_vector(11 downto 0) := (others => '0');

    -- Internal active-high reset
    signal sys_reset : std_logic;

begin

    -- Nexys4 DDR CPU_RESET button is active-low (0 when pressed).
    -- Internal logic expects active-high (1 when resetting).
    sys_reset <= not reset;
    
    xadc_inst : xadc_module
        port map (
            clk       => clk,
            reset     => sys_reset,
            vauxp3    => vauxp3,
            vauxn3    => vauxn3,
            adc_data  => adc_data,
            adc_valid => adc_valid
        );
        
    vga_inst : vga_controller
        port map (
            clk          => clk,
            reset        => sys_reset,
            vga_hsync    => vga_hsync,
            vga_vsync    => vga_vsync,
            vga_red      => open, -- Handled below
            vga_green    => open,
            vga_blue     => open,
            pixel_x      => pixel_x,
            pixel_y      => pixel_y,
            pixel_active => pixel_active
        );
        
    ram_inst : block_ram
        generic map (ADDR_WIDTH => RAM_ADDR_WIDTH, DATA_WIDTH => RAM_DATA_WIDTH)
        port map (
            clk        => clk,
            write_en   => ram_write_en,
            write_addr => ram_write_addr,
            write_data => ram_write_data,
            read_addr  => ram_read_addr,
            read_data  => ram_read_data
        );
        
    features_inst : oscilloscope_features
        port map (
            clk             => clk,
            reset           => sys_reset,
            btn_up          => btnU,
            btn_down        => btnD,
            btn_left        => btnL,
            btn_right       => btnR,
            btn_center      => btnC,
            sw              => sw,
            adc_valid_in    => adc_valid,
            run_mode        => run_mode,
            trigger_level   => trigger_level,
            vertical_pos    => vertical_pos,
            volts_per_div   => volts_per_div,
            time_per_div    => time_per_div,
            status          => status,
            active_control  => active_control,
            auto_trig_in    => auto_trigger_level
        );
        
    decoder_inst : display_decoder
        port map (
            clk             => clk,
            reset           => sys_reset,
            active_control  => active_control,
            volts_per_div   => volts_per_div,
            time_per_div    => time_per_div,
            trigger_level   => trigger_level,
            digit7          => digit7, digit6 => digit6, digit5 => digit5, digit4 => digit4,
            digit3          => digit3, digit2 => digit2, digit1 => digit1, digit0 => digit0,
            dp              => decimal_points
        );
        
    seven_seg_inst : seven_segment_driver
        port map (
            clk      => clk,
            reset    => sys_reset,
            digit7   => digit7, digit6 => digit6, digit5 => digit5, digit4 => digit4,
            digit3   => digit3, digit2 => digit2, digit1 => digit1, digit0 => digit0,
            dp       => decimal_points,
            seg      => seg,
            dp_out   => dp_out,
            an       => an
        );
        
    text_inst : simple_text_display
        port map (
            clk           => clk,
            reset         => sys_reset,
            pixel_x       => pixel_x,
            pixel_y       => pixel_y,
            text_enable   => '1',
            volts_per_div => volts_per_div,
            time_per_div  => time_per_div,
            trigger_level => trigger_level,
            is_running    => run_mode,
            draw_text     => text_draw,
            text_rgb      => text_rgb
        );

    -- Scaling Logic
    process(clk)
        variable raw_val : unsigned(11 downto 0);
        variable scaled : unsigned(11 downto 0);
    begin
        if rising_edge(clk) then
            if sys_reset = '1' then
                scaled_wave_val <= (others => '0');
                scaled_trig_val <= (others => '0');
            else
                -- Scale Waveform
                raw_val := unsigned(ram_read_data);
                case volts_per_div is
                    when "0000" => scaled := shift_right(raw_val, 3)(11 downto 0); -- High Gain
                    when "0001" => scaled := shift_right(raw_val, 4)(11 downto 0); 
                    when "0010" => scaled := shift_right(raw_val, 5)(11 downto 0); 
                    when others => scaled := shift_right(raw_val, 6)(11 downto 0); -- Low Gain
                end case;
                scaled_wave_val <= std_logic_vector(scaled);

                -- Scale Trigger
                raw_val := unsigned(trigger_level);
                case volts_per_div is
                    when "0000" => scaled := shift_right(raw_val, 3)(11 downto 0);
                    when "0001" => scaled := shift_right(raw_val, 4)(11 downto 0);
                    when "0010" => scaled := shift_right(raw_val, 5)(11 downto 0);
                    when others => scaled := shift_right(raw_val, 6)(11 downto 0);
                end case;
                scaled_trig_val <= std_logic_vector(scaled);
            end if;
        end if;
    end process;


    -- Sampling and Storage
    process(clk)
        variable actual_data : STD_LOGIC_VECTOR(11 downto 0);
        variable time_factor : unsigned(16 downto 0);
    begin
        if rising_edge(clk) then
            if sys_reset = '1' then
                sample_counter <= (others => '0');
                write_ptr <= (others => '0');
                trigger_armed <= '1';
                trigger_fired <= '0';
                data_written <= '0';
                test_wave <= (others => '0');
            else
                ram_write_en <= '0';
                time_factor := TIME_SCALE(to_integer(unsigned(time_per_div)));
                -- Sample Clock Divider (Timebase)
                if sample_counter >= time_factor then
                    sample_counter <= (others => '0');
                    
                    -- Test Wave Generation or ADC Input
                    if sw(15) = '1' then
                        -- SW(11 downto 10): 00=Square, 01=Sawtooth, 10=Triangle, 11=Sine
                        if sw(11 downto 10) = "01" then
                            -- Sawtooth Wave
                            test_wave <= test_wave + 64; 
                            actual_data := std_logic_vector(test_wave);
                        elsif sw(11 downto 10) = "10" then
                            -- Triangle Wave
                            if triangle_dir = '0' then
                                if test_wave >= 4095 - 64 then
                                    triangle_dir <= '1';
                                else
                                    test_wave <= test_wave + 64;
                                end if;
                            else
                                if test_wave <= 64 then
                                    triangle_dir <= '0';
                                else
                                    test_wave <= test_wave - 64;
                                end if;
                            end if;
                            actual_data := std_logic_vector(test_wave);
                        elsif sw(11 downto 10) = "11" then
                            -- Sine Wave (32 samples per cycle)
                            test_wave <= test_wave + 1;
                            actual_data := std_logic_vector(SINE_LUT(to_integer(test_wave(4 downto 0))));
                        else
                            -- Square Wave
                            if test_wave(11) = '1' then
                                actual_data := x"FFF";
                            else
                                actual_data := x"000";
                            end if;
                            test_wave <= test_wave + 128;
                        end if;
                    else
                        actual_data := adc_data;
                    end if;
                    
                    if run_mode = '1' then
                        -- Simple Trigger Logic
                        if trigger_fired = '0' and trigger_armed = '1' then
                            if unsigned(actual_data) >= unsigned(trigger_level) or sw(13) = '1' then
                                trigger_fired <= '1';
                                trigger_armed <= '0';
                                ram_write_en <= '1';
                                ram_write_addr <= std_logic_vector(write_ptr);
                                ram_write_data <= actual_data;
                                trigger_ptr_cap <= write_ptr;
                                write_ptr <= write_ptr + 1;
                                data_count <= (others => '0');
                            end if;
                        elsif trigger_fired = '1' then
                            ram_write_en <= '1';
                            ram_write_addr <= std_logic_vector(write_ptr);
                            ram_write_data <= actual_data;
                            write_ptr <= write_ptr + 1;
                            data_count <= data_count + 1;
                            if data_count = (2**RAM_ADDR_WIDTH - 2) then
                                trigger_fired <= '0';
                                trigger_armed <= '1';
                                display_ptr_base <= trigger_ptr_cap;
                                data_written <= '1';
                            end if;
                        end if;
                    end if;
                else
                    sample_counter <= sample_counter + 1;
                end if;
            end if;
        end if;
    end process;

    -- VGA Display Logic
    process(clk)
        variable x, y : integer;
        variable ram_addr : unsigned(RAM_ADDR_WIDTH-1 downto 0);
        variable wave_y : unsigned(9 downto 0);
        variable y_val : integer;
        variable current_color : STD_LOGIC_VECTOR(11 downto 0);
    begin
        if rising_edge(clk) then
            x := to_integer(unsigned(pixel_x));
            y := to_integer(unsigned(pixel_y));
            
            -- Cache waveform for current scanline
            if y = 0 and pixel_active = '1' then
                ram_addr := display_ptr_base + to_unsigned(x, RAM_ADDR_WIDTH);
                ram_read_addr <= std_logic_vector(ram_addr);
                
                y_val := 240 - to_integer(unsigned(scaled_wave_val)) + to_integer(unsigned(vertical_pos));
                if y_val < 0 then
                    wave_y := (others => '0');
                elsif y_val > 479 then
                    wave_y := to_unsigned(479, 10);
                else
                    wave_y := to_unsigned(y_val, 10);
                end if;
                
                waveform_buffer(x) <= wave_y;
                waveform_valid(x) <= data_written;
            end if;
            
            -- Pixel Selection
            current_color := COLOR_BACKGROUND;
            if pixel_active = '1' then
                -- Grid
                if (x mod 64 = 0) or (y mod 60 = 0) then
                    current_color := COLOR_GRID;
                end if;
                -- Axes
                if x = 320 or y = 240 then
                    current_color := COLOR_AXIS;
                end if;
                -- Trigger Line
                y_val := 240 - to_integer(unsigned(scaled_trig_val)) + to_integer(unsigned(vertical_pos));
                if y = y_val then
                    current_color := COLOR_TRIGGER;
                end if;
                -- Waveform
                if waveform_valid(x) = '1' and y = to_integer(waveform_buffer(x)) then
                    current_color := COLOR_WAVEFORM;
                end if;
                -- Text
                if text_draw = '1' then
                    current_color := text_rgb;
                end if;
            end if;
            
            vga_red   <= current_color(11 downto 8);
            vga_green <= current_color(7 downto 4);
            vga_blue  <= current_color(3 downto 0);
        end if;
    end process;

    -- LED Debug
    led(0) <= run_mode;
    led(1) <= trigger_fired;
    led(2) <= trigger_armed;
    led(15 downto 12) <= status;

end Behavioral;
```

## seven_segment_driver.vhd

```vhdl

-- =============================================================================
-- seven_segment_driver.vhd  (Nexys4 DDR version)
-- Multiplexes 8 digits on the Nexys4 DDR 7-segment display.
-- The Nexys4 DDR has 8 digits driven by an 8-bit AN (anode) bus.
-- Digit select cycles at ~1 kHz per digit (800 Hz refresh / 8 = 100 Hz each)
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity seven_segment_driver is
    Port (
        clk     : in  STD_LOGIC;   -- 100 MHz
        reset   : in  STD_LOGIC;

        -- 8 BCD digit inputs (digit7 = leftmost AN7)
        digit7  : in  STD_LOGIC_VECTOR(3 downto 0);
        digit6  : in  STD_LOGIC_VECTOR(3 downto 0);
        digit5  : in  STD_LOGIC_VECTOR(3 downto 0);
        digit4  : in  STD_LOGIC_VECTOR(3 downto 0);
        digit3  : in  STD_LOGIC_VECTOR(3 downto 0);
        digit2  : in  STD_LOGIC_VECTOR(3 downto 0);
        digit1  : in  STD_LOGIC_VECTOR(3 downto 0);
        digit0  : in  STD_LOGIC_VECTOR(3 downto 0);
        dp      : in  STD_LOGIC_VECTOR(7 downto 0);  -- decimal point per digit

        seg    : out STD_LOGIC_VECTOR(6 downto 0);  -- cathode segments a-g
        dp_out : out STD_LOGIC;                      -- decimal point cathode
        an     : out STD_LOGIC_VECTOR(7 downto 0)   -- 8 anodes (active low)
    );
end seven_segment_driver;

architecture Behavioral of seven_segment_driver is

    -- Counter for multiplexing: 100 MHz / 2^17 â‰ˆ 763 Hz full cycle
    -- 3 MSBs select 1-of-8 digits â†’ each digit refreshed at ~95 Hz
    signal counter : unsigned(19 downto 0) := (others => '0');
    signal digit_sel : unsigned(2 downto 0);

    signal current_digit : STD_LOGIC_VECTOR(3 downto 0);
    signal current_dp    : STD_LOGIC;

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                counter <= (others => '0');
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;

    digit_sel <= counter(19 downto 17);   -- top 3 bits â†’ 0-7

    -- Mux digit inputs
    process(digit_sel, digit0, digit1, digit2, digit3,
            digit4, digit5, digit6, digit7, dp)
    begin
        case digit_sel is
            when "000" =>
                current_digit <= digit0; current_dp <= dp(0); an <= "11111110";
            when "001" =>
                current_digit <= digit1; current_dp <= dp(1); an <= "11111101";
            when "010" =>
                current_digit <= digit2; current_dp <= dp(2); an <= "11111011";
            when "011" =>
                current_digit <= digit3; current_dp <= dp(3); an <= "11110111";
            when "100" =>
                current_digit <= digit4; current_dp <= dp(4); an <= "11101111";
            when "101" =>
                current_digit <= digit5; current_dp <= dp(5); an <= "11011111";
            when "110" =>
                current_digit <= digit6; current_dp <= dp(6); an <= "10111111";
            when others =>
                current_digit <= digit7; current_dp <= dp(7); an <= "01111111";
        end case;
    end process;

    -- Segment decoder (active-low cathodes, common anode)
    -- Encoding: seg = {g, f, e, d, c, b, a}  (index 6 = g, index 0 = a)
    process(current_digit)
    begin
        case current_digit is
            when "0000" => seg <= "1000000"; -- 0
            when "0001" => seg <= "1111001"; -- 1
            when "0010" => seg <= "0100100"; -- 2
            when "0011" => seg <= "0110000"; -- 3
            when "0100" => seg <= "0011001"; -- 4
            when "0101" => seg <= "0010010"; -- 5
            when "0110" => seg <= "0000010"; -- 6
            when "0111" => seg <= "1111000"; -- 7
            when "1000" => seg <= "0000000"; -- 8
            when "1001" => seg <= "0010000"; -- 9
            when "1010" => seg <= "0001000"; -- A
            when "1011" => seg <= "0000011"; -- b
            when "1100" => seg <= "1000110"; -- C
            when "1101" => seg <= "0100001"; -- d
            when "1110" => seg <= "0000110"; -- E
            when "1111" => seg <= "0001110"; -- F
            when others => seg <= "1111111"; -- all off
        end case;
    end process;

    dp_out <= not current_dp;   -- active low

end Behavioral;
```

## simple_text_display.vhd

```vhdl

-- =============================================================================
-- simple_text_display.vhd  (Nexys4 DDR version)
-- Renders on-screen text overlay on the VGA display using a built-in
-- character ROM (8x16 pixel bitmap font).
--
-- Text areas:
--   Top-left  (x=10, y=4):  "VOLT/DIV: <value>"
--   Top-mid   (x=210,y=4):  "TIME/DIV: <value>"
--   Top-right (x=410,y=4):  "TRIG: <value>"
--   Bottom    (x=10, y=462):"STATUS: <RUN/STOP>"
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity simple_text_display is
    Port (
        clk           : in  STD_LOGIC;
        reset         : in  STD_LOGIC;
        pixel_x       : in  STD_LOGIC_VECTOR(9 downto 0);
        pixel_y       : in  STD_LOGIC_VECTOR(9 downto 0);
        text_enable   : in  STD_LOGIC;
        volts_per_div : in  STD_LOGIC_VECTOR(3 downto 0);
        time_per_div  : in  STD_LOGIC_VECTOR(3 downto 0);
        trigger_level : in  STD_LOGIC_VECTOR(11 downto 0);
        is_running    : in  STD_LOGIC;
        draw_text     : out STD_LOGIC;
        text_rgb      : out STD_LOGIC_VECTOR(11 downto 0)
    );
end simple_text_display;

architecture Behavioral of simple_text_display is

    constant MAX_STRING_LENGTH : integer := 20;
    constant CHAR_WIDTH        : integer := 8;
    constant CHAR_HEIGHT       : integer := 16;

    -- -------------------------------------------------------------------------
    -- 8x16 bitmap character ROM (subset of ASCII)
    -- Each row byte: bit7 = leftmost pixel
    -- -------------------------------------------------------------------------
    type rom_type is array (0 to 127, 0 to 15) of std_logic_vector(7 downto 0);

    constant CHAR_ROM : rom_type := (
        -- Space (32)
        32 => (others => "00000000"),
        -- '.' (46)
        46 => ("00000000","00000000","00000000","00000000",
                "00000000","00000000","00000000","00000000",
                "00000000","00011000","00011000","00000000",
                "00000000","00000000","00000000","00000000"),
        -- '/' (47)
        47 => ("00000000","00000000","00000000","00000010",
                "00000110","00001100","00011000","00110000",
                "01100000","11000000","10000000","00000000",
                "00000000","00000000","00000000","00000000"),
        -- '0' (48)
        48 => ("00000000","00111100","01100110","01100110",
                "01101110","01110110","01100110","01100110",
                "01100110","01100110","00111100","00000000",
                "00000000","00000000","00000000","00000000"),
        -- '1' (49)
        49 => ("00000000","00011000","00111000","01111000",
                "00011000","00011000","00011000","00011000",
                "00011000","00011000","01111110","00000000",
                "00000000","00000000","00000000","00000000"),
        -- '2' (50)
        50 => ("00000000","00111100","01100110","00000110",
                "00001100","00011000","00110000","01100000",
                "01100000","01100110","01111110","00000000",
                "00000000","00000000","00000000","00000000"),
        -- '3' (51)
        51 => ("00000000","00111100","01100110","00000110",
                "00000110","00011100","00000110","00000110",
                "00000110","01100110","00111100","00000000",
                "00000000","00000000","00000000","00000000"),
        -- '4' (52)
        52 => ("00000000","00001100","00011100","00111100",
                "01101100","01001100","11111110","00001100",
                "00001100","00001100","00011110","00000000",
                "00000000","00000000","00000000","00000000"),
        -- '5' (53)
        53 => ("00000000","01111110","01100000","01100000",
                "01100000","01111100","00000110","00000110",
                "00000110","01100110","00111100","00000000",
                "00000000","00000000","00000000","00000000"),
        -- ':' (58)
        58 => ("00000000","00000000","00000000","00011000",
                "00011000","00000000","00000000","00000000",
                "00011000","00011000","00000000","00000000",
                "00000000","00000000","00000000","00000000"),
        -- 'A' (65)
        65 => ("00000000","00010000","00111000","01101100",
                "11000110","11000110","11111110","11000110",
                "11000110","11000110","11000110","00000000",
                "00000000","00000000","00000000","00000000"),
        -- 'D' (68)
        68 => ("00000000","11111000","01101100","01100110",
                "01100110","01100110","01100110","01100110",
                "01100110","01101100","11111000","00000000",
                "00000000","00000000","00000000","00000000"),
        -- 'E' (69)
        69 => ("00000000","11111110","01100000","01100000",
                "01100000","01111100","01100000","01100000",
                "01100000","01100000","11111110","00000000",
                "00000000","00000000","00000000","00000000"),
        -- 'G' (71)
        71 => ("00000000","00111100","01100110","11000000",
                "11000000","11000000","11001110","11000110",
                "11000110","01100110","00111100","00000000",
                "00000000","00000000","00000000","00000000"),
        -- 'I' (73)
        73 => ("00000000","00111100","00011000","00011000",
                "00011000","00011000","00011000","00011000",
                "00011000","00011000","00111100","00000000",
                "00000000","00000000","00000000","00000000"),
        -- 'L' (76)
        76 => ("00000000","11110000","01100000","01100000",
                "01100000","01100000","01100000","01100000",
                "01100010","01100110","11111110","00000000",
                "00000000","00000000","00000000","00000000"),
        -- 'M' (77)
        77 => ("00000000","11000011","11100111","11111111",
                "11111111","11011011","11000011","11000011",
                "11000011","11000011","11000011","00000000",
                "00000000","00000000","00000000","00000000"),
        -- 'N' (78)
        78 => ("00000000","11000110","11100110","11110110",
                "11111110","11011110","11001110","11000110",
                "11000110","11000110","11000110","00000000",
                "00000000","00000000","00000000","00000000"),
        -- 'O' (79)
        79 => ("00000000","01111100","11000110","11000110",
                "11000110","11000110","11000110","11000110",
                "11000110","11000110","01111100","00000000",
                "00000000","00000000","00000000","00000000"),
        -- 'P' (80)
        80 => ("00000000","11111100","01100110","01100110",
                "01100110","01111100","01100000","01100000",
                "01100000","01100000","11110000","00000000",
                "00000000","00000000","00000000","00000000"),
        -- 'R' (82)
        82 => ("00000000","11111100","01100110","01100110",
                "01100110","01111100","01101100","01100110",
                "01100110","01100110","11100110","00000000",
                "00000000","00000000","00000000","00000000"),
        -- 'S' (83)
        83 => ("00000000","01111100","11000110","11000110",
                "01100000","00111000","00001100","00000110",
                "11000110","11000110","01111100","00000000",
                "00000000","00000000","00000000","00000000"),
        -- 'T' (84)
        84 => ("00000000","11111111","11011011","10011001",
                "00011000","00011000","00011000","00011000",
                "00011000","00011000","00111100","00000000",
                "00000000","00000000","00000000","00000000"),
        -- 'U' (85)
        85 => ("00000000","11000110","11000110","11000110",
                "11000110","11000110","11000110","11000110",
                "11000110","11000110","01111100","00000000",
                "00000000","00000000","00000000","00000000"),
        -- 'V' (86)
        86 => ("00000000","11000011","11000011","11000011",
                "11000011","11000011","11000011","11000011",
                "01100110","00111100","00011000","00000000",
                "00000000","00000000","00000000","00000000"),
        -- 'm' (109)
        109 => ("00000000","00000000","00000000","11100110",
                "11111111","11011011","11011011","11011011",
                "11011011","11011011","11011011","00000000",
                "00000000","00000000","00000000","00000000"),
        -- 's' (115)
        115 => ("00000000","00000000","00000000","00000000",
                "01111100","11000110","01100000","00111000",
                "00001100","11000110","01111100","00000000",
                "00000000","00000000","00000000","00000000"),
        -- 'u' (117)
        117 => ("00000000","00000000","00000000","00000000",
                "11000110","11000110","11000110","11000110",
                "11000110","11001110","01110110","00000000",
                "00000000","00000000","00000000","00000000"),
        -- '?' (63)
        63 => ("00000000","00000000","01111100","11000110",
                "11000110","00001100","00011000","00011000",
                "00011000","00000000","00011000","00011000",
                "00000000","00000000","00000000","00000000"),
        -- All other characters: blank
        others => (others => "00000000")
    );

    -- Text field records
    type text_pos_type is record
        x      : integer range 0 to 639;
        y      : integer range 0 to 479;
        text   : string(1 to MAX_STRING_LENGTH);
        length : integer range 0 to MAX_STRING_LENGTH;
    end record;

    type text_array is array(0 to 3) of text_pos_type;

    signal text_positions : text_array := (
        0 => (x => 10,  y => 4,   text => "VOLT/DIV:           ", length => 20),
        1 => (x => 210, y => 4,   text => "TIME/DIV:           ", length => 20),
        2 => (x => 410, y => 4,   text => "TRIG:               ", length => 20),
        3 => (x => 10,  y => 462, text => "STATUS:             ", length => 20)
    );

    -- Dynamic text strings
    signal volts_text : string(1 to 5) := "     ";
    signal time_text  : string(1 to 5) := "     ";
    signal trig_text  : string(1 to 5) := "     ";
    signal run_text   : string(1 to 4) := "    ";

    signal current_char  : character;
    signal char_addr     : std_logic_vector(6 downto 0);
    signal rom_addr      : integer range 0 to 15;
    signal rom_data      : std_logic_vector(7 downto 0);
    signal pixel_in_text : std_logic := '0';
    signal text_bit_on   : std_logic := '0';
    signal current_x     : integer;
    signal current_y     : integer;

begin

    -- =========================================================================
    -- Dynamic string generators (combinational)
    -- =========================================================================
    process(volts_per_div)
    begin
        case to_integer(unsigned(volts_per_div)) is
            when 0 => volts_text <= "0.05V";
            when 1 => volts_text <= "0.1V ";
            when 2 => volts_text <= "0.2V ";
            when 3 => volts_text <= "0.5V ";
            when 4 => volts_text <= "1V   ";
            when 5 => volts_text <= "2V   ";
            when 6 => volts_text <= "5V   ";
            when 7 => volts_text <= "10V  ";
            when others => volts_text <= "?V   ";
        end case;
    end process;

    process(time_per_div)
    begin
        case to_integer(unsigned(time_per_div)) is
            when 0  => time_text <= "1us  ";
            when 1  => time_text <= "2us  ";
            when 2  => time_text <= "5us  ";
            when 3  => time_text <= "10us ";
            when 4  => time_text <= "20us ";
            when 5  => time_text <= "50us ";
            when 6  => time_text <= "100us";
            when 7  => time_text <= "200us";
            when 8  => time_text <= "500us";
            when 9  => time_text <= "1ms  ";
            when 10 => time_text <= "2ms  ";
            when 11 => time_text <= "5ms  ";
            when 12 => time_text <= "10ms ";
            when 13 => time_text <= "20ms ";
            when 14 => time_text <= "50ms ";
            when 15 => time_text <= "100ms";
            when others => time_text <= "?    ";
        end case;
    end process;

    process(trigger_level)
        variable trig_val  : integer;
        variable h, t, o   : integer;
    begin
        trig_val := to_integer(unsigned(trigger_level));
        h := trig_val / 100;
        t := (trig_val / 10) mod 10;
        o := trig_val mod 10;
        if trig_val < 1000 then
            trig_text(1) <= character'val(48 + h);
            trig_text(2) <= character'val(48 + t);
            trig_text(3) <= character'val(48 + o);
            trig_text(4) <= ' ';
            trig_text(5) <= ' ';
        else
            trig_text <= "?????" ;
        end if;
    end process;

    process(is_running)
    begin
        if is_running = '1' then
            run_text <= "RUN ";
        else
            run_text <= "STOP";
        end if;
    end process;

    -- =========================================================================
    -- Pixel-by-pixel text render (clocked)
    -- =========================================================================
    process(clk)
        variable text_x, text_y         : integer;
        variable char_column, char_row  : integer;
        variable char_index, bit_index  : integer;
    begin
        if rising_edge(clk) then
            text_bit_on  <= '0';
            pixel_in_text <= '0';

            current_x <= to_integer(unsigned(pixel_x));
            current_y <= to_integer(unsigned(pixel_y));

            for i in 0 to 3 loop
                text_x := text_positions(i).x;
                text_y := text_positions(i).y;

                if current_x >= text_x and
                   current_x <  text_x + (text_positions(i).length * CHAR_WIDTH) and
                   current_y >= text_y and
                   current_y <  text_y + CHAR_HEIGHT then

                    pixel_in_text <= '1';
                    char_column := (current_x - text_x) / CHAR_WIDTH;
                    char_row    := current_y - text_y;

                    if char_column < text_positions(i).length then
                        char_index := char_column + 1;  -- 1-indexed

                        -- Overlay dynamic values
                        if i = 0 and char_index >= 11 and char_index <= 15 then
                            current_char <= volts_text(char_index - 10);
                        elsif i = 1 and char_index >= 11 and char_index <= 15 then
                            current_char <= time_text(char_index - 10);
                        elsif i = 2 and char_index >= 7 and char_index <= 11 then
                            current_char <= trig_text(char_index - 6);
                        elsif i = 3 and char_index >= 9 and char_index <= 12 then
                            current_char <= run_text(char_index - 8);
                        else
                            current_char <= text_positions(i).text(char_index);
                        end if;

                        char_addr <= std_logic_vector(
                                         to_unsigned(character'pos(current_char), 7));
                        rom_addr  <= char_row;
                        rom_data  <= CHAR_ROM(to_integer(unsigned(char_addr)), rom_addr);

                        bit_index := 7 - ((current_x - text_x) mod CHAR_WIDTH);
                        if bit_index >= 0 and bit_index < 8 then
                            text_bit_on <= rom_data(bit_index);
                        end if;
                    end if;
                end if;
            end loop;
        end if;
    end process;

    draw_text <= text_bit_on and pixel_in_text and text_enable;
    text_rgb  <= X"FFF" when text_bit_on = '1' else X"000";

end Behavioral;
```

## vga_controller.vhd

```vhdl

-- =============================================================================
-- vga_controller.vhd  (Nexys4 DDR version)
-- Standard 640x480 @ 60 Hz VGA controller.
-- The Nexys4 DDR system clock is 100 MHz.  We divide by 4 to get ~25 MHz
-- pixel clock, which gives exact 640x480/60 Hz timing.
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga_controller is
    Port (
        clk          : in  STD_LOGIC;       -- 100 MHz system clock
        reset        : in  STD_LOGIC;

        vga_hsync    : out STD_LOGIC;
        vga_vsync    : out STD_LOGIC;
        vga_red      : out STD_LOGIC_VECTOR(3 downto 0);
        vga_green    : out STD_LOGIC_VECTOR(3 downto 0);
        vga_blue     : out STD_LOGIC_VECTOR(3 downto 0);

        pixel_x      : out STD_LOGIC_VECTOR(9 downto 0);
        pixel_y      : out STD_LOGIC_VECTOR(9 downto 0);
        pixel_active : out STD_LOGIC
    );
end vga_controller;

architecture Behavioral of vga_controller is

    -- Pixel clock divider: 100 MHz / 4 = 25 MHz
    signal clk_count : unsigned(1 downto 0) := (others => '0');
    signal pixel_clk : STD_LOGIC := '0';

    -- 640x480 @ 60 Hz timing constants
    constant H_DISPLAY    : integer := 640;
    constant H_FRONT_PORCH: integer := 16;
    constant H_SYNC_PULSE : integer := 96;
    constant H_BACK_PORCH : integer := 48;
    constant H_TOTAL      : integer := H_DISPLAY + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH; -- 800

    constant V_DISPLAY    : integer := 480;
    constant V_FRONT_PORCH: integer := 10;
    constant V_SYNC_PULSE : integer := 2;
    constant V_BACK_PORCH : integer := 33;
    constant V_TOTAL      : integer := V_DISPLAY + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH; -- 525

    signal h_count : unsigned(9 downto 0) := (others => '0');
    signal v_count : unsigned(9 downto 0) := (others => '0');

    signal h_sync, v_sync : STD_LOGIC := '1';
    signal video_active   : STD_LOGIC := '0';

    signal pixel_x_reg : unsigned(9 downto 0) := (others => '0');
    signal pixel_y_reg : unsigned(9 downto 0) := (others => '0');

begin

    -- -------------------------------------------------------------------------
    -- Pixel clock: toggle every 2 system clocks => 25 MHz
    -- -------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                clk_count <= (others => '0');
                pixel_clk <= '0';
            else
                if clk_count = 3 then
                    clk_count <= (others => '0');
                    pixel_clk <= '1';
                else
                    clk_count <= clk_count + 1;
                    pixel_clk <= '0';
                end if;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    -- Horizontal / Vertical counters
    -- -------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                h_count <= (others => '0');
                v_count <= (others => '0');
            elsif pixel_clk = '1' then
                if h_count = H_TOTAL - 1 then
                    h_count <= (others => '0');
                    if v_count = V_TOTAL - 1 then
                        v_count <= (others => '0');
                    else
                        v_count <= v_count + 1;
                    end if;
                else
                    h_count <= h_count + 1;
                end if;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    -- Sync signals (active-low)
    -- -------------------------------------------------------------------------
    h_sync <= '0' when (h_count >= H_DISPLAY + H_FRONT_PORCH) and
                       (h_count <  H_DISPLAY + H_FRONT_PORCH + H_SYNC_PULSE) else '1';

    v_sync <= '0' when (v_count >= V_DISPLAY + V_FRONT_PORCH) and
                       (v_count <  V_DISPLAY + V_FRONT_PORCH + V_SYNC_PULSE) else '1';

    video_active <= '1' when (h_count < H_DISPLAY) and (v_count < V_DISPLAY) else '0';

    -- -------------------------------------------------------------------------
    -- Pixel coordinate registers
    -- -------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if pixel_clk = '1' then
                if h_count < H_DISPLAY then
                    pixel_x_reg <= h_count;
                end if;
                if v_count < V_DISPLAY then
                    pixel_y_reg <= v_count;
                end if;
            end if;
        end if;
    end process;

    vga_hsync    <= h_sync;
    vga_vsync    <= v_sync;
    pixel_active <= video_active;
    pixel_x      <= std_logic_vector(pixel_x_reg);
    pixel_y      <= std_logic_vector(pixel_y_reg);

    -- Colour outputs are driven by oscilloscope_top via the pixel_active signal.
    -- When blanking, force black.
    vga_red   <= (others => '0');
    vga_green <= (others => '0');
    vga_blue  <= (others => '0');

end Behavioral;
```

## xadc_module.vhd

```vhdl

-- =============================================================================
-- xadc_module.vhd  (Nexys4 DDR version)
-- Wraps the Xilinx XADC Wizard IP and provides a simple valid-strobe interface.
--
-- Nexys4 DDR XADC analog input:
--   The board exposes XADC on the JXADC Pmod connector.
--   Pin JA1 / JA7 = VP/VN dedicated input
--   Auxiliary channels available:
--     VAUX0  -> JA2/JA8   (JXADC header pins 2/8)
--     VAUX8  -> JA3/JA9
--     VAUX1  -> JA4/JA10
--   This design uses VAUX0 (channel 16 decimal = 0x10, DRP addr 0x11).
--
--   Change daddr to 0x10 for VP/VN dedicated, or adjust for other aux channels.
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity xadc_module is
    Port (
        clk       : in  STD_LOGIC;                      -- 100 MHz
        reset     : in  STD_LOGIC;

        -- Analog inputs (JXADC Pmod Pin 1/7, channel VAUX3)
        vauxp3    : in  STD_LOGIC;
        vauxn3    : in  STD_LOGIC;

        -- Dedicated VP/VN input
        vp_in     : in  STD_LOGIC := '0';
        vn_in     : in  STD_LOGIC := '0';

        adc_data  : out STD_LOGIC_VECTOR(11 downto 0);  -- 12-bit sample
        adc_valid : out STD_LOGIC                       -- 1-cycle strobe
    );
end xadc_module;

architecture Behavioral of xadc_module is

    component xadc_wiz_0 is
        port (
            daddr_in    : in  STD_LOGIC_VECTOR(6 downto 0);
            den_in      : in  STD_LOGIC;
            di_in       : in  STD_LOGIC_VECTOR(15 downto 0);
            dwe_in      : in  STD_LOGIC;
            do_out      : out STD_LOGIC_VECTOR(15 downto 0);
            drdy_out    : out STD_LOGIC;
            dclk_in     : in  STD_LOGIC;
            reset_in    : in  STD_LOGIC;
            vauxp3      : in  STD_LOGIC;
            vauxn3      : in  STD_LOGIC;
            busy_out    : out STD_LOGIC;
            channel_out : out STD_LOGIC_VECTOR(4 downto 0);
            eoc_out     : out STD_LOGIC;
            eos_out     : out STD_LOGIC;
            alarm_out   : out STD_LOGIC;
            vp_in       : in  STD_LOGIC;
            vn_in       : in  STD_LOGIC
        );
    end component;

    signal xadc_daddr   : STD_LOGIC_VECTOR(6 downto 0);
    signal xadc_den     : STD_LOGIC := '0';
    signal xadc_di      : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal xadc_dwe     : STD_LOGIC := '0';
    signal xadc_do      : STD_LOGIC_VECTOR(15 downto 0);
    signal xadc_drdy    : STD_LOGIC;
    signal xadc_busy    : STD_LOGIC;
    signal xadc_channel : STD_LOGIC_VECTOR(4 downto 0);
    signal xadc_eoc     : STD_LOGIC;
    signal xadc_eos     : STD_LOGIC;
    signal xadc_alarm   : STD_LOGIC;

    signal sample_counter : unsigned(19 downto 0) := (others => '0');
    signal sample_enable  : STD_LOGIC := '0';

    signal adc_data_reg  : STD_LOGIC_VECTOR(11 downto 0) := (others => '0');
    signal adc_valid_reg : STD_LOGIC := '0';

begin

    -- DRP address: VAUX3 result register = 0x13
    xadc_daddr <= "0010011"; 

    xadc_inst : xadc_wiz_0
        port map (
            daddr_in    => xadc_daddr,
            den_in      => xadc_den,
            di_in       => xadc_di,
            dwe_in      => xadc_dwe,
            do_out      => xadc_do,
            drdy_out    => xadc_drdy,
            dclk_in     => clk,
            reset_in    => reset,
            vauxp3      => vauxp3,
            vauxn3      => vauxn3,
            busy_out    => xadc_busy,
            channel_out => xadc_channel,
            eoc_out     => xadc_eoc,
            eos_out     => xadc_eos,
            alarm_out   => xadc_alarm,
            vp_in       => vp_in,
            vn_in       => vn_in
        );

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                sample_counter <= (others => '0');
                sample_enable  <= '0';
            else
                if sample_counter >= 2499 then
                    sample_counter <= (others => '0');
                    sample_enable  <= '1';
                else
                    sample_counter <= sample_counter + 1;
                    sample_enable  <= '0';
                end if;
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                xadc_den      <= '0';
                adc_data_reg  <= (others => '0');
                adc_valid_reg <= '0';
            else
                xadc_den      <= '0';
                adc_valid_reg <= '0';

                if sample_enable = '1' then
                    xadc_den <= '1';
                end if;

                if xadc_drdy = '1' then
                    adc_data_reg  <= xadc_do(15 downto 4); 
                    adc_valid_reg <= '1';
                end if;
            end if;
        end if;
    end process;

    adc_data  <= adc_data_reg;
    adc_valid <= adc_valid_reg;

end Behavioral;

```

## tb_oscilloscope.vhd

```vhdl

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_oscilloscope is
-- Testbench has no ports
end tb_oscilloscope;

architecture Behavioral of tb_oscilloscope is

    -- Component Declaration for the Unit Under Test (UUT)
    component oscilloscope_top
    Port ( 
        clk          : in  STD_LOGIC;
        reset        : in  STD_LOGIC;
        
        -- XADC Inputs (Differential)
        vauxp3       : in  STD_LOGIC;
        vauxn3       : in  STD_LOGIC;
        
        -- UI Inputs
        btnU         : in  STD_LOGIC;
        btnD         : in  STD_LOGIC;
        btnL         : in  STD_LOGIC;
        btnR         : in  STD_LOGIC;
        btnC         : in  STD_LOGIC;
        sw           : in  STD_LOGIC_VECTOR(15 downto 0);
        
        -- VGA Outputs
        vga_hsync    : out STD_LOGIC;
        vga_vsync    : out STD_LOGIC;
        vga_red      : out STD_LOGIC_VECTOR(3 downto 0);
        vga_green    : out STD_LOGIC_VECTOR(3 downto 0);
        vga_blue     : out STD_LOGIC_VECTOR(3 downto 0);
        
        -- 7-Segment Display Outputs
        seg          : out STD_LOGIC_VECTOR(6 downto 0);
        dp_out       : out STD_LOGIC;
        an           : out STD_LOGIC_VECTOR(7 downto 0);
        
        -- LED Outputs
        led          : out STD_LOGIC_VECTOR(15 downto 0)
    );
    end component;

    -- Inputs
    signal clk : std_logic := '0';
    signal reset : std_logic := '0'; -- Active low reset
    signal vauxp3 : std_logic := '0';
    signal vauxn3 : std_logic := '0';
    signal btnU : std_logic := '0';
    signal btnD : std_logic := '0';
    signal btnL : std_logic := '0';
    signal btnR : std_logic := '0';
    signal btnC : std_logic := '0';
    signal sw : std_logic_vector(15 downto 0) := (others => '0');

    -- Outputs
    signal vga_hsync : std_logic;
    signal vga_vsync : std_logic;
    signal vga_red : std_logic_vector(3 downto 0);
    signal vga_green : std_logic_vector(3 downto 0);
    signal vga_blue : std_logic_vector(3 downto 0);
    signal seg : std_logic_vector(6 downto 0);
    signal dp_out : std_logic;
    signal an : std_logic_vector(7 downto 0);
    signal led : std_logic_vector(15 downto 0);

    -- Clock period definitions
    constant clk_period : time := 10 ns; -- 100MHz

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: oscilloscope_top PORT MAP (
          clk => clk,
          reset => reset,
          vauxp3 => vauxp3,
          vauxn3 => vauxn3,
          btnU => btnU,
          btnD => btnD,
          btnL => btnL,
          btnR => btnR,
          btnC => btnC,
          sw => sw,
          vga_hsync => vga_hsync,
          vga_vsync => vga_vsync,
          vga_red => vga_red,
          vga_green => vga_green,
          vga_blue => vga_blue,
          seg => seg,
          dp_out => dp_out,
          an => an,
          led => led
        );

    -- Clock process definitions
    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- Stimulus process
    stim_proc: process
    begin		
        -- hold reset state for 100 ns.
        reset <= '0'; -- Press reset button (active low)
        wait for 100 ns;	
        reset <= '1'; -- Release reset button
        
        -- Enable Test Wave mode (SW15 = ON)
        -- Keep Square Wave (SW11 = OFF)
        sw(15) <= '1'; 

        -- Wait for 5 ms to see many Square Wave cycles
        wait for 5 ms;

        -- Test sawtooth wave (SW11 = ON)
        sw(11) <= '1';
        
        -- Wait for 5 ms to see many Sawtooth cycles
        wait for 5 ms;
        
        -- Stop simulation smoothly
        wait;
    end process;

end Behavioral;
```

## tb_oscilloscope_sawtooth.vhd

```vhdl

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_oscilloscope_sawtooth is
end tb_oscilloscope_sawtooth;

architecture Behavioral of tb_oscilloscope_sawtooth is
    component oscilloscope_top
    Port ( clk : in STD_LOGIC; reset : in STD_LOGIC; vauxp3 : in STD_LOGIC; vauxn3 : in STD_LOGIC; btnU : in STD_LOGIC; btnD : in STD_LOGIC; btnL : in STD_LOGIC; btnR : in STD_LOGIC; btnC : in STD_LOGIC; sw : in STD_LOGIC_VECTOR(15 downto 0); vga_hsync : out STD_LOGIC; vga_vsync : out STD_LOGIC; vga_red : out STD_LOGIC_VECTOR(3 downto 0); vga_green : out STD_LOGIC_VECTOR(3 downto 0); vga_blue : out STD_LOGIC_VECTOR(3 downto 0); seg : out STD_LOGIC_VECTOR(6 downto 0); dp_out : out STD_LOGIC; an : out STD_LOGIC_VECTOR(7 downto 0); led : out STD_LOGIC_VECTOR(15 downto 0));
    end component;

    signal clk : std_logic := '0';
    signal reset : std_logic := '0';
    signal vauxp3, vauxn3, btnU, btnD, btnL, btnR, btnC : std_logic := '0';
    signal sw : std_logic_vector(15 downto 0) := (others => '0');
    signal vga_hsync, vga_vsync, dp_out : std_logic;
    signal vga_red, vga_green, vga_blue : std_logic_vector(3 downto 0);
    signal seg : std_logic_vector(6 downto 0);
    signal an : std_logic_vector(7 downto 0);
    signal led : std_logic_vector(15 downto 0);

    constant clk_period : time := 10 ns;
begin
    uut: oscilloscope_top PORT MAP (clk => clk, reset => reset, vauxp3 => vauxp3, vauxn3 => vauxn3, btnU => btnU, btnD => btnD, btnL => btnL, btnR => btnR, btnC => btnC, sw => sw, vga_hsync => vga_hsync, vga_vsync => vga_vsync, vga_red => vga_red, vga_green => vga_green, vga_blue => vga_blue, seg => seg, dp_out => dp_out, an => an, led => led);

    clk_process :process begin
        clk <= '0'; wait for clk_period/2;
        clk <= '1'; wait for clk_period/2;
    end process;

    stim_proc: process begin		
        reset <= '0'; wait for 100 ns; reset <= '1'; 
        
        -- SAWTOOTH WAVE MODE
        sw(15) <= '1'; -- Test Wave ON
        sw(11) <= '1'; -- Sawtooth Wave mode
        
        wait;
    end process;
end Behavioral;
```

## tb_oscilloscope_sine.vhd

```vhdl

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_oscilloscope_sine is
end tb_oscilloscope_sine;

architecture Behavioral of tb_oscilloscope_sine is
    component oscilloscope_top
    Port ( clk : in STD_LOGIC; reset : in STD_LOGIC; vauxp3 : in STD_LOGIC; vauxn3 : in STD_LOGIC; btnU : in STD_LOGIC; btnD : in STD_LOGIC; btnL : in STD_LOGIC; btnR : in STD_LOGIC; btnC : in STD_LOGIC; sw : in STD_LOGIC_VECTOR(15 downto 0); vga_hsync : out STD_LOGIC; vga_vsync : out STD_LOGIC; vga_red : out STD_LOGIC_VECTOR(3 downto 0); vga_green : out STD_LOGIC_VECTOR(3 downto 0); vga_blue : out STD_LOGIC_VECTOR(3 downto 0); seg : out STD_LOGIC_VECTOR(6 downto 0); dp_out : out STD_LOGIC; an : out STD_LOGIC_VECTOR(7 downto 0); led : out STD_LOGIC_VECTOR(15 downto 0));
    end component;

    signal clk : std_logic := '0';
    signal reset : std_logic := '0';
    signal vauxp3, vauxn3, btnU, btnD, btnL, btnR, btnC : std_logic := '0';
    signal sw : std_logic_vector(15 downto 0) := (others => '0');
    signal vga_hsync, vga_vsync, dp_out : std_logic;
    signal vga_red, vga_green, vga_blue : std_logic_vector(3 downto 0);
    signal seg : std_logic_vector(6 downto 0);
    signal an : std_logic_vector(7 downto 0);
    signal led : std_logic_vector(15 downto 0);

    constant clk_period : time := 10 ns;
begin
    uut: oscilloscope_top PORT MAP (clk => clk, reset => reset, vauxp3 => vauxp3, vauxn3 => vauxn3, btnU => btnU, btnD => btnD, btnL => btnL, btnR => btnR, btnC => btnC, sw => sw, vga_hsync => vga_hsync, vga_vsync => vga_vsync, vga_red => vga_red, vga_green => vga_green, vga_blue => vga_blue, seg => seg, dp_out => dp_out, an => an, led => led);

    clk_process :process begin
        clk <= '0'; wait for clk_period/2;
        clk <= '1'; wait for clk_period/2;
    end process;

    stim_proc: process begin		
        reset <= '0'; wait for 100 ns; reset <= '1'; 
        
        -- SINE WAVE MODE
        sw(15) <= '1'; -- Test Wave ON
        sw(11) <= '1'; -- Sine Wave mode
        sw(10) <= '1';
        
        wait;
    end process;
end Behavioral;
```

## tb_oscilloscope_square.vhd

```vhdl

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_oscilloscope_square is
end tb_oscilloscope_square;

architecture Behavioral of tb_oscilloscope_square is
    component oscilloscope_top
    Port ( clk : in STD_LOGIC; reset : in STD_LOGIC; vauxp3 : in STD_LOGIC; vauxn3 : in STD_LOGIC; btnU : in STD_LOGIC; btnD : in STD_LOGIC; btnL : in STD_LOGIC; btnR : in STD_LOGIC; btnC : in STD_LOGIC; sw : in STD_LOGIC_VECTOR(15 downto 0); vga_hsync : out STD_LOGIC; vga_vsync : out STD_LOGIC; vga_red : out STD_LOGIC_VECTOR(3 downto 0); vga_green : out STD_LOGIC_VECTOR(3 downto 0); vga_blue : out STD_LOGIC_VECTOR(3 downto 0); seg : out STD_LOGIC_VECTOR(6 downto 0); dp_out : out STD_LOGIC; an : out STD_LOGIC_VECTOR(7 downto 0); led : out STD_LOGIC_VECTOR(15 downto 0));
    end component;

    signal clk : std_logic := '0';
    signal reset : std_logic := '0';
    signal vauxp3, vauxn3, btnU, btnD, btnL, btnR, btnC : std_logic := '0';
    signal sw : std_logic_vector(15 downto 0) := (others => '0');
    signal vga_hsync, vga_vsync, dp_out : std_logic;
    signal vga_red, vga_green, vga_blue : std_logic_vector(3 downto 0);
    signal seg : std_logic_vector(6 downto 0);
    signal an : std_logic_vector(7 downto 0);
    signal led : std_logic_vector(15 downto 0);

    constant clk_period : time := 10 ns;
begin
    uut: oscilloscope_top PORT MAP (clk => clk, reset => reset, vauxp3 => vauxp3, vauxn3 => vauxn3, btnU => btnU, btnD => btnD, btnL => btnL, btnR => btnR, btnC => btnC, sw => sw, vga_hsync => vga_hsync, vga_vsync => vga_vsync, vga_red => vga_red, vga_green => vga_green, vga_blue => vga_blue, seg => seg, dp_out => dp_out, an => an, led => led);

    clk_process :process begin
        clk <= '0'; wait for clk_period/2;
        clk <= '1'; wait for clk_period/2;
    end process;

    stim_proc: process begin		
        reset <= '0'; wait for 100 ns; reset <= '1'; 
        
        -- SQUARE WAVE MODE
        sw(15) <= '1'; -- Test Wave ON
        sw(11) <= '0'; -- Square Wave mode
        
        wait;
    end process;
end Behavioral;
```

## tb_oscilloscope_triangle.vhd

```vhdl

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_oscilloscope_triangle is
end tb_oscilloscope_triangle;

architecture Behavioral of tb_oscilloscope_triangle is
    component oscilloscope_top
    Port ( clk : in STD_LOGIC; reset : in STD_LOGIC; vauxp3 : in STD_LOGIC; vauxn3 : in STD_LOGIC; btnU : in STD_LOGIC; btnD : in STD_LOGIC; btnL : in STD_LOGIC; btnR : in STD_LOGIC; btnC : in STD_LOGIC; sw : in STD_LOGIC_VECTOR(15 downto 0); vga_hsync : out STD_LOGIC; vga_vsync : out STD_LOGIC; vga_red : out STD_LOGIC_VECTOR(3 downto 0); vga_green : out STD_LOGIC_VECTOR(3 downto 0); vga_blue : out STD_LOGIC_VECTOR(3 downto 0); seg : out STD_LOGIC_VECTOR(6 downto 0); dp_out : out STD_LOGIC; an : out STD_LOGIC_VECTOR(7 downto 0); led : out STD_LOGIC_VECTOR(15 downto 0));
    end component;

    signal clk : std_logic := '0';
    signal reset : std_logic := '0';
    signal vauxp3, vauxn3, btnU, btnD, btnL, btnR, btnC : std_logic := '0';
    signal sw : std_logic_vector(15 downto 0) := (others => '0');
    signal vga_hsync, vga_vsync, dp_out : std_logic;
    signal vga_red, vga_green, vga_blue : std_logic_vector(3 downto 0);
    signal seg : std_logic_vector(6 downto 0);
    signal an : std_logic_vector(7 downto 0);
    signal led : std_logic_vector(15 downto 0);

    constant clk_period : time := 10 ns;
begin
    uut: oscilloscope_top PORT MAP (clk => clk, reset => reset, vauxp3 => vauxp3, vauxn3 => vauxn3, btnU => btnU, btnD => btnD, btnL => btnL, btnR => btnR, btnC => btnC, sw => sw, vga_hsync => vga_hsync, vga_vsync => vga_vsync, vga_red => vga_red, vga_green => vga_green, vga_blue => vga_blue, seg => seg, dp_out => dp_out, an => an, led => led);

    clk_process :process begin
        clk <= '0'; wait for clk_period/2;
        clk <= '1'; wait for clk_period/2;
    end process;

    stim_proc: process begin		
        reset <= '0'; wait for 100 ns; reset <= '1'; 
        
        -- TRIANGLE WAVE MODE
        sw(15) <= '1'; -- Test Wave ON
        sw(11) <= '1'; -- Triangle Wave mode
        sw(10) <= '0';
        
        wait;
    end process;
end Behavioral;
```

