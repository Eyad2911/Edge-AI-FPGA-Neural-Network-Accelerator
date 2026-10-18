library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_level is
    Port ( 
        clk   : in  STD_LOGIC;  -- 100 MHz System Clock
        btnC  : in  STD_LOGIC;  -- Center button for Reset
        RsRx  : in  STD_LOGIC;  -- Physical pin receiving from Raspberry Pi
        RsTx  : out STD_LOGIC;  -- Physical pin transmitting to Raspberry Pi
        led   : out STD_LOGIC_VECTOR(15 downto 0) -- Turn on LEDs to show status!
    );
end top_level;

architecture Behavioral of top_level is

    component uart_rx
        Port ( clk : in STD_LOGIC; rx_serial : in STD_LOGIC; rx_out : out STD_LOGIC_VECTOR(7 downto 0); rx_done : out STD_LOGIC);
    end component;

    component uart_tx
        Port ( clk : in STD_LOGIC; tx_start : in STD_LOGIC; tx_byte : in STD_LOGIC_VECTOR(7 downto 0); tx_active : out STD_LOGIC; tx_serial : out STD_LOGIC);
    end component;

    component nn_controller
        Port ( clk : in STD_LOGIC; reset : in STD_LOGIC; start : in STD_LOGIC; result : out STD_LOGIC; done : out STD_LOGIC;
               rx_data : in STD_LOGIC_VECTOR(7 downto 0); rx_we : in STD_LOGIC; rx_addr : in STD_LOGIC_VECTOR(11 downto 0));
    end component;

    signal rx_byte_wire : STD_LOGIC_VECTOR(7 downto 0);
    signal rx_done_wire : STD_LOGIC;
    signal ai_start     : STD_LOGIC := '0';
    signal ai_result    : STD_LOGIC;
    signal ai_done      : STD_LOGIC;
    
    signal tx_start     : STD_LOGIC := '0';
    signal tx_byte_wire : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal pixel_count  : integer range 0 to 2351 := 0;
    signal ram_we       : STD_LOGIC := '0';
    signal ram_addr     : STD_LOGIC_VECTOR(11 downto 0) := (others => '0');

begin

    EARS: uart_rx port map ( clk => clk, rx_serial => RsRx, rx_out => rx_byte_wire, rx_done => rx_done_wire );
    BRAIN: nn_controller port map ( clk => clk, reset => btnC, start => ai_start, result => ai_result, done => ai_done, rx_data => rx_byte_wire, rx_we => ram_we, rx_addr => ram_addr );
    MOUTH: uart_tx port map ( clk => clk, tx_start => tx_start, tx_byte => tx_byte_wire, tx_active => open, tx_serial => RsTx );

    process(clk)
    begin
        if rising_edge(clk) then
            if btnC = '1' then
                pixel_count <= 0;
                ai_start <= '0';
                ram_we <= '0';
            else
                ram_we <= '0';
                ai_start <= '0';
                if rx_done_wire = '1' then
                    ram_we <= '1';
                    ram_addr <= std_logic_vector(to_unsigned(pixel_count, 12));
                    if pixel_count = 2351 then
                        pixel_count <= 0;
                        ai_start <= '1'; 
                    else
                        pixel_count <= pixel_count + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            tx_start <= '0';
            if ai_done = '1' then
                if ai_result = '1' then
                    tx_byte_wire <= x"00";
                    led(15) <= '0';
                    led(0)  <= '1';
                else
                    tx_byte_wire <= x"01";
                    led(15) <= '1';
                    led(0)  <= '0';
                end if;
                tx_start <= '1'; 
            end if;
        end if;
    end process;

end Behavioral;
