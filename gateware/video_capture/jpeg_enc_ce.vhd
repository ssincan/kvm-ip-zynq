library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library work;

entity jpeg_enc_ce is
   port (
      clk : in std_logic;
      ce  : in std_logic;
      rst : in std_logic;

      -- Control
      image_size_x       : in std_logic_vector(15 downto 0);
      image_size_y       : in std_logic_vector(15 downto 0);
      image_size_x_nopad : in std_logic_vector(15 downto 0);
      image_size_y_nopad : in std_logic_vector(15 downto 0);
      image_start        : in std_logic;

      -- Status
      enc_ready : out std_logic;
      enc_size  : out std_logic_vector(23 downto 0);

      -- Image in
      iram_wdata      : in  std_logic_vector(23 downto 0);
      iram_wren       : in  std_logic;
      iram_fifo_afull : out std_logic;

      -- Output
      ram_byte          : out std_logic_vector(7 downto 0);
      ram_wren          : out std_logic;
      ram_wraddr        : out std_logic_vector(23 downto 0);
      outif_almost_full : in  std_logic
      );
end entity jpeg_enc_ce;

architecture struct of jpeg_enc_ce is

   signal clk_gated              : std_logic;
   signal image_size_x_int       : std_logic_vector(15 downto 0);
   signal image_size_y_int       : std_logic_vector(15 downto 0);
   signal image_size_x_nopad_int : std_logic_vector(15 downto 0);
   signal image_size_y_nopad_int : std_logic_vector(15 downto 0);
   signal image_start_int        : std_logic;
   signal enc_ready_int          : std_logic;
   signal enc_size_int           : std_logic_vector(23 downto 0);
   signal iram_wdata_int         : std_logic_vector(23 downto 0);
   signal iram_wren_int          : std_logic;
   signal iram_fifo_afull_int    : std_logic;
   signal ram_byte_int           : std_logic_vector(7 downto 0);
   signal ram_wren_int           : std_logic;
   signal ram_wraddr_int         : std_logic_vector(23 downto 0);
   signal outif_almost_full_int  : std_logic;

begin

   -------------------------------------------------------------------
   -- BUFHCE for Xilinx 7 series: there is a timing arc defined for
   -- the CE pin, enabling this application. Xilinx UG472 states:
   -- "The clock enable feature can provide a gated clock on a clock
   -- cycle-to-cycle basis."
   -------------------------------------------------------------------
   gated_clk_buffer : BUFHCE port map (I => clk, CE => ce, O => clk_gated);

   -------------------------------------------------------------------
   -- Because of the delta delay introduced by the clock buffer we
   -- may have a HW-simulation mismatch. Introduce a transport delay 
   -- on the data path to fix this. Synthesis ignores this.
   -------------------------------------------------------------------
   -- Inputs
   image_size_x_int       <= transport image_size_x        after 1 ps;
   image_size_y_int       <= transport image_size_y        after 1 ps;
   image_size_x_nopad_int <= transport image_size_x_nopad  after 1 ps;
   image_size_y_nopad_int <= transport image_size_y_nopad  after 1 ps;
   image_start_int        <= transport image_start         after 1 ps;
   iram_wdata_int         <= transport iram_wdata          after 1 ps;
   iram_wren_int          <= transport iram_wren           after 1 ps;
   outif_almost_full_int  <= transport outif_almost_full   after 1 ps;
   -- Outputs (not really necessary to delay these)
   enc_ready              <= transport enc_ready_int       after 1 ps;
   enc_size               <= transport enc_size_int        after 1 ps;
   iram_fifo_afull        <= transport iram_fifo_afull_int after 1 ps;
   ram_byte               <= transport ram_byte_int        after 1 ps;
   ram_wren               <= transport ram_wren_int        after 1 ps;
   ram_wraddr             <= transport ram_wraddr_int      after 1 ps;

   -- Actual Encoder
   jpeg_enc : entity work.JpegEnc
      port map (
         CLK                => clk_gated,               -- in std_logic;
         RST                => rst,                     -- in std_logic;
         -- Control
         image_size_x       => image_size_x_int,        -- in std_logic_vector(15 downto 0);
         image_size_y       => image_size_y_int,        -- in std_logic_vector(15 downto 0);
         image_size_x_nopad => image_size_x_nopad_int,  -- in std_logic_vector(15 downto 0);
         image_size_y_nopad => image_size_y_nopad_int,  -- in std_logic_vector(15 downto 0);
         image_start        => image_start_int,         -- in std_logic;
         -- Status
         enc_ready          => enc_ready_int,           -- out std_logic;
         enc_size           => enc_size_int,            -- out std_logic_vector(23 downto 0);
         -- IMAGE RAM
         iram_wdata         => iram_wdata_int,          -- in  std_logic_vector(C_PIXEL_BITS-1 downto 0);
         iram_wren          => iram_wren_int,           -- in  std_logic;
         iram_fifo_afull    => iram_fifo_afull_int,     -- out std_logic;
         -- OUT RAM
         ram_byte           => ram_byte_int,            -- out std_logic_vector(7 downto 0);
         ram_wren           => ram_wren_int,            -- out std_logic;
         ram_wraddr         => ram_wraddr_int,          -- out std_logic_vector(23 downto 0);
         outif_almost_full  => outif_almost_full_int    -- in  std_logic
         );

end struct;
