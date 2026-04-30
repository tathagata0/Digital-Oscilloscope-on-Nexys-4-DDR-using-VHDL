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
