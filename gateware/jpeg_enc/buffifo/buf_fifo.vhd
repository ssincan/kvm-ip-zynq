-------------------------------------------------------------------------------
-- File Name : BUF_FIFO.vhd
--
-- Project   : JPEG_ENC
--
-- Module    : BUF_FIFO
--
-- Content   : Input FIFO Buffer
--
-- Description : 
--
-- Spec.     : 
--
-- Author    : Michal Krepa
--
-------------------------------------------------------------------------------
-- History :
-- 20090311: (MK): Initial Creation.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
----------------------------------- LIBRARY/PACKAGE ---------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- generic packages/libraries:
-------------------------------------------------------------------------------
library ieee;
  use IEEE.STD_LOGIC_1164.all;
  use ieee.numeric_std.all;

-------------------------------------------------------------------------------
-- user packages/libraries:
-------------------------------------------------------------------------------
library work;
  use work.JPEG_PKG.all;
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
----------------------------------- ENTITY ------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
entity BUF_FIFO is
  port 
  (
        CLK                : in  std_logic;
        RST                : in  std_logic;
        -- HOST PROG
        img_size_x         : in  std_logic_vector(15 downto 0);
        img_size_y         : in  std_logic_vector(15 downto 0);
        sof                : in  std_logic;
        
        -- HOST DATA
        iram_wren          : in  std_logic;
        iram_wdata         : in  std_logic_vector(C_PIXEL_BITS-1 downto 0);
        fifo_almost_full   : out std_logic;
        
        -- FDCT
        fdct_fifo_rd       : in  std_logic;
        fdct_fifo_q        : out std_logic_vector(23 downto 0);
        fdct_fifo_hf_full  : out std_logic
    );
