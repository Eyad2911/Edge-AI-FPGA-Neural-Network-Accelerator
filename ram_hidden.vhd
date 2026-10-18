library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ram_hidden is
    generic (
        ADDR_WIDTH : integer := 6;  -- Example: 6 bits for 64 neurons in the hidden layer
        DATA_WIDTH : integer := 8   -- 8-bit activations
    );
    Port ( 
        clk   : in STD_LOGIC;
        we    : in STD_LOGIC;
        addr  : in STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
        din   : in STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
        dout  : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0)
    );
end ram_hidden;

architecture Behavioral of ram_hidden is
    type ram_type is array (0 to (2**ADDR_WIDTH)-1) of STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    signal RAM : ram_type := (others => (others => '0'));
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                RAM(to_integer(unsigned(addr))) <= din;
            end if;
            -- Read is synchronous
            dout <= RAM(to_integer(unsigned(addr)));
        end if;
    end process;
end Behavioral;