library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
library STD;
use STD.TEXTIO.ALL;

entity rom_h2_w is
    generic (
        ADDR_WIDTH : integer := 11;
        DATA_WIDTH : integer := 8
    );
    Port (
        clk   : in STD_LOGIC;
        ena   : in STD_LOGIC;
        addra : in STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
        douta : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0)
    );
end rom_h2_w;

architecture Behavioral of rom_h2_w is
    type rom_type is array (0 to 2047) of STD_LOGIC_VECTOR(7 downto 0);
    impure function init_rom return rom_type is
        file rom_file : text open read_mode is "C:/Users/belal/Downloads/project_1/trained_model/rom_h2_w.mem";
        variable rom_line : line;
        variable rom_data : STD_LOGIC_VECTOR(7 downto 0);
        variable rom : rom_type;
    begin
        for i in rom_type'range loop
            readline(rom_file, rom_line);
            hread(rom_line, rom_data);
            rom(i) := rom_data;
        end loop;
        return rom;
    end function;
    constant ROM : rom_type := init_rom;
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if ena = '1' then
                douta <= ROM(to_integer(unsigned(addra)));
            end if;
        end if;
    end process;
end Behavioral;
