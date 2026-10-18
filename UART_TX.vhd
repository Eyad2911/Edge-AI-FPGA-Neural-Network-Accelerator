library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx is
    generic (
        CLKS_PER_BIT : integer := 868 -- 100 MHz clock / 115200 baud rate
    );
    Port (
        clk        : in  STD_LOGIC;
        tx_start   : in  STD_LOGIC;                    -- Signal from Controller to start sending
        tx_byte    : in  STD_LOGIC_VECTOR(7 downto 0); -- The byte to send (0x01 for Dog, 0x00 for Cat)
        tx_active  : out STD_LOGIC;                    -- High while sending
        tx_serial  : out STD_LOGIC                     -- The physical wire going to the Raspberry Pi
    );
end uart_tx;

architecture Behavioral of uart_tx is

    type state_type is (IDLE, TX_START_BIT, TX_DATA_BITS, TX_STOP_BIT, CLEANUP);
    signal current_state : state_type := IDLE;

    signal clk_count : integer range 0 to CLKS_PER_BIT-1 := 0;
    signal bit_index : integer range 0 to 7 := 0;
    signal tx_data   : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

begin

    process(clk)
    begin
        if rising_edge(clk) then
            case current_state is
                
                when IDLE =>
                    tx_active <= '0';
                    tx_serial <= '1'; -- UART line idles HIGH
                    clk_count <= 0;
                    bit_index <= 0;
                    
                    if tx_start = '1' then
                        tx_data <= tx_byte;
                        current_state <= TX_START_BIT;
                    else
                        current_state <= IDLE;
                    end if;

                when TX_START_BIT =>
                    tx_active <= '1';
                    tx_serial <= '0'; -- Start bit is LOW
                    
                    if clk_count < CLKS_PER_BIT-1 then
                        clk_count <= clk_count + 1;
                        current_state <= TX_START_BIT;
                    else
                        clk_count <= 0;
                        current_state <= TX_DATA_BITS;
                    end if;

                when TX_DATA_BITS =>
                    tx_serial <= tx_data(bit_index);
                    if clk_count < CLKS_PER_BIT-1 then
                        clk_count <= clk_count + 1;
                        current_state <= TX_DATA_BITS;
                    else
                        clk_count <= 0;
                        if bit_index < 7 then
                            bit_index <= bit_index + 1;
                            current_state <= TX_DATA_BITS;
                        else
                            bit_index <= 0;
                            current_state <= TX_STOP_BIT;
                        end if;
                    end if;

                when TX_STOP_BIT =>
                    tx_serial <= '1'; -- Stop bit is HIGH
                    
                    if clk_count < CLKS_PER_BIT-1 then
                        clk_count <= clk_count + 1;
                        current_state <= TX_STOP_BIT;
                    else
                        clk_count <= 0;
                        current_state <= CLEANUP;
                    end if;

                when CLEANUP =>
                    tx_active <= '0';
                    current_state <= IDLE;

            end case;
        end if;
    end process;

end Behavioral;