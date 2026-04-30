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
