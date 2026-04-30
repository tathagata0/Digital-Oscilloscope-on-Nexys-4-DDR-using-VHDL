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
