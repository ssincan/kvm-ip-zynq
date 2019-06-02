library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg_axi.all;
use work.pkg_general.all;

entity kvm_top is
    port (
        DDR_addr          : inout std_logic_vector(14 downto 0);
        DDR_ba            : inout std_logic_vector(2 downto 0);
        DDR_cas_n         : inout std_logic;
        DDR_ck_n          : inout std_logic;
        DDR_ck_p          : inout std_logic;
        DDR_cke           : inout std_logic;
        DDR_cs_n          : inout std_logic;
        DDR_dm            : inout std_logic_vector(3 downto 0);
        DDR_dq            : inout std_logic_vector(31 downto 0);
        DDR_dqs_n         : inout std_logic_vector(3 downto 0);
        DDR_dqs_p         : inout std_logic_vector(3 downto 0);
        DDR_odt           : inout std_logic;
        DDR_ras_n         : inout std_logic;
        DDR_reset_n       : inout std_logic;
        DDR_we_n          : inout std_logic;
        FIXED_IO_ddr_vrn  : inout std_logic;
        FIXED_IO_ddr_vrp  : inout std_logic;
        FIXED_IO_mio      : inout std_logic_vector(53 downto 0);
        FIXED_IO_ps_clk   : inout std_logic;
        FIXED_IO_ps_porb  : inout std_logic;
        FIXED_IO_ps_srstb : inout std_logic;
        hdmi_rx_scl       : inout std_logic;
        hdmi_rx_sda       : inout std_logic;
        hdmi_rx_hpd       : out   std_logic;
        hdmi_rx_p         : in    std_logic_vector(3 downto 0);
        hdmi_rx_n         : in    std_logic_vector(3 downto 0);
        rgb_led           : out   std_logic_vector(2 downto 0)
        );
end kvm_top;

architecture structural of kvm_top is

    signal REF_CLK         : std_logic;
    signal REF_RST         : std_logic;
    signal ACLK            : std_logic;
    signal ARESET          : std_logic;
    signal M_AXI_REG0_OUT  : axi4lite_mout_sin;
    signal M_AXI_REG0_IN   : axi4lite_min_sout;
    signal M_AXI_REG1_OUT  : axi4lite_mout_sin;
    signal M_AXI_REG1_IN   : axi4lite_min_sout;
    signal S_AXI_DRAM0_OUT : axi4_min_sout;
    signal S_AXI_DRAM0_IN  : axi4_mout_sin;
    signal S_AXI_DRAM1_OUT : axi4_min_sout;
    signal S_AXI_DRAM1_IN  : axi4_mout_sin;
    signal S_AXI_DRAM2_OUT : axi4_min_sout;
    signal S_AXI_DRAM2_IN  : axi4_mout_sin;
    signal S_AXI_DRAM3_OUT : axi4_min_sout;
    signal S_AXI_DRAM3_IN  : axi4_mout_sin;

