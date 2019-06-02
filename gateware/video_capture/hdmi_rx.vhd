library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library xpm;
use xpm.vcomponents.all;

library work;

entity hdmi_rx is
    port (
        hdmi_scl      : inout std_logic;
        hdmi_sda      : inout std_logic;
        hdmi_hpd      : out   std_logic;
        hdmi_tmds_p   : in    std_logic_vector(3 downto 0);
        hdmi_tmds_n   : in    std_logic_vector(3 downto 0);
        clk_200       : in    std_logic;
        rst_200       : in    std_logic;
        clk_px_io     : out   std_logic;
        rst_mmcm      : in    std_logic;
        clk_px        : out   std_logic;
        clk_px_locked : out   std_logic;
        rst_tmds_lock : in    std_logic;
        px_r          : out   std_logic_vector(7 downto 0);
        px_b          : out   std_logic_vector(7 downto 0);
        px_g          : out   std_logic_vector(7 downto 0);
        px_valid      : out   std_logic;
        px_hsync      : out   std_logic;
        px_vsync      : out   std_logic
        );
end hdmi_rx;

architecture structural of hdmi_rx is

    signal SDA_I : std_logic;
    signal SDA_O : std_logic;
    signal SDA_T : std_logic;
    signal SCL_I : std_logic;
    signal SCL_O : std_logic;
    signal SCL_T : std_logic;

    signal restart_lock : std_logic;
    signal clk_px_int   : std_logic;

begin

    -- EDID ROM runs on the 200 MHz clock
    hdmi_hpd <= not rst_200 when rising_edge(clk_200);

    dvi2rgb_inst : entity work.dvi2rgb
        generic map (
            kEmulateDDC    => true,                              -- boolean := true;                 -- will emulate a DDC EEPROM with basic EDID, if set to yes 
            kRstActiveHigh => true,                              -- boolean := true;                 -- true, if active-high; false, if active-low
            kAddBUFG       => true,                              -- boolean := true;                 -- true, if PixelClk should be re-buffered with BUFG            
            kClkRange      => 2,                                 -- natural := 2;                    -- MULT_F = kClkRange*5 (choose >=120MHz=1, >=60MHz=2, >=40MHz=3)
            kEdidFileName  => "custom_edid.data",                -- string  := "dgl_720p_cea.data";  -- Select EDID file to use
            kDebug         => false                              -- boolean := true;
            )
        port map (
            -- DVI 1.0 TMDS video interface
            TMDS_Clk_p              => hdmi_tmds_p(3),           -- in std_logic;
            TMDS_Clk_n              => hdmi_tmds_n(3),           -- in std_logic;
            TMDS_Data_p             => hdmi_tmds_p(2 downto 0),  -- in std_logic_vector(2 downto 0);
            TMDS_Data_n             => hdmi_tmds_n(2 downto 0),  -- in std_logic_vector(2 downto 0);
            -- Auxiliary signals 
            RefClk                  => clk_200,                  -- in std_logic;  -- 200 MHz reference clock for IDELAYCTRL, reset, lock monitoring etc.
            aRst                    => rst_200,                  -- in std_logic;  -- asynchronous reset; must be reset when RefClk is not within spec
            aRst_n                  => '1',                      -- in std_logic;  -- asynchronous reset; must be reset when RefClk is not within spec
            PixelMMCMReset          => rst_mmcm,                 -- in std_logic := '0'; -- advanced use only; force MMCM reset
            -- Video out
            vid_pData(23 downto 16) => px_r,                     -- out std_logic_vector(23 downto 0);
            vid_pData(15 downto 8)  => px_b,                     -- out std_logic_vector(23 downto 0);
            vid_pData(7 downto 0)   => px_g,                     -- out std_logic_vector(23 downto 0);
            vid_pVDE                => px_valid,                 -- out std_logic;
            vid_pHSync              => px_hsync,                 -- out std_logic;
            vid_pVSync              => px_vsync,                 -- out std_logic;
            PixelClk                => clk_px_int,               -- out std_logic;  -- pixel-clock recovered from the DVI interface
            TMDS_Clk                => clk_px_io,                -- out std_logic; -- advanced use only; TMDS_Clk
            SerialClk               => open,                     -- out std_logic;  -- advanced use only; 5x PixelClk
            aPixelClkLckd           => clk_px_locked,            -- out std_logic;  -- advanced use only; PixelClk and SerialClk stable
            -- Optional DDC port
            SDA_I                   => SDA_I,                    -- in  std_logic;
            SDA_O                   => SDA_O,                    -- out std_logic;
            SDA_T                   => SDA_T,                    -- out std_logic;
            SCL_I                   => SCL_I,                    -- in  std_logic;
            SCL_O                   => SCL_O,                    -- out std_logic;
            SCL_T                   => SCL_T,                    -- out std_logic;
            pRst                    => restart_lock,             -- in std_logic;  -- synchronous reset; will restart locking procedure
            pRst_n                  => '1'                       -- in std_logic   -- synchronous reset; will restart locking procedure
            );

    rst_lock_sync : entity work.rst_synchro
        generic map (
            rst_in_active_high  => true,  -- boolean               := true;
            rst_out_active_high => true,  -- boolean               := true;
            rst_out_min_cycles  => 8      -- integer range 3 to 10 := 4
            )
        port map (
            arst => rst_tmds_lock,        -- in  std_logic;           -- captured asynchronously
            clk  => clk_px_int,           -- in  std_logic;
            rst  => restart_lock          -- out std_logic            -- fully synchronous
            );

    clk_px <= clk_px_int;

    IOBUF_sda : IOBUF
        port map (
            O  => SDA_I,                -- out   std_ulogic;
            IO => hdmi_sda,             -- inout std_ulogic;
            I  => SDA_O,                -- in    std_ulogic;
            T  => SDA_T                 -- in    std_ulogic
            );

    IOBUF_scl : IOBUF
        port map (
            O  => SCL_I,                -- out   std_ulogic;
            IO => hdmi_scl,             -- inout std_ulogic;
            I  => SCL_O,                -- in    std_ulogic;
            T  => SCL_T                 -- in    std_ulogic
            );

end structural;