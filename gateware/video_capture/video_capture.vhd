library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.pkg_general.all;
use work.pkg_axi.all;

entity video_capture is
    generic (
        num_chan    : integer := 4;
        clk_enc_mhz : real    := 1000.0/7.0
        );
    port (
        clk_px          : in  std_logic;
        vid_data_in     : in  std_logic_vector(23 downto 0);
        vid_dval_in     : in  std_logic;
        vid_hsync_in    : in  std_logic;
        vid_vsync_in    : in  std_logic;
        clk_enc         : in  std_logic;
        rst_enc         : in  std_logic;
        res_detect_rst  : in  std_logic;
        res_stable      : out std_logic;
        capture_rst     : in  std_logic;
        capture_wr_done : out std_logic;  -- pulse when write to memory completes
        enc_m_axi_out   : out axi4_mout_sin_array(num_chan-1 downto 0);
        enc_m_axi_in    : in  axi4_min_sout_array(num_chan-1 downto 0);
        reg_s_axi_in    : in  axi4lite_mout_sin;
        reg_s_axi_out   : out axi4lite_min_sout
        );
end video_capture;

architecture rtl of video_capture is

    signal rst_res_det : std_logic;
    signal vid_res_x   : std_logic_vector(15 downto 0);
    signal vid_res_y   : std_logic_vector(15 downto 0);
    signal rst_px      : std_logic;
    signal px_stable   : std_logic;

begin

    rst_res_det_synchro : entity work.rst_synchro
        generic map (
            rst_in_active_high  => true,  -- boolean               := true;
            rst_out_active_high => true,  -- boolean               := true;
            rst_out_min_cycles  => 4      -- integer range 3 to 10 := 4
            )
        port map (
            arst => res_detect_rst,       -- in  std_logic;        -- captured asynchronously
            clk  => clk_px,               -- in  std_logic;
            rst  => rst_res_det           -- out std_logic         -- fully synchronous
            );

    resolution_detect_inst : entity work.resolution_detect
        port map (
            clk        => clk_px,        -- in  std_logic;
            rst        => rst_res_det,   -- in  std_logic;
            vid_dval   => vid_dval_in,   -- in  std_logic;
            vid_hsync  => vid_hsync_in,  -- in  std_logic;
            vid_vsync  => vid_vsync_in,  -- in  std_logic;
            res_stable => res_stable,    -- out std_logic;
            res_x      => vid_res_x,     -- out std_logic_vector(15 downto 0);
            res_y      => vid_res_y      -- out std_logic_vector(15 downto 0)
            );

    rst_px_synchro : entity work.rst_synchro
        generic map (
            rst_in_active_high  => true,  -- boolean               := true;
            rst_out_active_high => true,  -- boolean               := true;
            rst_out_min_cycles  => 3      -- integer range 3 to 10 := 4
            )
        port map (
            arst => capture_rst,          -- in  std_logic;        -- captured asynchronously
            clk  => clk_px,               -- in  std_logic;
            rst  => rst_px                -- out std_logic         -- fully synchronous
            );

    px_stable <= not capture_rst when rising_edge(clk_enc);

    striped_encoders_inst : entity work.striped_encoders
        generic map (
            num_chan => num_chan                 -- integer := 4
            )
        port map (
            clk_px          => clk_px,           -- in  std_logic;
            rst_px          => rst_px,           -- in  std_logic;
            vid_data_in     => vid_data_in,      -- in  std_logic_vector(23 downto 0);
            vid_dval_in     => vid_dval_in,      -- in  std_logic;
            vid_hsync_in    => vid_hsync_in,     -- in  std_logic;
            vid_vsync_in    => vid_vsync_in,     -- in  std_logic;
            vid_res_x       => vid_res_x,        -- in  std_logic_vector(15 downto 0);
            vid_res_y       => vid_res_y,        -- in  std_logic_vector(15 downto 0);
            clk_enc         => clk_enc,          -- in  std_logic;
            rst_enc         => rst_enc,          -- in  std_logic;
            px_stable       => px_stable,        -- in  std_logic;
            capture_wr_done => capture_wr_done,  -- out std_logic;  -- pulse when write to memory completes
            enc_m_axi_out   => enc_m_axi_out,    -- out axi4_mout_sin_array(num_chan-1 downto 0);
            enc_m_axi_in    => enc_m_axi_in,     -- in  axi4_min_sout_array(num_chan-1 downto 0);
            reg_s_axi_in    => reg_s_axi_in,     -- in  axi4lite_mout_sin;
            reg_s_axi_out   => reg_s_axi_out     -- out axi4lite_min_sout
            );

end rtl;