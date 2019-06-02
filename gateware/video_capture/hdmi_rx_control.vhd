library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.pkg_general.all;

entity hdmi_rx_control is
    generic (
        clk_mhz : real := 1000.0/7.0
        );
    port (
        clk             : in  std_logic;
        px_clk_good     : in  std_logic;
        mmcm_rst        : out std_logic;
        mmcm_locked     : in  std_logic;
        res_detect_rst  : out std_logic;
        res_stable      : in  std_logic;
        capture_rst     : out std_logic;
        capture_wr_done : in  std_logic;  -- single pulse per successfully captured image
        rgb_led         : out std_logic_vector(2 downto 0)
        );
end hdmi_rx_control;

architecture rtl of hdmi_rx_control is

    constant one_ms_ld : positive := integer(ceil(clk_mhz*1000.0))-2;

    type state_type is (wait_clk_good, wait_mmcm_locked, wait_res_stable, periodic_wr_done);

    signal mmcm_locked_sync : std_logic;
    signal res_stable_sync  : std_logic;
    signal state            : state_type                             := wait_clk_good;
    signal timeout_ms       : integer range 0 to 4095                := 1;
    signal ms_counter       : integer range 0 to 4095                := 1;
    signal timeout_load     : std_logic;
    signal time_elapsed     : std_logic;
    signal ms_counter_is_1  : std_logic                              := '1';
    signal timeout_flag     : std_logic                              := '1';
    signal one_ms_counter   : unsigned(num_bits(one_ms_ld) downto 0) := (others => '1');  -- one extra bit to detect underflow

    constant one_ms_counter_ld : unsigned(one_ms_counter'range) := to_unsigned(one_ms_ld, one_ms_counter'length);

begin

    mmcm_locked_cdc : entity work.cdc_synchro
        generic map (
            data_width  => 1,            -- positive              := 1;
            sync_stages => 3             -- integer range 2 to 10 := 3
            )
        port map (
            din(0)  => mmcm_locked,      -- in  std_logic_vector(data_width-1 downto 0);
            clk     => clk,              -- in  std_logic;
            dout(0) => mmcm_locked_sync  -- out std_logic_vector(data_width-1 downto 0)  -- do not assume all bits will propagate in the same cycle!
            );

    res_stable_cdc : entity work.cdc_synchro
        generic map (
            data_width  => 1,           -- positive              := 1;
            sync_stages => 3            -- integer range 2 to 10 := 3
            )
        port map (
            din(0)  => res_stable,      -- in  std_logic_vector(data_width-1 downto 0);
            clk     => clk,             -- in  std_logic;
            dout(0) => res_stable_sync  -- out std_logic_vector(data_width-1 downto 0)  -- do not assume all bits will propagate in the same cycle!
            );

    control : process (clk)
    begin
        if rising_edge(clk) then
            timeout_load   <= '0';
            mmcm_rst       <= '0';
            res_detect_rst <= '0';
            capture_rst    <= '0';
            case state is
                when wait_clk_good =>
                    rgb_led        <= "000";    -- off while clock absent / out of range
                    mmcm_rst       <= '1';
                    res_detect_rst <= '1';
                    capture_rst    <= '1';
                    if px_clk_good = '1' then
                        state        <= wait_mmcm_locked;
                        timeout_ms   <= 10;
                        timeout_load <= '1';
                    end if;
                -- TODO between these states we could use DRP to configure the MMCM
                -- with parameters specific to the detected clock range
                when wait_mmcm_locked =>
                    rgb_led        <= "100";    -- red while waiting for MMCM to lock
                    res_detect_rst <= '1';
                    capture_rst    <= '1';
                    if mmcm_locked_sync = '1' then
                        state        <= wait_res_stable;
                        timeout_ms   <= 4000;
                        timeout_load <= '1';
                    elsif time_elapsed = '1' then
                        state <= wait_clk_good;
                    end if;
                when wait_res_stable =>
                    rgb_led     <= "001";       -- blue while measuring resolution
                    capture_rst <= '1';
                    if res_stable_sync = '1' then
                        rgb_led      <= "110";  -- orange while waiting for first captured image
                        state        <= periodic_wr_done;
                        timeout_ms   <= 2000;   -- larger timeout for first captured image
                        timeout_load <= '1';
                    elsif time_elapsed = '1' then
                        state <= wait_mmcm_locked;
                    end if;
                when others =>                  -- periodic_wr_done
                    if capture_wr_done = '1' then
                        rgb_led      <= "010";  -- green, satisfactory capture
                        timeout_ms   <= 125;    -- at least 8 fps after first image
                        timeout_load <= '1';
                    elsif time_elapsed = '1' then
                        state <= wait_res_stable;
                    end if;
            end case;
            -- force back to lowest suitable state
            if px_clk_good = '0' then
                state <= wait_clk_good;
            elsif mmcm_locked_sync = '0' then
                state <= wait_mmcm_locked;
            elsif res_stable_sync = '0' then
                state <= wait_res_stable;
            end if;
        end if;
    end process control;

    time_elapsed <= timeout_flag and not timeout_load;

    watchdog : process (clk)
    begin
        if rising_edge(clk) then
            ms_counter_is_1 <= conv_sl(ms_counter = 1);
            if timeout_load = '1' then
                one_ms_counter <= one_ms_counter_ld;
                ms_counter     <= timeout_ms;
                timeout_flag   <= '0';
            else
                if one_ms_counter(one_ms_counter'high) = '1' then
                    one_ms_counter <= one_ms_counter_ld;
                    if ms_counter_is_1 = '1' then
                        timeout_flag <= '1';
                    else
                        ms_counter <= ms_counter - 1;
                    end if;
                else
                    one_ms_counter <= one_ms_counter - 1;
                end if;
            end if;
        end if;
    end process watchdog;

end rtl;