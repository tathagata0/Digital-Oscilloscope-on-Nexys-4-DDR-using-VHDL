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
