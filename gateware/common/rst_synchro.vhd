library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

library work;
use work.pkg_general.all;

entity rst_synchro is
    generic (
        rst_in_active_high  : boolean               := true;
        rst_out_active_high : boolean               := true;
        rst_out_min_cycles  : integer range 3 to 10 := 4
        );
    port (
        arst : in  std_logic;           -- captured asynchronously
        clk  : in  std_logic;
        rst  : out std_logic            -- fully synchronous
        );
end rst_synchro;

architecture xpm_based of rst_synchro is

    signal rst_aasd : std_logic;        -- asynchronous assert, synchronous deassert
    signal rst_sync : std_logic;        -- fully synchronous, active high

begin

    xpm_async : xpm_cdc_async_rst
        generic map (
            DEST_SYNC_FF    => rst_out_min_cycles,           -- integer := 4;
            INIT_SYNC_FF    => 1,                            -- integer := 0;
            RST_ACTIVE_HIGH => conv_nat(rst_in_active_high)  -- integer := 0
            )
        port map (
            src_arst  => arst,                               -- in  std_logic;
            dest_clk  => clk,                                -- in  std_logic;
            dest_arst => rst_aasd                            -- out std_logic
            );

    xpm_sync : xpm_cdc_sync_rst
        generic map (
            DEST_SYNC_FF   => 3,        -- integer := 4;
            INIT           => 1,        -- integer := 1;
            INIT_SYNC_FF   => 1,        -- integer := 0;
            SIM_ASSERT_CHK => 0         -- integer := 0
            )
        port map (
            src_rst  => rst_aasd,       -- in  std_logic;
            dest_clk => clk,            -- in  std_logic;
            dest_rst => rst_sync        -- out std_logic
            );

    -- optionally invert
    rst <= rst_sync xnor conv_sl(rst_out_active_high);

end xpm_based;