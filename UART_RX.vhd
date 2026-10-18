library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx is
    generic (
        -- 100 MHz clock / 115200 baud rate = ~868 clock cycles per bit
        CLKS_PER_BIT : integer := 868 
    );
    Port (
        clk       : in  STD_LOGIC;
        rx_serial : in  STD_LOGIC;                    -- The physical wire from the Raspberry Pi
        rx_out    : out STD_LOGIC_VECTOR(7 downto 0); -- The full 8-bit pixel after we catch it
        rx_done   : out STD_LOGIC                     -- Goes high for 1 tick when a byte is fully received
    );
end uart_rx;

architecture Behavioral of uart_rx is

    type state_type is (IDLE, RX_START_BIT, RX_DATA_BITS, RX_STOP_BIT, CLEANUP);
    signal current_state : state_type := IDLE;

    signal clk_count : integer range 0 to CLKS_PER_BIT-1 := 0;
    signal bit_index : integer range 0 to 7 := 0;
    signal rx_byte   : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

begin

    process(clk)
    begin
        if rising_edge(clk) then
            case current_state is
                
                when IDLE =>
                    rx_done <= '0';
                    clk_count <= 0;
                    bit_index <= 0;
                    
                    if rx_serial = '0' then  -- A '0' means the Start Bit has arrived!
                        current_state <= RX_START_BIT;
                    else
                        current_state <= IDLE;
                    end if;

                when RX_START_BIT =>
                    -- Wait until the middle of the start bit to check it
                    if clk_count = (CLKS_PER_BIT-1)/2 then
                        if rx_serial = '0' then
                            clk_count <= 0; -- Reset counter, found the middle
                            current_state <= RX_DATA_BITS;
                        else
                            current_state <= IDLE;
                        end if;
                    else
                        clk_count <= clk_count + 1;
                        current_state <= RX_START_BIT;
                    end if;

                when RX_DATA_BITS =>
                    -- Wait one full bit period to read the next data bit
                    if clk_count = CLKS_PER_BIT-1 then
                        clk_count <= 0;
                        rx_byte(bit_index) <= rx_serial;
                        
                        if bit_index < 7 then
                            bit_index <= bit_index + 1;
                            current_state <= RX_DATA_BITS;
                        else
                            bit_index <= 0;
                            current_state <= RX_STOP_BIT;
                        end if;
                    else
                        clk_count <= clk_count + 1;
                        current_state <= RX_DATA_BITS;
                    end if;

                when RX_STOP_BIT =>
                    -- Wait one full bit period for the stop bit
                    if clk_count = CLKS_PER_BIT-1 then
                        rx_out <= rx_byte;
                        rx_done <= '1';
                        clk_count <= 0;
                        current_state <= CLEANUP;
                    else
                        clk_count <= clk_count + 1;
                        current_state <= RX_STOP_BIT;
                    end if;

                when CLEANUP =>
                    current_state <= IDLE;
                    rx_done <= '0';

            end case;
        end if;
    end process;

end Behavioral;