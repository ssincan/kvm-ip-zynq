library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.pkg_general.all;

entity clk_activity_detect is
    generic (
        clk_ref_mhz     : real       := 1000.0/7.0;
        clk_det_mhz_max : real       := 400.0;
        clk_det_mhz_min : real       := 10.0;
        num_thresholds  : positive   := 4;
        thresholds_mhz  : real_array := (24.0, 40.0, 65.0, 89.0)
        );
    port (
        clk_ref   : in  std_logic;
        rst_ref   : in  std_logic;
        clk_det   : in  std_logic;
        det_range : out std_logic_vector(0 to num_thresholds)
        );
end clk_activity_detect;

architecture rtl of clk_activity_detect is

    constant min_period_count : positive := 1024;

    function get_det_cnt_width return integer is
        variable result : positive;
    begin
        result := 1;
        while ((clk_det_mhz_max * 1.05) / (2.0**real(result))) >= (clk_ref_mhz / real(min_period_count)) loop
            result := result + 1;
        end loop;
        return result;
    end function get_det_cnt_width;

    constant det_cnt_width                    : positive := get_det_cnt_width;
    constant max_period_count                 : positive := integer(ceil(clk_ref_mhz / ((clk_det_mhz_min * 0.95) / (2.0**real(det_cnt_width)))));
    constant period_cnt_width                 : positive := num_bits(max_period_count);
    constant period_cnt_consistent_cnt_target : positive := 3;

    type period_array is array (natural range <>) of unsigned(period_cnt_width-1 downto 0);

    function get_period_cmp_array return period_array is
        variable result : period_array(0 to num_thresholds-1);
    begin
        for i in result'range loop
            result(i) := to_unsigned(integer(round(clk_ref_mhz / (thresholds_mhz(i) / (2.0**real(det_cnt_width))))), period_cnt_width);
        end loop;
        return result;
    end function get_period_cmp_array;

    constant period_cmp_array : period_array(0 to num_thresholds-1) := get_period_cmp_array;

    signal det_cnt                   : unsigned(det_cnt_width-1 downto 0) := (others => '0');
    signal det_cnt_high_ref          : std_logic;
    signal det_cnt_high_ref_p        : std_logic;
    signal det_cnt_high_rise         : std_logic;
    signal period_cnt_overflow       : std_logic;
    signal period_cnt                : unsigned(period_cnt_width-1 downto 0);
    signal period_cnt_estimate       : unsigned(period_cnt'range);
    signal period_cnt_consistent_min : unsigned(period_cnt'range);
    signal period_cnt_consistent_max : unsigned(period_cnt'range);
    signal period_cnt_consistent_cnt : integer range 0 to period_cnt_consistent_cnt_target;
    signal period_cnt_consistent     : std_logic;
    signal period_cmp_result         : std_logic_vector(0 to num_thresholds-1);

begin

    assert thresholds_mhz'low = 0 report "" severity FAILURE;
    assert thresholds_mhz'high = num_thresholds-1 report "" severity FAILURE;
    assert thresholds_mhz'ascending report "" severity FAILURE;

    -- only logic in clk_det domain: free running counter to "divide" clk_det
    counter : process (clk_det)
    begin
        if rising_edge(clk_det) then
            det_cnt <= det_cnt + 1;
        end if;
    end process counter;

    cross_det_cnt : entity work.cdc_synchro
        generic map (
            data_width  => 1,                  -- positive              := 1;
            sync_stages => 3                   -- integer range 2 to 10 := 3
            )
        port map (
            din(0)  => det_cnt(det_cnt'high),  -- in  std_logic_vector(data_width-1 downto 0);
            clk     => clk_ref,                -- in  std_logic;
            dout(0) => det_cnt_high_ref        -- out std_logic_vector(data_width-1 downto 0)
            );

    det_cnt_high_edge_detect : process (clk_ref)
    begin
        if rising_edge(clk_ref) then
            det_cnt_high_ref_p <= det_cnt_high_ref;
            det_cnt_high_rise  <= det_cnt_high_ref and not det_cnt_high_ref_p;
        end if;
    end process det_cnt_high_edge_detect;

    period_counter : process (clk_ref)
    begin
        if rising_edge(clk_ref) then
            -- tolerance: +/- 3.125%
            period_cnt_consistent_min <= period_cnt_estimate - shift_right(period_cnt_estimate, 5);
            period_cnt_consistent_max <= period_cnt_estimate + shift_right(period_cnt_estimate, 5);
            if det_cnt_high_rise = '1' then
                period_cnt                                                   <= (others => '0');
                period_cnt_overflow                                          <= '0';
                period_cnt_estimate                                          <= period_cnt;
                if (period_cnt >= period_cnt_consistent_min) and (period_cnt <= period_cnt_consistent_max) then
                    if period_cnt_consistent_cnt < period_cnt_consistent_cnt_target then
                        period_cnt_consistent_cnt <= period_cnt_consistent_cnt + 1;
                    else
                        period_cnt_consistent <= '1';
                    end if;
                else
                    period_cnt_consistent     <= '0';
                    period_cnt_consistent_cnt <= 0;
                end if;
                if period_cnt_overflow = '1' then
                    period_cnt_estimate       <= (others => '1');
                    period_cnt_consistent     <= '0';
                    period_cnt_consistent_cnt <= 0;
                end if;
            else
                period_cnt <= period_cnt + 1;
                if and_reduce(std_logic_vector(period_cnt)) = '1' then
                    period_cnt_overflow       <= '1';
                    period_cnt_consistent     <= '0';
                    period_cnt_consistent_cnt <= 0;
                end if;
            end if;
            if rst_ref = '1' then
                period_cnt                <= (others => '1');
                period_cnt_estimate       <= (others => '1');
                period_cnt_overflow       <= '1';
                period_cnt_consistent     <= '0';
                period_cnt_consistent_cnt <= 0;
            end if;
        end if;
    end process period_counter;

    comparator_bank : process (clk_ref)
    begin
        if rising_edge(clk_ref) then
            -- compare
            for i in period_cmp_array'range loop
                if period_cnt_estimate < period_cmp_array(i) then
                    period_cmp_result(i) <= '1';
                else
                    period_cmp_result(i) <= '0';
                end if;
            end loop;
            -- force to "too slow" if inconsistent
            if period_cnt_consistent = '0' then
                period_cmp_result <= (others => '0');
            end if;
            -- decode
            det_range <= (others => '0');
            if and_reduce(period_cmp_result) = '1' then
                -- too fast
                det_range(det_range'high) <= '1';
            elsif or_reduce(period_cmp_result) = '0' then
                -- too slow
                det_range(det_range'low) <= '1';
            else
                for i in 1 to period_cmp_result'high loop
                    if period_cmp_result(i) = '0' then
                        det_range(i) <= '1';
                        exit;
                    end if;
                end loop;
            end if;
        end if;
    end process comparator_bank;

end rtl;
