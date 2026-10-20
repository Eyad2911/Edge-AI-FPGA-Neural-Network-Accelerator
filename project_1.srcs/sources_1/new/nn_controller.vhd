library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity nn_controller is
    Port ( 
        clk         : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        start       : in  STD_LOGIC;  
        result      : out STD_LOGIC;  
        done        : out STD_LOGIC;
        
        rx_data     : in  STD_LOGIC_VECTOR(7 downto 0);
        rx_we       : in  STD_LOGIC;
        rx_addr     : in  STD_LOGIC_VECTOR(11 downto 0)
    );
end nn_controller;

architecture Behavioral of nn_controller is

    type state_type is (IDLE, LAYER_1_CALC, LAYER_1_ACTIVATE, 
                        LAYER_2_CALC, LAYER_2_ACTIVATE, 
                        OUTPUT_CALC, OUTPUT_ACTIVATE, FINISHED);
    signal current_state : state_type := IDLE;

    -- Counters for loops
    signal input_counter  : integer range 0 to 4095 := 0; 
    signal weight_counter : integer range 0 to 150527 := 0;
    signal neuron_counter : integer range 0 to 63 := 0;
    signal calc_step      : integer range 0 to 4 := 0;
    
    -- THE FIX: A dedicated signal for tying memory enables HIGH
    signal const_high     : STD_LOGIC := '1';
    
    -- MAC Signals
    signal mac_enable : STD_LOGIC := '0';
    signal mac_reset  : STD_LOGIC := '0';
    signal mac_pixel  : signed(7 downto 0) := (others => '0');
    signal mac_weight : signed(7 downto 0) := (others => '0');
    signal mac_accum  : signed(31 downto 0);
    signal accum_with_bias : signed(31 downto 0);
    
    -- Memory Signals (Layer 1)
    signal ram_in_addr   : STD_LOGIC_VECTOR(11 downto 0) := (others => '0');
    signal ram_in_dout   : STD_LOGIC_VECTOR(7 downto 0);
    signal rom_h1_w_addr : STD_LOGIC_VECTOR(17 downto 0) := (others => '0');
    signal rom_h1_w_dout : STD_LOGIC_VECTOR(7 downto 0);
    signal rom_h1_b_addr : STD_LOGIC_VECTOR(5 downto 0)  := (others => '0');
    signal rom_h1_b_dout : STD_LOGIC_VECTOR(31 downto 0);

    -- Intermediate RAM 1 (Layer 1 Outputs -> Layer 2 Inputs)
    signal ram_h1_we     : STD_LOGIC := '0';
    signal ram_h1_addr   : STD_LOGIC_VECTOR(5 downto 0) := (others => '0');
    signal ram_h1_din    : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal ram_h1_dout   : STD_LOGIC_VECTOR(7 downto 0);
    
    -- Memory Signals (Layer 2)
    signal rom_h2_w_addr : STD_LOGIC_VECTOR(10 downto 0) := (others => '0'); 
    signal rom_h2_w_dout : STD_LOGIC_VECTOR(7 downto 0);
    signal rom_h2_b_addr : STD_LOGIC_VECTOR(4 downto 0)  := (others => '0');
    signal rom_h2_b_dout : STD_LOGIC_VECTOR(31 downto 0);

    -- Intermediate RAM 2 (Layer 2 Outputs -> Output Layer Inputs)
    signal ram_h2_we     : STD_LOGIC := '0';
    signal ram_h2_addr   : STD_LOGIC_VECTOR(4 downto 0) := (others => '0'); 
    signal ram_h2_din    : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal ram_h2_dout   : STD_LOGIC_VECTOR(7 downto 0);

    -- Memory Signals (Output Layer)
    signal rom_out_w_addr : STD_LOGIC_VECTOR(4 downto 0) := (others => '0');
    signal rom_out_w_dout : STD_LOGIC_VECTOR(7 downto 0);
    signal rom_out_b_addr : STD_LOGIC_VECTOR(0 downto 0) := "0";
    signal rom_out_b_dout : STD_LOGIC_VECTOR(31 downto 0);

    signal ram_addr_mux  : STD_LOGIC_VECTOR(11 downto 0);
    signal ram_we_wire   : STD_LOGIC_VECTOR(0 downto 0);

    -- COMPONENTS
    component mac_unit
        Port ( clk : in STD_LOGIC; reset : in STD_LOGIC; enable : in STD_LOGIC;
               pixel : in signed (7 downto 0); weight : in signed (7 downto 0); accum : out signed (31 downto 0));
    end component;

    component ram_input
        Port ( clka : in STD_LOGIC; ena : in STD_LOGIC; wea : in STD_LOGIC_VECTOR(0 downto 0);
               addra : in STD_LOGIC_VECTOR(11 downto 0); dina : in STD_LOGIC_VECTOR(7 downto 0); douta : out STD_LOGIC_VECTOR(7 downto 0));
    end component;

    component rom_h1_w
        Port ( clka : in STD_LOGIC; ena : in STD_LOGIC; addra : in STD_LOGIC_VECTOR(17 downto 0); douta : out STD_LOGIC_VECTOR(7 downto 0));
    end component;
    
    component rom_h1_b
        Port ( clk : in STD_LOGIC; ena : in STD_LOGIC; addra : in STD_LOGIC_VECTOR(5 downto 0); douta : out STD_LOGIC_VECTOR(31 downto 0));
    end component;

    component ram_hidden
        generic ( ADDR_WIDTH : integer := 6; DATA_WIDTH : integer := 8 );
        Port ( clk : in STD_LOGIC; we : in STD_LOGIC; addr : in STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0); din : in STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0); dout : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0));
    end component;

    component rom_h2_w
        generic ( ADDR_WIDTH : integer := 11; DATA_WIDTH : integer := 8 );
        Port ( clk : in STD_LOGIC; ena : in STD_LOGIC; addra : in STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0); douta : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0));
    end component;

    component rom_h2_b
        Port ( clk : in STD_LOGIC; ena : in STD_LOGIC; addra : in STD_LOGIC_VECTOR(4 downto 0); douta : out STD_LOGIC_VECTOR(31 downto 0));
    end component;

    component rom_out_w
        generic ( ADDR_WIDTH : integer := 5; DATA_WIDTH : integer := 8 );
        Port ( clk : in STD_LOGIC; ena : in STD_LOGIC; addra : in STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0); douta : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0));
    end component;

    component rom_out_b
        Port ( clk : in STD_LOGIC; ena : in STD_LOGIC; addra : in STD_LOGIC_VECTOR(0 downto 0); douta : out STD_LOGIC_VECTOR(31 downto 0));
    end component;

