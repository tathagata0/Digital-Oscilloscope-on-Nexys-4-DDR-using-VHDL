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
