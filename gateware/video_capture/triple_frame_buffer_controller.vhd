library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg_general.all;

entity triple_frame_buffer_controller is
    generic (
        num_chan : positive := 4
        );
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        start_read    : in  std_logic_vector(num_chan-1 downto 0);
        end_read      : in  std_logic_vector(num_chan-1 downto 0);
        read_channel  : out std_logic_vector(1 downto 0);  -- 00: none locked, 01 - 11: locked channel
        write_channel : out std_logic_vector(1 downto 0);  -- 01 - 11: write channel
        end_write     : in  std_logic
        );
end triple_frame_buffer_controller;

architecture rtl of triple_frame_buffer_controller is

    function next_write_channel (
        wr_chan : std_logic_vector(1 downto 0);
        rd_chan : std_logic_vector(1 downto 0)
        )
        return std_logic_vector is
        variable result : std_logic_vector(wr_chan'range);
    begin
        -- increment to next channel
        result := std_logic_vector(unsigned(wr_chan)+1);
        -- skip 0, which is invalid
        if result = "00" then
            result := "01";
        end if;
        -- skip read channel
        if result = rd_chan then
            result := std_logic_vector(unsigned(result)+1);
        end if;
        -- skip 0, which is invalid
        if result = "00" then
            result := "01";
        end if;
        return result;
    end function next_write_channel;

    constant max_ref_cnt : positive := 16*num_chan-1;

    signal ref_cnt              : natural range 0 to max_ref_cnt;
    signal read_channel_int     : std_logic_vector(read_channel'range);
    signal write_channel_int    : std_logic_vector(read_channel'range);
    signal latest_write_channel : std_logic_vector(read_channel'range);

begin

    read_channel  <= read_channel_int;
    write_channel <= write_channel_int;

    controller : process (clk)
        variable latest_write_channel_v : std_logic_vector(read_channel'range);
        variable write_channel_int_v    : std_logic_vector(read_channel'range);
        variable ref_cnt_v              : natural range 0 to max_ref_cnt;
    begin
        if rising_edge(clk) then

            latest_write_channel_v := latest_write_channel;
            write_channel_int_v    := write_channel_int;
            ref_cnt_v              := ref_cnt;

            if end_write = '1' then
                latest_write_channel_v := write_channel_int_v;
                write_channel_int_v    := next_write_channel(write_channel_int_v, read_channel_int);
            end if;

            ref_cnt_v := ref_cnt_v - count_ones(end_read);
            if ref_cnt_v = 0 then
                if or_reduce(start_read) = '1' then
                    read_channel_int <= latest_write_channel_v;
                else
                    read_channel_int <= "00";
                end if;
            end if;
            ref_cnt_v := ref_cnt_v + count_ones(start_read);

            latest_write_channel <= latest_write_channel_v;
            write_channel_int    <= write_channel_int_v;
            ref_cnt              <= ref_cnt_v;

            if rst = '1' then
                ref_cnt              <= 0;
                read_channel_int     <= "00";
                write_channel_int    <= "10";
                latest_write_channel <= "01";
            end if;

        end if;
    end process controller;

end rtl;