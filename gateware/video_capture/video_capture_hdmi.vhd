library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg_general.all;
use work.pkg_axi.all;

entity video_capture_hdmi is
    generic (
        num_chan    : integer := 4;
        clk_enc_mhz : real    := 1000.0/7.0
        );
    port (
        hdmi_scl      : inout std_logic;
        hdmi_sda      : inout std_logic;
        hdmi_hpd      : out   std_logic;
        hdmi_tmds_p   : in    std_logic_vector(3 downto 0);
        hdmi_tmds_n   : in    std_logic_vector(3 downto 0);
        clk_200       : in    std_logic;
        rst_200       : in    std_logic;
        clk_enc       : in    std_logic;
        rst_enc       : in    std_logic;
        enc_m_axi_out : out   axi4_mout_sin_array(num_chan-1 downto 0);
        enc_m_axi_in  : in    axi4_min_sout_array(num_chan-1 downto 0);
        reg_s_axi_in  : in    axi4lite_mout_sin;
        reg_s_axi_out : out   axi4lite_min_sout;
        rgb_led       : out   std_logic_vector(2 downto 0)
        );
end video_capture_hdmi;

architecture rtl of video_capture_hdmi is

    signal clk_px_io       : std_logic;
    signal mmcm_rst        : std_logic;
    signal clk_px          : std_logic;
    signal mmcm_locked     : std_logic;
    signal res_detect_rst  : std_logic;
    signal vid_data        : std_logic_vector(23 downto 0);
    signal vid_dval        : std_logic;
    signal vid_hsync       : std_logic;
    signal vid_vsync       : std_logic;
    signal det_range       : std_logic_vector(0 to 2);
    signal px_clk_good     : std_logic;
    signal res_stable      : std_logic;
    signal capture_rst     : std_logic;
    signal capture_wr_done : std_logic;

begin

    hdmi_rx_inst : entity work.hdmi_rx
        port map (
            hdmi_scl      => hdmi_scl,                -- inout std_logic;
            hdmi_sda      => hdmi_sda,                -- inout std_logic;
            hdmi_hpd      => hdmi_hpd,                -- out   std_logic;
            hdmi_tmds_p   => hdmi_tmds_p,             -- in    std_logic_vector(3 downto 0);
            hdmi_tmds_n   => hdmi_tmds_n,             -- in    std_logic_vector(3 downto 0);
            clk_200       => clk_200,                 -- in    std_logic;
            rst_200       => rst_200,                 -- in    std_logic;
            clk_px_io     => clk_px_io,               -- out   std_logic;
            rst_mmcm      => mmcm_rst,                -- in    std_logic;
            clk_px        => clk_px,                  -- out   std_logic;
            clk_px_locked => mmcm_locked,             -- out   std_logic;
            rst_tmds_lock => res_detect_rst,          -- in    std_logic;
            px_r          => vid_data(7 downto 0),    -- out   std_logic_vector(7 downto 0);
            px_b          => vid_data(23 downto 16),  -- out   std_logic_vector(7 downto 0);
            px_g          => vid_data(15 downto 8),   -- out   std_logic_vector(7 downto 0);
            px_valid      => vid_dval,                -- out   std_logic;
            px_hsync      => vid_hsync,               -- out   std_logic;
            px_vsync      => vid_vsync                -- out   std_logic
            );

    clk_activity_detect_inst : entity work.clk_activity_detect
        generic map (
            clk_ref_mhz     => clk_enc_mhz,  -- real       := 1000.0/7.0;
            clk_det_mhz_max => 400.0,        -- real       := 400.0;
            clk_det_mhz_min => 10.0,         -- real       := 10.0;
            num_thresholds  => 2,            -- positive   := 4;
            thresholds_mhz  => (60.0, 90.0)  -- real_array := (24.0, 40.0, 65.0, 89.0)
            )
        port map (
            clk_ref   => clk_enc,            -- in  std_logic;
            rst_ref   => rst_enc,            -- in  std_logic;
            clk_det   => clk_px_io,          -- in  std_logic;
            det_range => det_range           -- out std_logic_vector(0 to num_thresholds)
            );

    px_clk_good <= not (det_range(det_range'low) or det_range(det_range'high)) when rising_edge(clk_enc);

    hdmi_rx_control_inst : entity work.hdmi_rx_control
        generic map (
            clk_mhz => clk_enc_mhz               -- real := 1000.0/7.0
            )
        port map (
            clk             => clk_enc,          -- in  std_logic;
            px_clk_good     => px_clk_good,      -- in  std_logic;
            mmcm_rst        => mmcm_rst,         -- out std_logic;
            mmcm_locked     => mmcm_locked,      -- in  std_logic;
            res_detect_rst  => res_detect_rst,   -- out std_logic;
            res_stable      => res_stable,       -- in  std_logic;
            capture_rst     => capture_rst,      -- out std_logic;
            capture_wr_done => capture_wr_done,  -- in  std_logic;  -- single pulse per successfully captured image
            rgb_led         => rgb_led           -- out std_logic_vector(2 downto 0)
            );

    video_capture_inst : entity work.video_capture
        generic map (
            num_chan    => num_chan,             -- integer := 4;
            clk_enc_mhz => clk_enc_mhz           -- real    := 1000.0/7.0
            )
        port map (
            clk_px          => clk_px,           -- in  std_logic;
            vid_data_in     => vid_data,         -- in  std_logic_vector(23 downto 0);
            vid_dval_in     => vid_dval,         -- in  std_logic;
            vid_hsync_in    => vid_hsync,        -- in  std_logic;
            vid_vsync_in    => vid_vsync,        -- in  std_logic;
            clk_enc         => clk_enc,          -- in  std_logic;
            rst_enc         => rst_enc,          -- in  std_logic;
            res_detect_rst  => res_detect_rst,   -- in  std_logic;
            res_stable      => res_stable,       -- out std_logic;
            capture_rst     => capture_rst,      -- in  std_logic;
            capture_wr_done => capture_wr_done,  -- out std_logic;  -- pulse when write to memory completes
            enc_m_axi_out   => enc_m_axi_out,    -- out axi4_mout_sin_array(num_chan-1 downto 0);
            enc_m_axi_in    => enc_m_axi_in,     -- in  axi4_min_sout_array(num_chan-1 downto 0);
            reg_s_axi_in    => reg_s_axi_in,     -- in  axi4lite_mout_sin;
            reg_s_axi_out   => reg_s_axi_out     -- out axi4lite_min_sout
            );

end rtl;