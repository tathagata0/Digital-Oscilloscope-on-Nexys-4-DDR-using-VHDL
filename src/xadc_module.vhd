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

