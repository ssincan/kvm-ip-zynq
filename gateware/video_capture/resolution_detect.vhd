library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity resolution_detect is
   port (
      clk        : in  std_logic;
      rst        : in  std_logic;
      vid_dval   : in  std_logic;
      vid_hsync  : in  std_logic;
      vid_vsync  : in  std_logic;
      res_stable : out std_logic;
      res_x      : out std_logic_vector(15 downto 0);
      res_y      : out std_logic_vector(15 downto 0)
      );
end resolution_detect;

architecture rtl of resolution_detect is

   constant stable_cnt_max : integer := 2;

   signal vid_dval_p      : std_logic;
   signal vid_vsync_p     : std_logic;
   signal active_line_cnt : unsigned(res_y'range);
   signal active_lines    : unsigned(res_y'range);
   signal active_col_cnt  : unsigned(res_x'range);
   signal active_columns  : unsigned(res_x'range);
   signal col_cnt_stable  : std_logic;
   signal line_stable_cnt : integer range 0 to stable_cnt_max;
   signal line_cnt_stable : std_logic;

begin

   process (clk, rst)
   begin
      if rising_edge(clk) then

         vid_dval_p <= vid_dval;
         vid_vsync_p <= vid_vsync;

         if vid_dval_p = '0' and vid_dval = '1' then
            -- start of line
            active_line_cnt <= active_line_cnt + 1;
            active_col_cnt  <= to_unsigned(1, active_col_cnt'length);
         elsif vid_dval = '1' then
            active_col_cnt <= active_col_cnt + 1;
         elsif vid_dval_p = '1' and vid_dval = '0' then
            -- after end of line
            if active_col_cnt /= active_columns then
               col_cnt_stable  <= '0';
               line_cnt_stable <= '0';
               line_stable_cnt <= 0;
            end if;
            active_columns <= active_col_cnt;
         end if;

         -- start of frame
         if vid_vsync = '0' and vid_vsync_p = '1' then
            -- last frame line count is consistent with current value?
            if (col_cnt_stable = '1') and (active_line_cnt = active_lines) then
               if line_stable_cnt < stable_cnt_max then
                  line_stable_cnt <= line_stable_cnt + 1;
                  line_cnt_stable <= '0';
               else
                  line_cnt_stable <= '1';
               end if;
            else
               line_cnt_stable <= '0';
               line_stable_cnt <= 0;
            end if;
            active_lines    <= active_line_cnt;
            active_line_cnt <= (others => '0');
            col_cnt_stable  <= '1';
         end if;

      end if;
      if rst = '1' then
         line_stable_cnt <= 0;
         line_cnt_stable <= '0';
         col_cnt_stable  <= '0';
      end if;
   end process;

   res_stable <= line_cnt_stable;
   res_x      <= std_logic_vector(active_columns);
   res_y      <= std_logic_vector(active_lines);

end rtl;