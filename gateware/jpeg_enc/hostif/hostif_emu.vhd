-------------------------------------------------------------------------------
-- File Name : HostIF_emu.vhd
--
-- Project   : JPEG_ENC
--
-- Module    : HostIF
--
-- Content   : Host Interface Emulator
--
-- Description : 
--
-- Spec.     : 
--
-- Author    : Michal Krepa
--
-------------------------------------------------------------------------------
-- History :
-- 20090301: (MK): Initial Creation.
-------------------------------------------------------------------------------
-- 20190301: (ssincan): Based on hostif.vhd.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity HostIF_emu is
  port (
    CLK : in std_logic;
    RST : in std_logic;

    -- Control
    image_size_x       : in std_logic_vector(15 downto 0);
    image_size_y       : in std_logic_vector(15 downto 0);
    image_size_x_nopad : in std_logic_vector(15 downto 0);
    image_size_y_nopad : in std_logic_vector(15 downto 0);
    image_start        : in std_logic;

    -- Status
    enc_ready : out std_logic;
    enc_size  : out std_logic_vector(23 downto 0);

    -- Quantizer RAM
    qdata : out std_logic_vector(7 downto 0);
    qaddr : out std_logic_vector(6 downto 0);
    qwren : out std_logic;

    -- CTRL
    jpeg_ready : in std_logic;
    jpeg_busy  : in std_logic;

    -- ByteStuffer
    outram_base_addr : out std_logic_vector(9 downto 0);
    num_enc_bytes    : in  std_logic_vector(23 downto 0);

    -- others
    img_size_x    : out std_logic_vector(15 downto 0);
    img_size_y    : out std_logic_vector(15 downto 0);
    img_size_jfif : out std_logic_vector(31 downto 0);
    img_size_wr   : out std_logic;
    sof           : out std_logic;

    RST_out : out std_logic

    );
end entity HostIF_emu;

architecture RTL of HostIF_emu is


  type ROMQ_TYPE is array (0 to 128-1) of unsigned(7 downto 0);

  constant qrom_lum_chr : ROMQ_TYPE := (
    -- Luminance 85%
    X"05", X"03", X"04", X"04",
    X"04", X"03", X"05", X"04",
    X"04", X"04", X"05", X"05",
    X"05", X"06", X"07", X"0C",
    X"08", X"07", X"07", X"07",
    X"07", X"0F", X"0B", X"0B",
    X"09", X"0C", X"11", X"0F",
    X"12", X"12", X"11", X"0F",
    X"11", X"11", X"13", X"16",
    X"1C", X"17", X"13", X"14",
    X"1A", X"15", X"11", X"11",
    X"18", X"21", X"18", X"1A",
    X"1D", X"1D", X"1F", X"1F",
    X"1F", X"13", X"17", X"22",
    X"24", X"22", X"1E", X"24",
    X"1C", X"1E", X"1F", X"1E",
    -- Chrominance 50%
    X"11", X"12", X"12", X"18", X"15", X"18", X"2F", X"1A",
    X"1A", X"2F", X"63", X"42", X"38", X"42", X"63", X"63",
    X"63", X"63", X"63", X"63", X"63", X"63", X"63", X"63",
    X"63", X"63", X"63", X"63", X"63", X"63", X"63", X"63",
    X"63", X"63", X"63", X"63", X"63", X"63", X"63", X"63",
    X"63", X"63", X"63", X"63", X"63", X"63", X"63", X"63",
    X"63", X"63", X"63", X"63", X"63", X"63", X"63", X"63",
    X"63", X"63", X"63", X"63", X"63", X"63", X"63", X"63"
    );

  type state_type is (post_reset, qmem_init, idle, wr_img_size, wait_busy, wait_ready, rst_downstream);

  signal state              : state_type := post_reset;
  signal post_reset_holdoff : unsigned(5 downto 0);
  signal wr_start           : std_logic;
  signal wr_done            : std_logic;
  signal wr_skip            : std_logic;
  signal addr_cnt           : unsigned(qaddr'range);
  signal qdata_int          : std_logic_vector(qdata'range);
  signal qaddr_int          : std_logic_vector(qaddr'range);
  signal qwren_int          : std_logic;

begin

  outram_base_addr <= (others => '0');

  fsm : process (CLK, RST)
  begin
    if rising_edge(CLK) then
      RST_out     <= RST;
      sof         <= '0';
      wr_start    <= '0';
      img_size_wr <= '0';
      case state is
        when post_reset =>
          if post_reset_holdoff(post_reset_holdoff'high) = '1' then
            if wr_skip = '0' then
              state    <= qmem_init;
              wr_start <= '1';
            else
              state <= idle;
            end if;
          else
            post_reset_holdoff <= post_reset_holdoff + 1;
          end if;
        when qmem_init =>
          if (wr_start = '0') and (wr_done = '1') then
            state   <= idle;
            wr_skip <= '1';
          end if;
        when idle =>
          enc_ready <= '1';
          if image_start = '1' then
            img_size_x    <= image_size_x;
            img_size_y    <= image_size_y;
            img_size_jfif <= image_size_x_nopad & image_size_y_nopad;
            enc_ready     <= '0';
            sof           <= '1';
            state         <= wr_img_size;
          end if;
        when wr_img_size =>
          img_size_wr <= '1';
          state       <= wait_busy;
        when wait_busy =>
          if jpeg_busy = '1' then
            state <= wait_ready;
          end if;
        when wait_ready =>
          if jpeg_ready = '1' then
            state    <= rst_downstream;
            enc_size <= num_enc_bytes;
          end if;
        when rst_downstream =>
          RST_out <= '1';
          state   <= post_reset;
      end case;
    end if;
    if RST = '1' then
      enc_ready          <= '0';
      post_reset_holdoff <= (others => '0');
      state              <= post_reset;
      wr_skip            <= '0';
    end if;
  end process fsm;

  memwr : process (CLK, RST)
  begin
    if rising_edge(CLK) then
      qdata     <= qdata_int;
      qaddr     <= qaddr_int;
      qwren     <= qwren_int;
      qwren_int <= '0';
      if wr_done = '0' then
        addr_cnt  <= addr_cnt + 1;
        qdata_int <= std_logic_vector(qrom_lum_chr(to_integer(addr_cnt)));
        qaddr_int <= std_logic_vector(addr_cnt);
        qwren_int <= '1';
        if addr_cnt = qrom_lum_chr'high then
          wr_done <= '1';
        end if;
      end if;
      if wr_start = '1' then
        wr_done  <= '0';
        addr_cnt <= (others => '0');
      end if;
    end if;
    if RST = '1' then
      wr_done <= '1';
    end if;
  end process memwr;

end architecture RTL;