library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg_general.all;

entity image_stripe is
   generic (
      num_chan : integer := 4
      );
   port (
      clk              : in  std_logic;
      rst              : in  std_logic;
      res_x_in         : in  std_logic_vector(15 downto 0);
      res_y_in         : in  std_logic_vector(15 downto 0);
      img_start_in     : in  std_logic;
      px_data_in       : in  std_logic_vector(23 downto 0);
      px_dval_in       : in  std_logic;  -- assumed to be continually high for each line
      res_x_out        : out slv16d_array(num_chan-1 downto 0);
      res_y_out        : out std_logic_vector(15 downto 0);
      res_x_nopad_out  : out slv16d_array(num_chan-1 downto 0);
      res_y_nopad_out  : out std_logic_vector(15 downto 0);
      img_start_out    : out std_logic;
      px_data_out      : out std_logic_vector(23 downto 0);
      px_dval_out      : out std_logic_vector(num_chan-1 downto 0);
      px_dval_1st_out  : out std_logic_vector(num_chan-1 downto 0);
      px_dval_last_out : out std_logic_vector(num_chan-1 downto 0);
      fault_bad_res    : out std_logic
      );
end image_stripe;

architecture rtl of image_stripe is

   constant chan_bits : integer := log2(num_chan);

   type u16_array is array (natural range <>) of unsigned(15 downto 0);

   function res_pad (
      num_px : unsigned;
      step   : integer
      ) return unsigned is
      constant step_bits : integer := log2(step);
      variable result    : unsigned(num_px'length-1 downto 0);
   begin
      assert step = 2**step_bits report "Step must be a power of 2!" severity failure;
      result := num_px;
      if result(step_bits-1 downto 0) /= 0 then
         result := shift_left(shift_right(result, step_bits) + 1, step_bits);
      end if;
      return result;
   end function res_pad;

   signal img_start_p1   : std_logic;
   signal px_dval_in_p1  : std_logic;
   signal res_x_nopad_ch : u16_array(num_chan-1 downto 0);
   signal res_y_nopad_ch : unsigned(res_y_in'range);
   signal res_x_ch       : u16_array(num_chan-1 downto 0);
   signal res_y_ch       : unsigned(res_y_in'range);
   signal res_y_ch_m1    : unsigned(res_y_in'range);
   signal line_cnt       : unsigned(res_y_in'range);
   signal cnt_en         : std_logic;
   signal px_cnt         : unsigned(res_x_in'range);
   signal start_cnt      : u16_array(num_chan-1 downto 0);
   signal end_cnt        : u16_array(num_chan-1 downto 0);
   signal expect_1st_px  : std_logic_vector(num_chan-1 downto 0);
   signal start_pulse    : std_logic_vector(num_chan-1 downto 0);
   signal end_pulse_m1   : std_logic_vector(num_chan-1 downto 0);
   signal end_pulse      : std_logic_vector(num_chan-1 downto 0);
   signal last_line      : std_logic;

begin

   assert num_chan = 2**chan_bits report "num_chan must be a power of 2" severity failure;

   data_dly : entity work.sreg_inferred
      generic map (
         sreg_width => px_data_out'length,  -- positive       := 18;                         -- shift register width
         sreg_depth => 4                    -- positive       := 1                           -- shift register depth
         )
      port map (
         rst => rst,                        -- in  std_logic := '0';                         -- asynchronous reset
         clk => clk,                        -- in  std_logic;                                -- clock
         en  => '1',                        -- in  std_logic := '1';                         -- clock enable
         d   => px_data_in,                 -- in  std_logic_vector(sreg_width-1 downto 0);  -- data in
         q   => px_data_out                 -- out std_logic_vector(sreg_width-1 downto 0)   -- data out
         );

   gen_conv : for i in res_x_out'range generate
      res_x_out(i)       <= std_logic_vector(res_x_ch(i));
      res_x_nopad_out(i) <= std_logic_vector(res_x_nopad_ch(i));
   end generate gen_conv;

   res_y_out       <= std_logic_vector(res_y_ch);
   res_y_nopad_out <= std_logic_vector(res_y_nopad_ch);

   process (clk)
   begin
      if rising_edge(clk) then
         img_start_out    <= '0';
         img_start_p1     <= img_start_in;
         px_dval_in_p1    <= px_dval_in;
         px_dval_1st_out  <= (others => '0');
         px_dval_last_out <= (others => '0');
         start_pulse      <= (others => '0');
         end_pulse_m1     <= (others => '0');
         end_pulse        <= end_pulse_m1;
         res_y_ch_m1      <= res_y_ch - 1;
         last_line        <= '0';
         if line_cnt = res_y_ch_m1 then
            last_line <= '1';
         end if;
         if img_start_in = '1' then
            for i in res_x_ch'range loop
               if i /= num_chan-1 then
                  res_x_nopad_ch(i) <= shift_right(unsigned(res_x_in), chan_bits);
               else
                  res_x_nopad_ch(i) <= shift_right(unsigned(res_x_in), chan_bits) + unsigned(res_x_in(chan_bits-1 downto 0));
               end if;
            end loop;
            res_y_nopad_ch <= unsigned(res_y_in);
         end if;
         if img_start_p1 = '1' then
            line_cnt      <= (others => '0');
            expect_1st_px <= (others => '1');
            for i in res_x_nopad_ch'range loop
               res_x_ch(i) <= res_pad(res_x_nopad_ch(i), 16);
            end loop;
            res_y_ch      <= res_y_nopad_ch;
            img_start_out <= '1';
            if unsigned(res_y_nopad_ch(2 downto 0)) /= 0 then
               fault_bad_res <= '1';
               img_start_out <= '0';
               assert false report "Vertical resolution must be a multiple of 8!" severity failure;  -- If you are here because you want to fix this, you need to generate extra lines.
            end if;
         end if;
         for i in start_cnt'range loop
            if i = 0 then
               start_cnt(i) <= to_unsigned(0, start_cnt(0)'length);
            else
               start_cnt(i) <= start_cnt(i-1) + res_x_nopad_ch(i-1);
            end if;
            end_cnt(i) <= start_cnt(i) + res_x_ch(i) - 1;
            if px_cnt = start_cnt(i) then
               start_pulse(i) <= '1';
            end if;
            if px_cnt = end_cnt(i) then
               end_pulse_m1(i) <= '1';
            end if;
            if start_pulse(i) = '1' and cnt_en = '1' then
               px_dval_out(i) <= '1';
               if expect_1st_px(i) = '1' then
                  px_dval_1st_out(i) <= '1';
                  expect_1st_px(i)   <= '0';
               end if;
            end if;
            if end_pulse_m1(i) = '1' and last_line = '1' then
               px_dval_last_out(i) <= '1';
            end if;
            if end_pulse(i) = '1' or cnt_en = '0' then
               px_dval_out(i) <= '0';
            end if;
         end loop;
         if px_dval_in = '1' and px_dval_in_p1 = '0' then
            cnt_en <= '1';
         end if;
         if end_pulse(end_pulse'high) = '1' then
            cnt_en <= '0';
            if last_line = '1' then
               line_cnt <= (others => '-');
            else
               line_cnt <= line_cnt + 1;
            end if;
         end if;
         if cnt_en = '1' then
            px_cnt <= px_cnt + 1;
         else
            px_cnt <= (others => '1');
         end if;
         if rst = '1' then
            fault_bad_res <= '0';
            cnt_en        <= '0';
         end if;
      end if;
   end process;

end rtl;