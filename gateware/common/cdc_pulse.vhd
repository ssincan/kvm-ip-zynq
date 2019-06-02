library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

entity cdc_pulse is
    generic (
        sync_stages : integer range 2 to 10 := 3
        );
    port (
        src_clk    : in  std_logic;
        src_pulse  : in  std_logic;
        dest_clk   : in  std_logic;
        dest_pulse : out std_logic
        );
end cdc_pulse;

architecture rtl of cdc_pulse is

    signal toggle_src    : std_logic := '0';
    signal toggle_dest   : std_logic := '0';
    signal toggle_dest_p : std_logic := '0';

begin

    process (src_clk)
    begin
        if rising_edge(src_clk) then
            if src_pulse = '1' then
                toggle_src <= not toggle_src;
            end if;
        end if;
    end process;

    toggle_sync : entity work.cdc_synchro
        generic map (
            sync_stages => sync_stages  -- integer range 2 to 10 := 3
            )
        port map (
            din(0)  => toggle_src,      -- in  std_logic_vector(data_width-1 downto 0);
            clk     => dest_clk,        -- in  std_logic;
            dout(0) => toggle_dest      -- out std_logic_vector(data_width-1 downto 0)  -- do not assume all bits will propagate in the same cycle!
            );

    process (dest_clk)
    begin
        if rising_edge(dest_clk) then
            toggle_dest_p <= toggle_dest;
            dest_pulse    <= toggle_dest_p xor toggle_dest;
        end if;
    end process;

end rtl;