end entity BUF_FIFO;

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
----------------------------------- ARCHITECTURE ------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
architecture RTL of BUF_FIFO is

  
  --constant C_NUM_LINES    : integer := 8 + C_EXTRA_LINES;
  -- No Exstra Lines
  constant C_NUM_LINES : integer := 8;

  signal pixel_cnt : unsigned(15 downto 0);
  signal line_cnt  : unsigned(15 downto 0);

  --signal ramq             : STD_LOGIC_VECTOR(C_PIXEL_BITS-1 downto 0);
  signal q        : std_logic_vector(C_PIXEL_BITS-1 downto 0);
  --signal ramd             : STD_LOGIC_VECTOR(C_PIXEL_BITS-1 downto 0);
  signal ram_data : std_logic_vector(C_PIXEL_BITS-1 downto 0);

  signal wr_ptr    : unsigned(log2(C_MAX_LINE_WIDTH*C_NUM_LINES)-1 downto 0);
  signal ram_write : std_logic;
  signal rd_ptr    : unsigned(log2(C_MAX_LINE_WIDTH*C_NUM_LINES)-1 downto 0);

  signal wr_addr : unsigned(log2(C_MAX_LINE_WIDTH)-1 downto 0);
  signal we      : std_logic;
  signal rd_addr : unsigned(log2(C_MAX_LINE_WIDTH)-1 downto 0);

  signal data_out : std_logic_vector(15 downto 0);
  --signal ramd             : STD_LOGIC_VECTOR(C_PIXEL_BITS-1 downto 0);
  signal data_in  : unsigned(15 downto 0);


  signal wr_addr2 : unsigned(log2(C_MAX_LINE_WIDTH)-1 downto 0);
  signal we2      : std_logic;
  signal rd_addr2 : unsigned(log2(C_MAX_LINE_WIDTH)-1 downto 0);

  signal data_out2 : std_logic_vector(15 downto 0);
  --signal ramd             : STD_LOGIC_VECTOR(C_PIXEL_BITS-1 downto 0);
  signal data_in2  : unsigned(15 downto 0);

  signal pix_inblk_cnt    : unsigned(3 downto 0);
  signal pix_inblk_cnt_d1 : unsigned(3 downto 0);
  signal line_inblk_cnt   : unsigned(2 downto 0);

  signal read_block_cnt    : unsigned(12 downto 0);
  signal read_block_cnt_d1 : unsigned(12 downto 0);
  signal write_block_cnt   : unsigned(12 downto 0);

  signal ramraddr_int    : unsigned(16+log2(C_NUM_LINES)-1 downto 0);
  signal raddr_base_line : unsigned(16+log2(C_NUM_LINES)-1 downto 0);
  signal raddr_tmp       : unsigned(15 downto 0);
  --signal ramwaddr_d1      : unsigned(ramwaddr'range);

  signal line_lock : unsigned(log2(C_NUM_LINES)-1 downto 0);

  signal memwr_line_cnt : unsigned(log2(C_NUM_LINES)-1 downto 0);

  signal memrd_offs_cnt : unsigned(log2(C_NUM_LINES)-1+1 downto 0);
  signal memrd_line     : unsigned(log2(C_NUM_LINES)-1 downto 0);

  signal wr_line_idx : unsigned(15 downto 0);
  signal rd_line_idx : unsigned(15 downto 0);

  signal image_write_end : std_logic;

  signal result_pre                    : std_logic_vector(31 downto 0);
  signal result                        : std_logic_vector(31 downto 0);
  signal result_m2                     : std_logic_vector(31 downto 0);
  signal threshold                     : std_logic_vector(31 downto 0);
  signal wr_counter_total_eq_result_m1 : std_logic;
  signal rd_counter_total_eq_result_m1 : std_logic;

  signal wr_counter           : unsigned(15 downto 0);
  signal rd_counter           : unsigned(15 downto 0);
  signal wr_rd_counter_max    : unsigned(15 downto 0);
  signal wr_rd_counter_max_m4 : unsigned(15 downto 0);
  signal wr_rd_counter_max_m2 : unsigned(15 downto 0);

  signal wr_mod         : unsigned(15 downto 0);
  signal wr_mod_eq_zero : std_logic;
  signal rd_mod         : unsigned(15 downto 0);

  signal wr_counter_total                       : unsigned(31 downto 0);
  signal rd_counter_total                       : unsigned(31 downto 0);
  signal rd_counter_total_plus_img_size_x_t8_m2 : unsigned(31 downto 0);
  signal rd_counter_total_plus_threshold        : unsigned(31 downto 0);
  signal counter                                : unsigned(31 downto 0);
  signal counter2                               : unsigned(31 downto 0);

  signal init_table_wr : std_logic;
  signal init_table_rd : std_logic;

  signal do1        : unsigned(15 downto 0);
  signal do2        : unsigned(15 downto 0);
  signal data_temp  : unsigned(15 downto 0);
  signal data_temp2 : unsigned(15 downto 0);

  signal temp : std_logic_vector(23 downto 0);

  signal fifo_almost_full_i : std_logic;

  type img_size_x_mult_v is array (natural range <>) of unsigned(2+img_size_x'length-1 downto 0);
  signal img_size_x_mult  : img_size_x_mult_v(0 to 7);
  signal img_size_y_d8_m1 : unsigned(img_size_y'range);
  signal img_size_x_t8_m2 : unsigned(img_size_x'length-1+3 downto 0);
  signal sof_p1           : std_logic;
  
-------------------------------------------------------------------------------
-- Architecture: begin
-------------------------------------------------------------------------------
begin  
  -------------------------------------------------------------------
  -- RAM for SUB_FIFOs
  -------------------------------------------------------------------
  fifo_almost_full <= fifo_almost_full_i;
  
  U_SUB_RAMZ : entity work.SUB_RAMZ
  generic map 
  (
           RAMADDR_W => log2( C_MAX_LINE_WIDTH*C_NUM_LINES ),
           RAMDATA_W => C_PIXEL_BITS        
  )   
  port map 
  (      
        d            => ram_data,               
        waddr        => std_logic_vector(wr_ptr),     
        raddr        => std_logic_vector(rd_ptr),     
        we           => ram_write,     
        clk          => clk,     
        
        q            => q     
  ); 
  
  MULTIPLIER : entity work.multiplier
    port map(
      CLK        => CLK,
      RST        => '0',
      img_size_x => img_size_x,
      img_size_y => img_size_y,
      result     => result_pre
      );
  
  U_SUB_RAMZ_WR_ADRESS_LUT : entity work.SUB_RAMZ_LUT
  generic map 
  (
           RAMADDR_W => log2( C_MAX_LINE_WIDTH ),
           RAMDATA_W => 16        
  )   
  port map 
  (      
        d            => std_logic_vector(data_in),               
        waddr        => std_logic_vector(wr_addr),     
        raddr        => std_logic_vector(rd_addr),     
        we           => we,     
        clk          => CLK,     
        
        q            => data_out
  ); 
  
  U_SUB_RAMZ_RD_ADRESS_LUT : entity work.SUB_RAMZ_LUT
  generic map 
  (
           RAMADDR_W => log2( C_MAX_LINE_WIDTH ),
           RAMDATA_W => 16        
  )   
  port map 
  (      
        d            => std_logic_vector(data_in2),               
        waddr        => std_logic_vector(wr_addr2),     
        raddr        => std_logic_vector(rd_addr2),     
        we           => we2,     
        clk          => CLK,     
        
        q            => data_out2
  ); 

  process (CLK, RST)
  begin
    if rising_edge(CLK) then
      result               <= result_pre;
      result_m2            <= std_logic_vector(unsigned(result) - 2);
      wr_rd_counter_max    <= shift_left(unsigned(img_size_x), 3) - 1;
      wr_rd_counter_max_m4 <= shift_left(unsigned(img_size_x), 3) - 1 - 4;
      wr_rd_counter_max_m2 <= shift_left(unsigned(img_size_x), 3) - 1 - 2;
      img_size_y_d8_m1     <= unsigned(img_size_y) / 8 - 1;
      img_size_x_t8_m2     <= shift_left(resize(unsigned(img_size_x), img_size_x_t8_m2'length), 3)-2;
    end if;
    if (RST = '1') then
      result <= (others => '0');
    end if;
  end process;

  gen_mult : for i in 0 to img_size_x_mult'length-1 generate
    constant i_u : unsigned(2 downto 0) := to_unsigned(i, 3);
  begin
    process(clk)
      variable temp : unsigned(img_size_x_mult(0)'range);
    begin
      if rising_edge(clk) then
        temp := (others => '0');
        for j in i_u'range loop
          if i_u(j) = '1' then
            temp := temp + shift_left(resize(unsigned(img_size_x), temp'length), j);
          end if;
        end loop;
        img_size_x_mult(i) <= temp;
      end if;
    end process;
  end generate gen_mult;

  threshold <= std_logic_vector(resize(img_size_x_mult(7), threshold'length));
    
  process (CLK, RST)
  begin
    if (CLK'event and CLK = '1') then
      if (init_table_wr = '0') then
        if (iram_wren = '1') then
          if ((wr_mod_eq_zero = '0') and wr_counter mod 8 = "000") then
            wr_ptr    <= resize(img_size_x_mult(to_integer(do1(5 downto 3))), log2(C_MAX_LINE_WIDTH*C_NUM_LINES)) + resize(do1(15 downto 6) * 8, log2(C_MAX_LINE_WIDTH*C_NUM_LINES));
            data_temp <= resize(img_size_x_mult(to_integer(do1(5 downto 3))), 16) + resize(do1(15 downto 6) * 8, 16);

          --wr_ptr <= do1 / 8 mod 8 *  unsigned(img_size_x) + do1 / 8 / 8 * 8;
          --data_temp <= do1 / 8 mod 8 *  unsigned(img_size_x) + do1 / 8 / 8 * 8;
          else
            if (wr_counter = 0) then
              wr_ptr <= (others => '0');
            else
              wr_ptr <= wr_ptr + 1;
            end if;
          end if;

          if ((wr_mod_eq_zero = '0') and wr_counter mod 8 = "011") then
            if (wr_counter = wr_rd_counter_max_m4) then
              rd_addr <= (others => '0');
            else
              rd_addr <= resize((wr_counter/8)+1, log2(C_MAX_LINE_WIDTH));
            end if;
          end if;

          if (wr_mod /= 0 and wr_counter mod 8 = "101") then
            do1 <= unsigned(data_out);
            we  <= '1';

            if (wr_mod = img_size_y_d8_m1) then
              wr_addr <= resize(counter, log2(C_MAX_LINE_WIDTH));
              data_in <= resize(counter * 8, 16);
              counter <= counter + 1;
            else
              data_in <= data_temp;
              if (wr_counter = wr_rd_counter_max_m2) then
                wr_addr <= (others => '0');
              else
                wr_addr <= resize(wr_counter/8, log2(C_MAX_LINE_WIDTH));
              end if;
            end if;
          else
            we <= '0';
          end if;

          ram_write <= '1';
          ram_data  <= iram_wdata;

          wr_counter_total <= wr_counter_total + 1;
          if (wr_counter_total = unsigned(result_m2)) then
            wr_counter_total_eq_result_m1 <= '1';
          else
            wr_counter_total_eq_result_m1 <= '0';
          end if;

          if (wr_counter_total_eq_result_m1 = '1') then

            init_table_wr <= '1';
            counter       <= (others => '0');
          end if;

          if (wr_counter = wr_rd_counter_max) then
            wr_counter     <= (others => '0');
            wr_mod         <= wr_mod + 1;
            wr_mod_eq_zero <= '0';
          else
            wr_counter <= wr_counter + 1;
          end if;
        else
          ram_write <= '0';
        end if;

        if sof = '1' then
          wr_counter                    <= (others => '0');
          wr_counter_total              <= (others => '0');
          wr_counter_total_eq_result_m1 <= '0';
          wr_mod                        <= (others => '0');
          wr_mod_eq_zero                <= '1';
          wr_ptr                        <= (others => '0');

          ram_write     <= '0';
          init_table_wr <= '0';
          do1           <= (others => '0');
          wr_addr       <= (others => '0');
          rd_addr       <= (others => '0');
          we            <= '0';
          counter       <= (others => '0');
        end if;

      end if;
    end if;
    if (RST = '1') then
      wr_counter                    <= (others => '0');
      wr_counter_total              <= (others => '0');
      wr_counter_total_eq_result_m1 <= '0';
      wr_mod                        <= (others => '0');
      wr_mod_eq_zero                <= '1';

      ram_write     <= '0';
      init_table_wr <= '0';
      do1           <= (others => '0');
      data_temp     <= (others => '0');
      wr_addr       <= (others => '0');
      rd_addr       <= (others => '0');
      we            <= '0';
      counter       <= (others => '0');
    end if;
  end process;

  process (CLK, RST)
  begin
    if (RST = '1') then
      fifo_almost_full_i <= '0';
      fdct_fifo_hf_full  <= '0';
    elsif (CLK'event and CLK = '1') then
      if (fifo_almost_full_i = '0' and wr_counter_total = rd_counter_total_plus_img_size_x_t8_m2) then

        fifo_almost_full_i <= '1';

      end if;

      if (fifo_almost_full_i = '1' and wr_counter_total < rd_counter_total_plus_threshold) then

        fifo_almost_full_i <= '0';

      end if;

      if (wr_counter = wr_rd_counter_max) then

        fdct_fifo_hf_full <= '1';
      end if;

      if (rd_counter = wr_rd_counter_max) then

        fdct_fifo_hf_full  <= '0';
        fifo_almost_full_i <= '0';
      end if;

      if sof = '1' then
        fifo_almost_full_i <= '0';
        fdct_fifo_hf_full  <= '0';
      end if;

    end if;
  end process;
    

  process (CLK, RST)
  begin
    if (CLK'event and CLK = '1') then
      sof_p1 <= sof;
      if (init_table_rd = '0') then
        if (fdct_fifo_rd = '1') then
          if (rd_counter mod 8 = "000") then
            --rd_ptr <=  resize(do2(5 downto 3) *  unsigned(img_size_x) + do2(15 downto 7) * 8, log2(C_MAX_LINE_WIDTH*C_NUM_LINES));
            --data_temp2 <=  resize(do2(5 downto 3) *  unsigned(img_size_x) + do2(15 downto 7) * 8, 16);
            rd_ptr     <= resize(img_size_x_mult(to_integer(do2(5 downto 3))), log2(C_MAX_LINE_WIDTH*C_NUM_LINES)) + resize(do2(15 downto 6) * 8, log2(C_MAX_LINE_WIDTH*C_NUM_LINES));
            data_temp2 <= resize(img_size_x_mult(to_integer(do2(5 downto 3))), 16) + resize(do2(15 downto 6) * 8, 16);
          else
            rd_ptr <= rd_ptr + 1;
          end if;

          if (rd_counter mod 8 = "011") then
            if (rd_counter = wr_rd_counter_max_m4) then
              rd_addr2 <= (others => '0');
            else
              rd_addr2 <= resize(unsigned(rd_counter)/8+1, log2(C_MAX_LINE_WIDTH));
            end if;
          end if;

          if (rd_counter mod 8 = "101") then
            do2 <= unsigned(data_out2);
            we2 <= '1';
            if (rd_mod = unsigned(img_size_y) / 8) then
              data_in2 <= resize(counter2 * 8, 16);
              wr_addr2 <= resize(counter2, log2(C_MAX_LINE_WIDTH));
              counter2 <= counter2 + 1;
            else
              data_in2 <= data_temp2;
              if (rd_counter = wr_rd_counter_max_m2) then
                wr_addr2 <= (others => '0');
              else

                wr_addr2 <= resize(unsigned(rd_counter)/8, log2(C_MAX_LINE_WIDTH));

              end if;
            end if;
          else
            we2 <= '0';
          end if;

          rd_counter_total                       <= rd_counter_total + 1;
          rd_counter_total_plus_img_size_x_t8_m2 <= rd_counter_total_plus_img_size_x_t8_m2 + 1;
          rd_counter_total_plus_threshold        <= rd_counter_total_plus_threshold + 1;
          if (rd_counter_total = unsigned(result_m2)) then
            rd_counter_total_eq_result_m1 <= '1';
          else
            rd_counter_total_eq_result_m1 <= '0';
          end if;

          if (rd_counter_total_eq_result_m1 = '1') then

            init_table_rd <= '1';
            counter2      <= (others => '0');
          end if;

          if (rd_counter = wr_rd_counter_max) then

            rd_counter <= (others => '0');
            rd_mod     <= rd_mod + 1;

          else
            rd_counter <= rd_counter + 1;
          end if;




        end if;

        if sof = '1' then
          fdct_fifo_q                   <= (others => '0');
          temp                          <= (others => '0');
          rd_counter                    <= (others => '0');
          rd_counter_total              <= (others => '0');
          rd_counter_total_eq_result_m1 <= '0';
          rd_mod                        <= x"0001";
          rd_ptr                        <= (others => '0');
          init_table_rd                 <= '0';
          do2                           <= (others => '0');
          data_temp2                    <= (others => '0');
          wr_addr2                      <= (others => '0');
          rd_addr2                      <= (others => '0');
          we2                           <= '0';
          counter2                      <= (others => '0');
        end if;

        if sof_p1 = '1' then
          rd_counter_total_plus_img_size_x_t8_m2 <= resize(img_size_x_t8_m2, rd_counter_total_plus_img_size_x_t8_m2'length);
          rd_counter_total_plus_threshold        <= resize(unsigned(threshold), rd_counter_total_plus_threshold'length);
        end if;


  --         fdct_fifo_q <= (temp(15 downto 11) & "000" & 
  --                 temp(10 downto 5) & "00" & 
  --                 temp(4 downto 0) & "000") when C_PIXEL_BITS = 16 else 
  --                 std_logic_vector(resize(unsigned(temp), 24));
      end if;

      temp <= q;
      if (C_PIXEL_BITS = 16) then

        fdct_fifo_q <= (temp(15 downto 11) & "000" &
                        temp(10 downto 5) & "00" &
                        temp(4 downto 0) & "000");
      else
        fdct_fifo_q <= temp;
      end if;

    end if;
    if (RST = '1') then
      fdct_fifo_q                            <= (others => '0');
      temp                                   <= (others => '0');
      rd_counter                             <= (others => '0');
      rd_counter_total                       <= (others => '0');
      rd_counter_total_plus_img_size_x_t8_m2 <= (others => '0');
      rd_counter_total_plus_threshold        <= (others => '0');
      rd_counter_total_eq_result_m1          <= '0';
      rd_mod                                 <= x"0001";
      init_table_rd                          <= '0';
      do2                                    <= (others => '0');
      wr_addr2                               <= (others => '0');
      rd_addr2                               <= (others => '0');
      we2                                    <= '0';
      counter2                               <= (others => '0');
      sof_p1                                 <= '0';
    end if;
  end process;
end architecture RTL;
-------------------------------------------------------------------------------
-- Architecture: end
-------------------------------------------------------------------------------