library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;  -- This library is required to do math in VHDL!

entity mac_unit is
    Port ( 
        clk    : in  STD_LOGIC;               -- The system clock
        reset  : in  STD_LOGIC;               -- Signal to clear the running total
        enable : in  STD_LOGIC;               -- Signal to tell the unit to calculate
        pixel  : in  signed (7 downto 0);     -- 8-bit input from the image
        weight : in  signed (7 downto 0);     -- 8-bit input from the AI model
        accum  : out signed (31 downto 0)     -- 32-bit output total
    );
end mac_unit;

architecture Behavioral of mac_unit is
    -- We need a physical register (memory) to hold the running total
    signal accum_reg : signed(31 downto 0) := (others => '0');

begin

    -- This process runs every single time the clock ticks
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                -- Clear the register back to zero
                accum_reg <= (others => '0');
            elsif enable = '1' then
                -- Multiply the 8-bit pixel by the 8-bit weight (which creates a 16-bit number)
                -- Then add it to the running total
                accum_reg <= accum_reg + resize(pixel * weight, 32);
            end if;
        end if;
    end process;

    -- Connect our internal register to the output wire
    accum <= accum_reg;

end Behavioral;
