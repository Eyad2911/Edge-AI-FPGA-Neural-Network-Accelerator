library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_mac_unit is
-- A testbench has no ports because it is the top-level test environment!
end tb_mac_unit;

architecture Behavioral of tb_mac_unit is
    -- 1. Bring in your MAC unit design
    component mac_unit
    Port (
        clk    : in  STD_LOGIC;
        reset  : in  STD_LOGIC;
        enable : in  STD_LOGIC;
        pixel  : in  signed (7 downto 0);
        weight : in  signed (7 downto 0);
        accum  : out signed (15 downto 0)
    );
    end component;

    -- 2. Create internal wires to connect to the MAC unit
    signal clk    : STD_LOGIC := '0';
    signal reset  : STD_LOGIC := '0';
    signal enable : STD_LOGIC := '0';
    signal pixel  : signed(7 downto 0) := (others => '0');
    signal weight : signed(7 downto 0) := (others => '0');
    signal accum  : signed(15 downto 0);

    constant clk_period : time := 10 ns;

begin
    -- 3. Wire up the fake signals to your actual MAC unit
    uut: mac_unit PORT MAP (
        clk => clk,
        reset => reset,
        enable => enable,
        pixel => pixel,
        weight => weight,
        accum => accum
    );

    -- 4. Generate a fake system clock ticking every 10 nanoseconds
    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- 5. THE TEST: Inject fake numbers to see if it calculates correctly
    stim_proc: process
    begin
        -- Step A: Press the Reset button to clear the memory
        reset <= '1';
        wait for 20 ns;
        reset <= '0';
        wait for 20 ns;

        -- Step B: First Calculation (5 * 10 = 50)
        enable <= '1';
        pixel <= to_signed(5, 8);
        weight <= to_signed(10, 8);
        wait for clk_period;
        -- Wait for one clock tick to let it calculate

        -- Step C: Second Calculation (-2 * 5 = -10)
        -- The Accumulator should now add this to the total: 50 + (-10) = 40!
        pixel <= to_signed(-2, 8);
        weight <= to_signed(5, 8);
        wait for clk_period;

        -- Step D: Stop calculating
        enable <= '0';
        wait;
    end process;

end Behavioral;