begin

    AI_MAC: mac_unit port map (clk => clk, reset => mac_reset, enable => mac_enable, pixel => mac_pixel, weight => mac_weight, accum => mac_accum);

    ram_addr_mux <= rx_addr when current_state = IDLE else ram_in_addr;
    ram_we_wire(0) <= rx_we when current_state = IDLE else '0';

    -- Updated Instantiations using the const_high signal
    MEM_INPUT: ram_input port map (clka => clk, ena => const_high, wea => ram_we_wire, addra => ram_addr_mux, dina => rx_data, douta => ram_in_dout);
    MEM_H1_W: rom_h1_w port map (clka => clk, ena => const_high, addra => rom_h1_w_addr, douta => rom_h1_w_dout);
    MEM_H1_B: rom_h1_b port map (clk => clk, ena => const_high, addra => rom_h1_b_addr, douta => rom_h1_b_dout);

    MEM_HIDDEN_1: ram_hidden generic map (ADDR_WIDTH => 6) port map (clk => clk, we => ram_h1_we, addr => ram_h1_addr, din => ram_h1_din, dout => ram_h1_dout);
    MEM_HIDDEN_2: ram_hidden generic map (ADDR_WIDTH => 5) port map (clk => clk, we => ram_h2_we, addr => ram_h2_addr, din => ram_h2_din, dout => ram_h2_dout);
    
    MEM_H2_W: rom_h2_w generic map (ADDR_WIDTH => 11) port map (clk => clk, ena => const_high, addra => rom_h2_w_addr, douta => rom_h2_w_dout);
    MEM_H2_B: rom_h2_b port map (clk => clk, ena => const_high, addra => rom_h2_b_addr, douta => rom_h2_b_dout);
    
    MEM_OUT_W: rom_out_w generic map (ADDR_WIDTH => 5) port map (clk => clk, ena => const_high, addra => rom_out_w_addr, douta => rom_out_w_dout);
    MEM_OUT_B: rom_out_b port map (clk => clk, ena => const_high, addra => rom_out_b_addr, douta => rom_out_b_dout);

    process(clk)
        variable act_tmp : signed(31 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                current_state <= IDLE;
                done <= '0';
                ram_h1_we <= '0';
                ram_h2_we <= '0';
            else
                case current_state is
                    
                    when IDLE =>
                        done <= '0';
                        ram_h1_we <= '0';
                        ram_h2_we <= '0';
                        if start = '1' then
                            input_counter <= 0;
                            weight_counter <= 0;
                            neuron_counter <= 0;
                            calc_step <= 0;
                            mac_reset <= '1'; 
                            current_state <= LAYER_1_CALC;
                        end if;

                    -- ==========================
                    -- LAYER 1 (2352 -> 64)
                    -- ==========================
                    when LAYER_1_CALC =>
                        mac_reset <= '0';
                        ram_h1_we <= '0';
                        if calc_step = 0 then
                            ram_in_addr   <= std_logic_vector(to_unsigned(input_counter, 12));
                            rom_h1_w_addr <= std_logic_vector(to_unsigned(weight_counter, 18));
                            calc_step <= 1;
                        elsif calc_step = 1 then calc_step <= 2;
                        elsif calc_step = 2 then
                            mac_pixel  <= signed(ram_in_dout);
                            mac_weight <= signed(rom_h1_w_dout);
                            mac_enable <= '1';
                            calc_step <= 3;
                        elsif calc_step = 3 then
                            mac_enable <= '0';
                            if input_counter < 2351 then
                                input_counter  <= input_counter + 1;
                                weight_counter <= weight_counter + 1;
                                calc_step <= 0; 
                            else
                                rom_h1_b_addr <= std_logic_vector(to_unsigned(neuron_counter, 6));
                                current_state <= LAYER_1_ACTIVATE;
                                calc_step <= 0;
                            end if;
                        end if;

                    when LAYER_1_ACTIVATE =>
                        if calc_step = 0 then calc_step <= 1;
                        elsif calc_step = 1 then
                            accum_with_bias <= mac_accum + signed(rom_h1_b_dout);
                            calc_step <= 2;
                        elsif calc_step = 2 then
                            ram_h1_we <= '1';
                            ram_h1_addr <= std_logic_vector(to_unsigned(neuron_counter, 6));
                            act_tmp := shift_right(accum_with_bias, 8);
                            if act_tmp < 0 then ram_h1_din <= x"00"; -- ReLU
                            elsif act_tmp > 127 then ram_h1_din <= x"7F";
                            else ram_h1_din <= std_logic_vector(act_tmp(7 downto 0));
                            end if;
                            calc_step <= 3;
                        elsif calc_step = 3 then
                            ram_h1_we <= '0';
                            if neuron_counter < 63 then
                                neuron_counter <= neuron_counter + 1;
                                input_counter <= 0;
                                mac_reset <= '1';
                                calc_step <= 0;
                                current_state <= LAYER_1_CALC;
                            else
                                -- SETUP FOR LAYER 2
                                neuron_counter <= 0; 
                                input_counter <= 0;
                                weight_counter <= 0;
                                mac_reset <= '1';
                                calc_step <= 0;
                                current_state <= LAYER_2_CALC;
                            end if;
                        end if;

                    -- ==========================
                    -- LAYER 2 (64 -> 32)
                    -- ==========================
                    when LAYER_2_CALC =>
                        mac_reset <= '0';
                        ram_h2_we <= '0';
                        if calc_step = 0 then
                            ram_h1_addr   <= std_logic_vector(to_unsigned(input_counter, 6));
                            rom_h2_w_addr <= std_logic_vector(to_unsigned(weight_counter, 11));
                            calc_step <= 1;
                        elsif calc_step = 1 then calc_step <= 2;
                        elsif calc_step = 2 then
                            mac_pixel  <= signed(ram_h1_dout);
                            mac_weight <= signed(rom_h2_w_dout);
                            mac_enable <= '1';
                            calc_step <= 3;
                        elsif calc_step = 3 then
                            mac_enable <= '0';
                            if input_counter < 63 then
                                input_counter  <= input_counter + 1;
                                weight_counter <= weight_counter + 1;
                                calc_step <= 0; 
                            else
                                rom_h2_b_addr <= std_logic_vector(to_unsigned(neuron_counter, 5));
                                current_state <= LAYER_2_ACTIVATE;
                                calc_step <= 0;
                            end if;
                        end if;

                    when LAYER_2_ACTIVATE =>
                        if calc_step = 0 then calc_step <= 1;
                        elsif calc_step = 1 then
                            accum_with_bias <= mac_accum + signed(rom_h2_b_dout);
                            calc_step <= 2;
                        elsif calc_step = 2 then
                            ram_h2_we <= '1';
                            ram_h2_addr <= std_logic_vector(to_unsigned(neuron_counter, 5));
                            act_tmp := shift_right(accum_with_bias, 8);
                            if act_tmp < 0 then ram_h2_din <= x"00"; -- ReLU
                            elsif act_tmp > 127 then ram_h2_din <= x"7F";
                            else ram_h2_din <= std_logic_vector(act_tmp(7 downto 0));
                            end if;
                            calc_step <= 3;
                        elsif calc_step = 3 then
                            ram_h2_we <= '0';
                            if neuron_counter < 31 then
                                neuron_counter <= neuron_counter + 1;
                                input_counter <= 0;
                                mac_reset <= '1';
                                calc_step <= 0;
                                current_state <= LAYER_2_CALC;
                            else
                                -- SETUP FOR OUTPUT LAYER
                                neuron_counter <= 0;
                                input_counter <= 0;
                                mac_reset <= '1';
                                calc_step <= 0;
                                current_state <= OUTPUT_CALC;
                            end if;
                        end if;

                    -- ==========================
                    -- OUTPUT LAYER (32 -> 1)
                    -- ==========================
                    when OUTPUT_CALC =>
                        mac_reset <= '0';
                        if calc_step = 0 then
                            ram_h2_addr    <= std_logic_vector(to_unsigned(input_counter, 5));
                            rom_out_w_addr <= std_logic_vector(to_unsigned(input_counter, 5));
                            calc_step <= 1;
                        elsif calc_step = 1 then calc_step <= 2;
                        elsif calc_step = 2 then
                            mac_pixel  <= signed(ram_h2_dout);
                            mac_weight <= signed(rom_out_w_dout);
                            mac_enable <= '1';
                            calc_step <= 3;
                        elsif calc_step = 3 then
                            mac_enable <= '0';
                            if input_counter < 31 then
                                input_counter <= input_counter + 1;
                                calc_step <= 0; 
                            else
                                rom_out_b_addr <= "0";
                                current_state <= OUTPUT_ACTIVATE;
                                calc_step <= 0;
                            end if;
                        end if;

                    when OUTPUT_ACTIVATE =>
                        if calc_step = 0 then calc_step <= 1; 
                        elsif calc_step = 1 then
                            accum_with_bias <= mac_accum + signed(rom_out_b_dout);
                            current_state <= FINISHED;
                        end if;

                    when FINISHED =>
                        done <= '1';
                        -- Final Output classification
                        if accum_with_bias > 0 then 
                            result <= '1'; -- Dog
                        else
                            result <= '0'; -- Cat
                        end if;
                        current_state <= IDLE;

                end case;
            end if;
        end if;
    end process;

end Behavioral;
