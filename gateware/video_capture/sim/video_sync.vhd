library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg_general.all;

entity video_sync is
   generic (
      h_sync_active_high : boolean  := true;
      v_sync_active_high : boolean  := true;
      ver_addr_px        : positive := 1024;
      ver_front_porch_px : positive := 1;
      ver_sync_px        : positive := 3;
      ver_back_porch_px  : positive := 44;
      hor_addr_px        : positive := 1280;
      hor_front_porch_px : positive := 64;
      hor_sync_px        : positive := 160;
      hor_back_porch_px  : positive := 224
      );
   port (
      reset       : in  std_logic;
      clk         : in  std_logic;
      px_addr_v   : out std_logic_vector(log2(ver_addr_px)-1 downto 0);
      px_addr_h   : out std_logic_vector(log2(hor_addr_px)-1 downto 0);
      px_en       : out std_logic;
      h_sync      : out std_logic;
      v_sync      : out std_logic
      );
end entity video_sync;

architecture rtl of video_sync is

   constant ver_total_px : positive := ver_addr_px + ver_front_porch_px + ver_sync_px + ver_back_porch_px;
   constant hor_total_px : positive := hor_addr_px + hor_front_porch_px + hor_sync_px + hor_back_porch_px;

   signal hor_count       : std_logic_vector(log2(hor_total_px)-1 downto 0);
   signal ver_count       : std_logic_vector(log2(ver_total_px)-1 downto 0);
   signal hor_count_reset : std_logic;
   signal ver_count_reset : std_logic;
   signal raise_h_sync    : std_logic;
   signal lower_h_sync    : std_logic;
   signal raise_v_sync    : std_logic;
   signal lower_v_sync    : std_logic;
   signal lower_px_en_h   : std_logic;
   signal lower_px_en_v   : std_logic;
   signal px_en_h         : std_logic;
   signal px_en_v         : std_logic;


begin

   sync_counters : process (clk, reset)
   begin
      if rising_edge(clk) then

         -- lookahead comparators to improve timing
         hor_count_reset <= conv_sl(unsigned(hor_count) = hor_total_px - 2);
         ver_count_reset <= conv_sl(unsigned(ver_count) = ver_total_px - 1);
         lower_px_en_h   <= conv_sl(unsigned(hor_count) = hor_addr_px - 2);
         lower_px_en_v   <= conv_sl(unsigned(ver_count) = ver_addr_px - 1);
         raise_h_sync    <= conv_sl(unsigned(hor_count) = hor_addr_px + hor_front_porch_px - 2);
         lower_h_sync    <= conv_sl(unsigned(hor_count) = hor_addr_px + hor_front_porch_px + hor_sync_px - 2);
         raise_v_sync    <= conv_sl(unsigned(ver_count) = ver_addr_px + ver_front_porch_px - 1);
         lower_v_sync    <= conv_sl(unsigned(ver_count) = ver_addr_px + ver_front_porch_px + ver_sync_px - 1);

         -- addressable pixel enable
         if hor_count_reset = '1' then
            px_en_h <= '1';
            if ver_count_reset = '1' then
               px_en_v <= '1';
            elsif lower_px_en_v = '1' then
               px_en_v <= '0';
            end if;
         elsif lower_px_en_h = '1' then
            px_en_h <= '0';
         end if;

         -- nested counters
         if hor_count_reset = '1' then
            hor_count <= (others => '0');
            if ver_count_reset = '1' then
               ver_count <= (others => '0');
            else
               ver_count <= std_logic_vector(unsigned(ver_count) + 1);
            end if;
         else
            hor_count <= std_logic_vector(unsigned(hor_count) + 1);
         end if;

         -- drive sync signals
         if raise_h_sync = '1' then
            if raise_v_sync = '1' then
               v_sync <= conv_sl(v_sync_active_high);
            elsif lower_v_sync = '1' then
               v_sync <= not conv_sl(v_sync_active_high);
            end if;
            h_sync <= conv_sl(h_sync_active_high);
         elsif lower_h_sync = '1' then
            h_sync <= not conv_sl(h_sync_active_high);
         end if;

      end if;

      if reset = '1' then
         hor_count <= (others => '0');
         ver_count <= (others => '0');
         h_sync    <= not conv_sl(h_sync_active_high);
         v_sync    <= not conv_sl(v_sync_active_high);
         px_en_v   <= '0';
         px_en_h   <= '0';
      end if;

   end process sync_counters;

   px_addr_v <= ver_count(px_addr_v'range);
   px_addr_h <= hor_count(px_addr_h'range);
   px_en     <= px_en_h and px_en_v;

end architecture rtl;
