library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity image_shim is
    port (
        clk                    : in  std_logic;
        rst                    : in  std_logic;
        vid_data_in            : in  std_logic_vector(23 downto 0);
        vid_dval_in            : in  std_logic;
        vid_hsync_pos          : in  std_logic;
        vid_vsync_pos          : in  std_logic;
        vid_res_x              : in  std_logic_vector(15 downto 0);
        vid_res_y              : in  std_logic_vector(15 downto 0);
        downstream_ready       : in  std_logic;  -- ready to start new image
        vid_data_out           : out std_logic_vector(23 downto 0);
        vid_dval_out           : out std_logic;
        vid_dval_out_1st       : out std_logic;
        vid_dval_out_last      : out std_logic;
        vid_dval_out_1st_early : out std_logic   -- 16 cycles ahead of vid_dval_1st
        );
end image_shim;

architecture image_shim_arc of image_shim is

    type state_type is (wait_downstream_ready, wait_start_img, fwd_pixels);

    signal res_y_m1         : unsigned(vid_res_y'range);
    signal line_cnt         : unsigned(vid_res_y'range);
    signal last_line        : std_logic;
    signal vid_vsync_pos_p1 : std_logic;
    signal vid_dval_p1      : std_logic;
    signal vid_data_p1      : std_logic_vector(vid_data_in'range);
    signal vid_dval_ds_1st  : std_logic;
    signal vid_dval_ds_last : std_logic;
    signal vid_dval_ds      : std_logic;
    signal vid_data_ds      : std_logic_vector(vid_data_in'range);
    signal state            : state_type := wait_downstream_ready;
    signal wait_first_px    : std_logic;

begin

    gate_image : process (clk)
    begin
        if rising_edge(clk) then
            vid_vsync_pos_p1 <= vid_vsync_pos;
            vid_dval_p1      <= vid_dval_in;
            vid_data_p1      <= vid_data_in;
            last_line        <= '0';
            vid_dval_ds_1st  <= '0';
            vid_dval_ds_last <= '0';
            vid_dval_ds      <= '0';
            vid_data_ds      <= (others => '-');
            res_y_m1         <= unsigned(vid_res_y) - 1;
            if line_cnt = res_y_m1 then
                last_line <= '1';
            end if;
            case state is
                when wait_downstream_ready =>
                    if downstream_ready = '1' then
                        state <= wait_start_img;
                    end if;
                when wait_start_img =>
                    line_cnt      <= (others => '0');
                    wait_first_px <= '1';
                    if vid_vsync_pos_p1 = '1' and vid_vsync_pos = '0' then
                        state <= fwd_pixels;
                    end if;
                when fwd_pixels =>
                    if vid_dval_p1 = '1' and wait_first_px = '1' then
                        vid_dval_ds_1st <= '1';
                        wait_first_px   <= '0';
                    end if;
                    if vid_dval_p1 = '1' and vid_dval_in = '0' then
                        if last_line = '1' then
                            vid_dval_ds_last <= '1';
                            state            <= wait_downstream_ready;
                            line_cnt         <= (others => '-');
                        else
                            line_cnt <= line_cnt + 1;
                        end if;
                    end if;
                    vid_dval_ds <= vid_dval_p1;
                    vid_data_ds <= vid_data_p1;
            end case;
            if rst = '1' then
                state <= wait_downstream_ready;
            end if;
        end if;
    end process gate_image;

    sreg_inferred_inst : entity work.sreg_inferred
        generic map (
            sreg_width => vid_data_ds'length+3,            -- positive       := 18;                    -- shift register width
            sreg_depth => 16                               -- positive       := 1                      -- shift register depth
            )
        port map (
            rst                     => '0',                -- in  std_logic := '0';                         -- asynchronous reset
            clk                     => clk,                -- in  std_logic;                                -- clock
            en                      => '1',                -- in  std_logic := '1';                         -- clock enable
            d(vid_data_ds'length+2) => vid_dval_ds_1st,    -- in  std_logic_vector(sreg_width-1 downto 0);  -- data in
            d(vid_data_ds'length+1) => vid_dval_ds_last,   -- in  std_logic_vector(sreg_width-1 downto 0);  -- data in
            d(vid_data_ds'length+0) => vid_dval_ds,        -- in  std_logic_vector(sreg_width-1 downto 0);  -- data in
            d(vid_data_ds'range)    => vid_data_ds,        -- in  std_logic_vector(sreg_width-1 downto 0);  -- data in
            q(vid_data_ds'length+2) => vid_dval_out_1st,   -- out std_logic_vector(sreg_width-1 downto 0)   -- data out
            q(vid_data_ds'length+1) => vid_dval_out_last,  -- out std_logic_vector(sreg_width-1 downto 0)   -- data out
            q(vid_data_ds'length+0) => vid_dval_out,       -- out std_logic_vector(sreg_width-1 downto 0)   -- data out
            q(vid_data_ds'range)    => vid_data_out        -- out std_logic_vector(sreg_width-1 downto 0)   -- data out
            );

    vid_dval_out_1st_early <= vid_dval_ds_1st;

end image_shim_arc;