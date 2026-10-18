library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ram_input is
    Port (
        clka  : in  STD_LOGIC;
        ena   : in  STD_LOGIC;
        wea   : in  STD_LOGIC_VECTOR(0 downto 0);
        addra : in  STD_LOGIC_VECTOR(11 downto 0);
        dina  : in  STD_LOGIC_VECTOR(7 downto 0);
        douta : out STD_LOGIC_VECTOR(7 downto 0)
    );
end ram_input;

architecture Behavioral of ram_input is
    -- Needs to hold at least 2352 pixels. 12 address bits give us 4096 slots.
    type ram_type is array (0 to 4095) of STD_LOGIC_VECTOR(7 downto 0);
    signal RAM : ram_type := (others => (others => '0'));
begin
    process(clka)
    begin
        if rising_edge(clka) then
            if ena = '1' then
                if wea(0) = '1' then
                    RAM(to_integer(unsigned(addra))) <= dina;
                end if;
                douta <= RAM(to_integer(unsigned(addra)));
            end if;
        end if;
    end process;
end Behavioral;