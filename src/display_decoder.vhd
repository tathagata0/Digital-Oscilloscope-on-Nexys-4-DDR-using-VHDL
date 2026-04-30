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
                    -- "000" = trigger level (raw ADC counts → show as decimal)
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
                            when 0  => val := to_unsigned(1,   14); uc := "011"; -- 1 µs
                            when 1  => val := to_unsigned(2,   14); uc := "011"; -- 2 µs
                            when 2  => val := to_unsigned(5,   14); uc := "011"; -- 5 µs
                            when 3  => val := to_unsigned(10,  14); uc := "011"; -- 10 µs
                            when 4  => val := to_unsigned(20,  14); uc := "011"; -- 20 µs
                            when 5  => val := to_unsigned(50,  14); uc := "011"; -- 50 µs
                            when 6  => val := to_unsigned(100, 14); uc := "011"; -- 100 µs
                            when 7  => val := to_unsigned(200, 14); uc := "011"; -- 200 µs
                            when 8  => val := to_unsigned(500, 14); uc := "011"; -- 500 µs
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
            when "001" => digit5 <= "1010"; -- 'A' placeholder → wire-decode below as 'V'
            when "010" => digit5 <= "1011"; -- 'b' → 'm'
            when "011" => digit5 <= "1100"; -- 'C' → 'u'
            when "100" => digit5 <= "1101"; -- 'd' → 'm' (ms)
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