begin

    zynq_ps_wrap_inst : entity work.zynq_ps_wrap
        port map (
            DDR_addr          => DDR_addr,           -- inout std_logic_vector(14 downto 0);
            DDR_ba            => DDR_ba,             -- inout std_logic_vector(2 downto 0);
            DDR_cas_n         => DDR_cas_n,          -- inout std_logic;
            DDR_ck_n          => DDR_ck_n,           -- inout std_logic;
            DDR_ck_p          => DDR_ck_p,           -- inout std_logic;
            DDR_cke           => DDR_cke,            -- inout std_logic;
            DDR_cs_n          => DDR_cs_n,           -- inout std_logic;
            DDR_dm            => DDR_dm,             -- inout std_logic_vector(3 downto 0);
            DDR_dq            => DDR_dq,             -- inout std_logic_vector(31 downto 0);
            DDR_dqs_n         => DDR_dqs_n,          -- inout std_logic_vector(3 downto 0);
            DDR_dqs_p         => DDR_dqs_p,          -- inout std_logic_vector(3 downto 0);
            DDR_odt           => DDR_odt,            -- inout std_logic;
            DDR_ras_n         => DDR_ras_n,          -- inout std_logic;
            DDR_reset_n       => DDR_reset_n,        -- inout std_logic;
            DDR_we_n          => DDR_we_n,           -- inout std_logic;
            FIXED_IO_ddr_vrn  => FIXED_IO_ddr_vrn,   -- inout std_logic;
            FIXED_IO_ddr_vrp  => FIXED_IO_ddr_vrp,   -- inout std_logic;
            FIXED_IO_mio      => FIXED_IO_mio,       -- inout std_logic_vector(53 downto 0);
            FIXED_IO_ps_clk   => FIXED_IO_ps_clk,    -- inout std_logic;
            FIXED_IO_ps_porb  => FIXED_IO_ps_porb,   -- inout std_logic;
            FIXED_IO_ps_srstb => FIXED_IO_ps_srstb,  -- inout std_logic;
            REF_CLK           => REF_CLK,            -- out   std_logic;
            REF_RST           => REF_RST,            -- out   std_logic;
            ACLK              => ACLK,               -- out   std_logic;
            ARESET            => ARESET,             -- out   std_logic;
            M_AXI_REG0_OUT    => M_AXI_REG0_OUT,     -- out   axi4lite_mout_sin;
            M_AXI_REG0_IN     => M_AXI_REG0_IN,      -- in    axi4lite_min_sout;
            M_AXI_REG1_OUT    => M_AXI_REG1_OUT,     -- out   axi4lite_mout_sin;
            M_AXI_REG1_IN     => M_AXI_REG1_IN,      -- in    axi4lite_min_sout;
            S_AXI_DRAM0_OUT   => S_AXI_DRAM0_OUT,    -- out   axi4_min_sout;
            S_AXI_DRAM0_IN    => S_AXI_DRAM0_IN,     -- in    axi4_mout_sin;
            S_AXI_DRAM1_OUT   => S_AXI_DRAM1_OUT,    -- out   axi4_min_sout;
            S_AXI_DRAM1_IN    => S_AXI_DRAM1_IN,     -- in    axi4_mout_sin;
            S_AXI_DRAM2_OUT   => S_AXI_DRAM2_OUT,    -- out   axi4_min_sout;
            S_AXI_DRAM2_IN    => S_AXI_DRAM2_IN,     -- in    axi4_mout_sin;
            S_AXI_DRAM3_OUT   => S_AXI_DRAM3_OUT,    -- out   axi4_min_sout;
            S_AXI_DRAM3_IN    => S_AXI_DRAM3_IN      -- in    axi4_mout_sin
            );

    video_capture_hdmi_inst : entity work.video_capture_hdmi
        generic map (
            num_chan    => 4,                     -- integer := 4;
            clk_enc_mhz => 1000.0/7.0             -- real    := 1000.0/7.0
            )
        port map (
            hdmi_scl         => hdmi_rx_scl,      -- inout std_logic;
            hdmi_sda         => hdmi_rx_sda,      -- inout std_logic;
            hdmi_hpd         => hdmi_rx_hpd,      -- out   std_logic;
            hdmi_tmds_p      => hdmi_rx_p,        -- in    std_logic_vector(3 downto 0);
            hdmi_tmds_n      => hdmi_rx_n,        -- in    std_logic_vector(3 downto 0);
            clk_200          => REF_CLK,          -- in    std_logic;
            rst_200          => REF_RST,          -- in    std_logic;
            clk_enc          => ACLK,             -- in    std_logic;
            rst_enc          => ARESET,           -- in    std_logic;
            enc_m_axi_out(3) => S_AXI_DRAM3_IN,   -- out axi4_mout_sin_array(num_chan-1 downto 0);
            enc_m_axi_out(2) => S_AXI_DRAM1_IN,   -- out axi4_mout_sin_array(num_chan-1 downto 0);
            enc_m_axi_out(1) => S_AXI_DRAM2_IN,   -- out axi4_mout_sin_array(num_chan-1 downto 0);
            enc_m_axi_out(0) => S_AXI_DRAM0_IN,   -- out axi4_mout_sin_array(num_chan-1 downto 0);
            enc_m_axi_in(3)  => S_AXI_DRAM3_OUT,  -- in  axi4_min_sout_array(num_chan-1 downto 0);
            enc_m_axi_in(2)  => S_AXI_DRAM1_OUT,  -- in  axi4_min_sout_array(num_chan-1 downto 0);
            enc_m_axi_in(1)  => S_AXI_DRAM2_OUT,  -- in  axi4_min_sout_array(num_chan-1 downto 0);
            enc_m_axi_in(0)  => S_AXI_DRAM0_OUT,  -- in  axi4_min_sout_array(num_chan-1 downto 0);
            reg_s_axi_in     => M_AXI_REG0_OUT,   -- in  axi4lite_mout_sin;
            reg_s_axi_out    => M_AXI_REG0_IN,    -- out axi4lite_min_sout
            rgb_led          => rgb_led           -- out   std_logic_vector(2 downto 0)
            );

    -- TODO: module to communicate via UART with Pro Micro based mouse/keyboard emulator?
    axi4lite_reg_file_inst : entity work.axi4lite_reg_file
        generic map (
            G_S_AXI_NUM_REGISTERS => 1,       -- integer          := 4;
            G_S_AXI_REG_IS_STATUS => "1"      -- std_logic_vector := "0000"               -- if G_S_AXI_REG_IS_STATUS(i) = '1', register i will be read from reg_rdata(i)
            )
        port map (
            -- AXI4-Lite Bus
            S_AXI_ACLK    => ACLK,            -- in  std_logic;
            S_AXI_ARESETN => "not"(ARESET),   -- in  std_logic;
            S_AXI_IN      => M_AXI_REG1_OUT,  -- in  axi4lite_mout_sin;
            S_AXI_OUT     => M_AXI_REG1_IN,   -- out axi4lite_min_sout;
            -- register interface to/from fabric logic
            reg_rdata(0)  => x"CABBA6E6",     -- in  slv32d_array(0 to G_S_AXI_NUM_REGISTERS-1);  -- applicable only for status registers
            reg_wdata     => open,            -- out slv32d_array(0 to G_S_AXI_NUM_REGISTERS-1);
            reg_wpulse    => open             -- out std_logic_vector(0 to G_S_AXI_NUM_REGISTERS-1)
            );

end structural;