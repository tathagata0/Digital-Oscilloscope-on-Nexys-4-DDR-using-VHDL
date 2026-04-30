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

    -- Counter for multiplexing: 100 MHz / 2^17 ≈ 763 Hz full cycle
    -- 3 MSBs select 1-of-8 digits → each digit refreshed at ~95 Hz
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

    digit_sel <= counter(19 downto 17);   -- top 3 bits → 0-7

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
