library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
library STD;
use STD.TEXTIO.ALL;

entity rom_h1_w is
    Port (
        clka  : in  STD_LOGIC;
        ena   : in  STD_LOGIC;
        addra : in  STD_LOGIC_VECTOR(17 downto 0);
        douta : out STD_LOGIC_VECTOR(7 downto 0)
    );
end rom_h1_w;

architecture Behavioral of rom_h1_w is
    subtype word_type is STD_LOGIC_VECTOR(7 downto 0);
    type bank_type is array (0 to 2351) of word_type;
    type rom_type is array (0 to 63) of bank_type;
    impure function init_bank(neuron : integer) return bank_type is
        variable file_name : string(1 to 64);
        file rom_file : text;
        variable rom_line : line;
        variable rom_data : word_type;
        variable rom : bank_type;
    begin
        case neuron is
        when 0 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_00.mem";
        when 1 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_01.mem";
        when 2 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_02.mem";
        when 3 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_03.mem";
        when 4 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_04.mem";
        when 5 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_05.mem";
        when 6 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_06.mem";
        when 7 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_07.mem";
        when 8 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_08.mem";
        when 9 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_09.mem";
        when 10 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_10.mem";
        when 11 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_11.mem";
        when 12 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_12.mem";
        when 13 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_13.mem";
        when 14 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_14.mem";
        when 15 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_15.mem";
        when 16 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_16.mem";
        when 17 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_17.mem";
        when 18 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_18.mem";
        when 19 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_19.mem";
        when 20 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_20.mem";
        when 21 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_21.mem";
        when 22 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_22.mem";
        when 23 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_23.mem";
        when 24 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_24.mem";
        when 25 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_25.mem";
        when 26 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_26.mem";
        when 27 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_27.mem";
        when 28 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_28.mem";
        when 29 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_29.mem";
        when 30 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_30.mem";
        when 31 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_31.mem";
        when 32 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_32.mem";
        when 33 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_33.mem";
        when 34 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_34.mem";
        when 35 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_35.mem";
        when 36 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_36.mem";
        when 37 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_37.mem";
        when 38 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_38.mem";
        when 39 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_39.mem";
        when 40 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_40.mem";
        when 41 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_41.mem";
        when 42 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_42.mem";
        when 43 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_43.mem";
        when 44 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_44.mem";
        when 45 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_45.mem";
        when 46 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_46.mem";
        when 47 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_47.mem";
        when 48 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_48.mem";
        when 49 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_49.mem";
        when 50 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_50.mem";
        when 51 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_51.mem";
        when 52 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_52.mem";
        when 53 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_53.mem";
        when 54 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_54.mem";
        when 55 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_55.mem";
        when 56 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_56.mem";
        when 57 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_57.mem";
        when 58 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_58.mem";
        when 59 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_59.mem";
        when 60 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_60.mem";
        when 61 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_61.mem";
        when 62 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_62.mem";
        when 63 => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_63.mem";
        when others => file_name := "C:/Users/belal/Downloads/project_1/trained_model/rom_h1_w_00.mem";
        end case;
        file_open(rom_file, file_name, read_mode);
        for i in bank_type'range loop
            readline(rom_file, rom_line);
            hread(rom_line, rom_data);
            rom(i) := rom_data;
        end loop;
        file_close(rom_file);
        return rom;
    end function;
    impure function init_rom return rom_type is
        variable rom : rom_type;
    begin
        for n in rom_type'range loop
            rom(n) := init_bank(n);
        end loop;
        return rom;
    end function;
    constant ROM : rom_type := init_rom;
begin
    process(clka)
        variable flat_addr : integer range 0 to 150527;
        variable neuron_addr : integer range 0 to 63;
        variable input_addr  : integer range 0 to 2351;
    begin
        if rising_edge(clka) then
            if ena = '1' then
                flat_addr := to_integer(unsigned(addra));
                neuron_addr := flat_addr / 2352;
                input_addr := flat_addr mod 2352;
                douta <= ROM(neuron_addr)(input_addr);
            end if;
        end if;
    end process;
end Behavioral;
