library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

entity cdc_synchro is
    generic (
        data_width  : positive              := 1;
        sync_stages : integer range 2 to 10 := 3
        );
    port (
        din  : in  std_logic_vector(data_width-1 downto 0);
        clk  : in  std_logic;
        dout : out std_logic_vector(data_width-1 downto 0)  -- do not assume all bits will propagate in the same cycle!
        );
end cdc_synchro;

architecture xpm_based of cdc_synchro is
begin

    xpm_cdc : xpm_cdc_array_single
        generic map (
            DEST_SYNC_FF   => sync_stages,  -- integer := 4;
            INIT_SYNC_FF   => 0,            -- integer := 0;
            SIM_ASSERT_CHK => 0,            -- integer := 0;
            SRC_INPUT_REG  => 0,            -- integer := 1;
            WIDTH          => din'length    -- integer := 2
            )
        port map (
            src_clk  => '0',                -- in std_logic;
            src_in   => din,                -- in std_logic_vector(WIDTH-1 downto 0);
            dest_clk => clk,                -- in std_logic;
            dest_out => dout                -- out std_logic_vector(WIDTH-1 downto 0)
            );

end xpm_based;