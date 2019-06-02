library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

library work;
use work.pkg_general.all;
use work.pkg_axi.all;

entity buffered_encoder is
   port (
      clk_px            : in  std_logic;
      rst_px            : in  std_logic;
      res_x_in          : in  std_logic_vector(15 downto 0);
      res_y_in          : in  std_logic_vector(15 downto 0);
      res_x_nopad_in    : in  std_logic_vector(15 downto 0);
      res_y_nopad_in    : in  std_logic_vector(15 downto 0);
      img_start_in      : in  std_logic;
      img_base_addr     : in  std_logic_vector(31 downto 0);
      px_data_in        : in  std_logic_vector(23 downto 0);
      px_dval_in        : in  std_logic;
      px_dval_1st_in    : in  std_logic;  -- first pixel in image
      px_dval_last_in   : in  std_logic;  -- last pixel in image
      this_enc_ready    : out std_logic;
      clk_enc           : in  std_logic;
      rst_enc           : in  std_logic;
      px_stable         : in  std_logic;
      write_in_progress : out std_logic;
      write_fault       : out std_logic;
      m_axi_out         : out axi4_mout_sin;
      m_axi_in          : in  axi4_min_sout
      );
end buffered_encoder;

architecture rtl of buffered_encoder is

   constant BURST_LEN       : integer                                  := 16;
   constant AXI_WORD_LEN    : integer                                  := m_axi_out.wdata'length;
   constant ADDR_STEP       : std_logic_vector(m_axi_out.awaddr'range) := std_logic_vector(to_unsigned(BURST_LEN*AXI_WORD_LEN/8, m_axi_out.awaddr'length));
   constant RES_X_MAX       : integer                                  := 512;  -- must be a power of 2
   constant BUF_LINES       : integer                                  := 16;
   constant PX_FIFO_DEPTH   : integer                                  := BUF_LINES * RES_X_MAX;
   constant JPEG_FIFO_DEPTH : integer                                  := 16384 / AXI_WORD_LEN;

   type capture_state_type is (idle, accum_4_lines, accum_8_lines, enc_enable, wait_enc_done);

   signal res_x_reg       : std_logic_vector(res_x_in'length-1 downto 0);
   signal res_y_reg       : std_logic_vector(res_y_in'length-1 downto 0);
   signal res_x_nopad_reg : std_logic_vector(res_x_nopad_in'length-1 downto 0);
   signal res_y_nopad_reg : std_logic_vector(res_y_nopad_in'length-1 downto 0);
   signal cnt_4lines      : unsigned(2+res_x_in'length-1 downto 0);
   signal cnt_8lines      : unsigned(3+res_x_in'length-1 downto 0);
   signal px_data_reg     : std_logic_vector(px_data_in'length-1 downto 0);
   signal px_dval_reg     : std_logic;
   signal px_first_reg    : std_logic;
   signal px_last_reg     : std_logic;

   signal enc_init        : std_logic;
   signal enc_go_pxclk    : std_logic;
   signal px_cnt          : unsigned(cnt_8lines'range);
   signal have_4_lines    : std_logic;
   signal have_8_lines    : std_logic;
   signal capture_state   : capture_state_type;
   signal enc_ready_pxclk : std_logic;
   signal px_fifo_full    : std_logic;  -- TODO
   signal px_fifo_ren     : std_logic;
   signal px_fifo_rdata   : std_logic_vector(px_data_in'length-1 downto 0);
   signal px_fifo_first   : std_logic;
   signal px_fifo_last    : std_logic;
   signal px_fifo_empty   : std_logic;
   signal ce_pre          : std_logic;
   signal encode_enable   : std_logic;
   signal gating_en       : std_logic;
   signal ds_afull        : std_logic;
   signal enc_go          : std_logic;
   signal rst_jpeg_enc    : std_logic;
   signal ce_enc          : std_logic;
   signal ce_enc_p1       : std_logic;
   signal ce_enc_p2       : std_logic;

   signal image_size_x       : std_logic_vector(15 downto 0);
   signal image_size_y       : std_logic_vector(15 downto 0);
   signal image_size_x_nopad : std_logic_vector(15 downto 0);
   signal image_size_y_nopad : std_logic_vector(15 downto 0);
   signal image_start        : std_logic;
   signal enc_ready          : std_logic;
   signal enc_ready_p1       : std_logic;
   signal enc_size           : std_logic_vector(23 downto 0);
   signal iram_wdata         : std_logic_vector(23 downto 0);
   signal iram_wren          : std_logic;
   signal iram_wren_last     : std_logic;
   signal iram_fifo_afull    : std_logic;
   signal ram_byte           : std_logic_vector(7 downto 0);
   signal ram_wren           : std_logic;
   signal ram_byte_p1        : std_logic_vector(7 downto 0);
   signal ram_wren_p1        : std_logic;
   signal jpeg_word          : std_logic_vector(AXI_WORD_LEN-1 downto 0);
   signal jpeg_word_swap     : std_logic_vector(AXI_WORD_LEN-1 downto 0);
   signal jpeg_word_valid    : std_logic;
   signal jpeg_word_wlast    : std_logic;
   signal addr_valid         : std_logic;
   signal byte_cnt           : integer range 0 to AXI_WORD_LEN/ram_byte'length-1;
   signal burst_words_left   : integer range 0 to BURST_LEN-1;
   signal addr_wr            : std_logic_vector(m_axi_out.awaddr'range);
   signal addr_wr_next       : std_logic_vector(m_axi_out.awaddr'range);
   signal addr_wr_size       : std_logic_vector(m_axi_out.awaddr'range);

   type data_state_type is (data_idle, data_fwd, data_term_burst, data_wr_length, data_wait_wr_done, data_post_reset);

   signal data_state            : data_state_type := data_post_reset;
   signal enc_ready_and_wr_done : std_logic;
   signal override_enc_size     : std_logic;
   signal jpeg_data_afull       : std_logic;
   signal m_axi_wready_g        : std_logic;
   signal m_axi_wvalid_n        : std_logic;
   signal jpeg_addr_afull       : std_logic;
   signal m_axi_awready_g       : std_logic;
   signal m_axi_awvalid_n       : std_logic;
   signal outstanding_write_cnt : natural range 0 to 2*JPEG_FIFO_DEPTH/BURST_LEN-1;
   signal wack                  : std_logic;
   signal have_pending_writes   : std_logic;
   signal img_base_addr_reg     : std_logic_vector(img_base_addr'range);
   signal addr_wr_base_clk_enc  : std_logic_vector(img_base_addr'range);

begin

   res_reg : process (clk_px)
   begin
      if rising_edge(clk_px) then

         if img_start_in = '1' then
            img_base_addr_reg <= img_base_addr;
            res_x_reg         <= res_x_in;
            res_y_reg         <= res_y_in;
            res_x_nopad_reg   <= res_x_nopad_in;
            res_y_nopad_reg   <= res_y_nopad_in;
            cnt_4lines        <= shift_left(resize(unsigned(res_x_in), cnt_4lines'length), 2);
            cnt_8lines        <= shift_left(resize(unsigned(res_x_in), cnt_8lines'length), 3);
         end if;

         px_data_reg  <= px_data_in;
         px_dval_reg  <= px_dval_in;
         px_first_reg <= px_dval_1st_in;
         px_last_reg  <= px_dval_last_in;

      end if;
   end process res_reg;

   -- Below are safe to cross w/o handshake because they are sampled at img_start_in,
   -- but used (at the earliest) after 4 full lines have been buffered.
   cross_base_addr : entity work.cdc_synchro
      generic map (
         data_width  => img_base_addr_reg'length,  -- positive              := 1;
         sync_stages => 3                          -- integer range 2 to 10 := 3
         )
      port map (
         din  => img_base_addr_reg,                -- in  std_logic_vector(data_width-1 downto 0);
         clk  => clk_enc,                          -- in  std_logic;
         dout => addr_wr_base_clk_enc              -- out std_logic_vector(data_width-1 downto 0)  -- do not assume all bits will propagate in the same cycle!
         );

   cross_res_x : entity work.cdc_synchro
      generic map (
         data_width  => res_x_reg'length,  -- positive              := 1;
         sync_stages => 3                  -- integer range 2 to 10 := 3
         )
      port map (
         din  => res_x_reg,                -- in  std_logic_vector(data_width-1 downto 0);
         clk  => clk_enc,                  -- in  std_logic;
         dout => image_size_x              -- out std_logic_vector(data_width-1 downto 0)  -- do not assume all bits will propagate in the same cycle!
         );

   cross_res_xnopad : entity work.cdc_synchro
      generic map (
         data_width  => res_x_nopad_reg'length,  -- positive              := 1;
         sync_stages => 3                        -- integer range 2 to 10 := 3
         )
      port map (
         din  => res_x_nopad_reg,                -- in  std_logic_vector(data_width-1 downto 0);
         clk  => clk_enc,                        -- in  std_logic;
         dout => image_size_x_nopad              -- out std_logic_vector(data_width-1 downto 0)  -- do not assume all bits will propagate in the same cycle!
         );

   cross_res_y : entity work.cdc_synchro
      generic map (
         data_width  => res_y_reg'length,  -- positive              := 1;
         sync_stages => 3                  -- integer range 2 to 10 := 3
         )
      port map (
         din  => res_y_reg,                -- in  std_logic_vector(data_width-1 downto 0);
         clk  => clk_enc,                  -- in  std_logic;
         dout => image_size_y              -- out std_logic_vector(data_width-1 downto 0)  -- do not assume all bits will propagate in the same cycle!
         );

   cross_res_ynopad : entity work.cdc_synchro
      generic map (
         data_width  => res_y_nopad_reg'length,  -- positive              := 1;
         sync_stages => 3                        -- integer range 2 to 10 := 3
         )
      port map (
         din  => res_y_nopad_reg,                -- in  std_logic_vector(data_width-1 downto 0);
         clk  => clk_enc,                        -- in  std_logic;
         dout => image_size_y_nopad              -- out std_logic_vector(data_width-1 downto 0)  -- do not assume all bits will propagate in the same cycle!
         );

   capture_fsm : process (clk_px)
   begin
      if rising_edge(clk_px) then
         enc_init     <= '0';
         enc_go_pxclk <= '0';
         if px_first_reg = '1' then
            px_cnt <= to_unsigned(1, px_cnt'length);
         elsif px_dval_reg = '1' then
            px_cnt <= px_cnt + 1;
         end if;
         if px_cnt = cnt_4lines then
            have_4_lines <= '1';
         end if;
         if px_cnt = cnt_8lines then
            have_8_lines <= '1';
         end if;
         case capture_state is
            when idle =>
               have_4_lines <= '0';
               have_8_lines <= '0';
               if px_first_reg = '1' then
                  capture_state  <= accum_4_lines;
                  this_enc_ready <= '0';
               end if;
            when accum_4_lines =>
               if have_4_lines = '1' then
                  capture_state <= accum_8_lines;
                  enc_init      <= '1';
               end if;
            when accum_8_lines =>
               if have_8_lines = '1' then
                  capture_state <= enc_enable;
               end if;
            when enc_enable =>
               px_cnt        <= (others => '0');
               enc_go_pxclk  <= '1';
               capture_state <= wait_enc_done;
            when wait_enc_done =>
               if enc_ready_pxclk = '1' then
                  capture_state  <= idle;
                  this_enc_ready <= '1';
               end if;
         end case;
         if rst_px = '1' then
            capture_state  <= wait_enc_done;
            this_enc_ready <= '0';
         end if;
      end if;
   end process capture_fsm;

   cross_enc_ready : entity work.cdc_synchro
      generic map (
         data_width  => 1,                  -- positive              := 1;
         sync_stages => 3                   -- integer range 2 to 10 := 3
         )
      port map (
         din(0)  => enc_ready_and_wr_done,  -- in  std_logic_vector(data_width-1 downto 0);
         clk     => clk_px,                 -- in  std_logic;
         dout(0) => enc_ready_pxclk         -- out std_logic_vector(data_width-1 downto 0)  -- do not assume all bits will propagate in the same cycle!
         );

   init_pulse : entity work.cdc_pulse
      generic map (
         sync_stages => 3                  -- integer range 2 to 10 := 3
         )
      port map (
         src_clk    => clk_px,             -- in  std_logic;
         src_pulse  => enc_init,           -- in  std_logic;
         dest_clk   => clk_enc,            -- in  std_logic;
         dest_pulse => image_start         -- out std_logic
         );

   go_pulse : entity work.cdc_pulse
      generic map (
         sync_stages => 3                  -- integer range 2 to 10 := 3
         )
      port map (
         src_clk    => clk_px,             -- in  std_logic;
         src_pulse  => enc_go_pxclk,       -- in  std_logic;
         dest_clk   => clk_enc,            -- in  std_logic;
         dest_pulse => enc_go              -- out std_logic
         );

   fifo_in : xpm_fifo_async
      generic map (
         FIFO_MEMORY_TYPE    => "block",               -- string   := "block";
         FIFO_WRITE_DEPTH    => PX_FIFO_DEPTH,         -- integer  := 2048;
         RELATED_CLOCKS      => 0,                     -- integer  := 0;
         WRITE_DATA_WIDTH    => px_data_in'length+2,   -- integer  := 32;
         READ_MODE           => "fwft",                -- string   :="std";
         FIFO_READ_LATENCY   => 0,                     -- integer  := 1;
         FULL_RESET_VALUE    => 0,                     -- integer  := 0;
         USE_ADV_FEATURES    => "0707",                -- string   :="0707";
         READ_DATA_WIDTH     => px_data_in'length+2,   -- integer  := 32;
         CDC_SYNC_STAGES     => 2,                     -- integer  := 2;
         WR_DATA_COUNT_WIDTH => log2(PX_FIFO_DEPTH),   -- integer  := 12;
         PROG_FULL_THRESH    => 10,                    -- integer  := 10;
         RD_DATA_COUNT_WIDTH => log2(PX_FIFO_DEPTH),   -- integer  := 12;
         PROG_EMPTY_THRESH   => 10,                    -- integer  := 10;
         DOUT_RESET_VALUE    => "0",                   -- string   := "0";
         ECC_MODE            => "no_ecc",              -- string   :="no_ecc";
         WAKEUP_TIME         => 0                      -- integer  := 0
         )
      port map (
         sleep                      => '0',            -- in  std_logic;
         rst                        => rst_px,         -- in  std_logic;
         wr_clk                     => clk_px,         -- in  std_logic;
         wr_en                      => px_dval_reg,    -- in  std_logic;
         din(px_data_reg'length+1)  => px_first_reg,   -- in  std_logic_vector(WRITE_DATA_WIDTH-1 downto 0);
         din(px_data_reg'length)    => px_last_reg,    -- in  std_logic_vector(WRITE_DATA_WIDTH-1 downto 0);
         din(px_data_reg'range)     => px_data_reg,    -- in  std_logic_vector(WRITE_DATA_WIDTH-1 downto 0);
         full                       => px_fifo_full,   -- out std_logic;
         prog_full                  => open,           -- out std_logic;
         wr_data_count              => open,           -- out std_logic_vector(WR_DATA_COUNT_WIDTH-1 downto 0);
         overflow                   => open,           -- out std_logic;
         wr_rst_busy                => open,           -- out std_logic;
         almost_full                => open,           -- out std_logic;
         wr_ack                     => open,           -- out std_logic;
         rd_clk                     => clk_enc,        -- in  std_logic;
         rd_en                      => px_fifo_ren,    -- in  std_logic;
         dout(px_data_reg'length+1) => px_fifo_first,  -- out std_logic_vector(READ_DATA_WIDTH-1 downto 0);
         dout(px_data_reg'length)   => px_fifo_last,   -- out std_logic_vector(READ_DATA_WIDTH-1 downto 0);
         dout(px_data_reg'range)    => px_fifo_rdata,  -- out std_logic_vector(READ_DATA_WIDTH-1 downto 0);
         empty                      => px_fifo_empty,  -- out std_logic;
         prog_empty                 => open,           -- out std_logic;
         rd_data_count              => open,           -- out std_logic_vector(RD_DATA_COUNT_WIDTH-1 downto 0);
         underflow                  => open,           -- out std_logic;
         rd_rst_busy                => open,           -- out std_logic;
         almost_empty               => open,           -- out std_logic;
         data_valid                 => open,           -- out std_logic;
         injectsbiterr              => '0',            -- in  std_logic;
         injectdbiterr              => '0',            -- in  std_logic;
         sbiterr                    => open,           -- out std_logic;
         dbiterr                    => open            -- out std_logic
         );

   px_fifo_ren <= ce_pre and (not iram_fifo_afull) and (not px_fifo_empty) and encode_enable;

   gen_ce_pre : process (gating_en, iram_fifo_afull, px_fifo_empty, ds_afull)
   begin
      ce_pre <= '1';        -- enable by default
      if gating_en = '1' then
         if iram_fifo_afull = '0' and px_fifo_empty = '1' then
            ce_pre <= '0';  -- upstream starved
         end if;
      end if;
      if ds_afull = '1' then
         ce_pre <= '0';     -- downstream full
      end if;
   end process gen_ce_pre;

   gen_ce_wr : process (clk_enc)
   begin
      if rising_edge(clk_enc) then
         rst_jpeg_enc <= '0';

         if enc_go = '1' then
            encode_enable <= '1';
         elsif iram_wren_last = '1' then
            encode_enable <= '0';
         end if;

         gating_en      <= encode_enable;
         ce_enc         <= ce_pre;
         iram_wdata     <= px_fifo_rdata;
         iram_wren      <= px_fifo_ren;
         iram_wren_last <= px_fifo_ren and px_fifo_last;

         if (rst_enc = '1') or (px_stable = '0') then
            encode_enable <= '0';
            gating_en     <= '0';
            rst_jpeg_enc  <= '1';
         end if;
      end if;
   end process gen_ce_wr;

   jpeg_enc_ce_inst : entity work.jpeg_enc_ce
      port map (
         clk                => clk_enc,             -- in  std_logic;
         ce                 => ce_enc,              -- in  std_logic;
         rst                => rst_jpeg_enc,        -- in  std_logic;
         -- Control
         image_size_x       => image_size_x,        -- in  std_logic_vector(15 downto 0);
         image_size_y       => image_size_y,        -- in  std_logic_vector(15 downto 0);
         image_size_x_nopad => image_size_x_nopad,  -- in  std_logic_vector(15 downto 0);
         image_size_y_nopad => image_size_y_nopad,  -- in  std_logic_vector(15 downto 0);
         image_start        => image_start,         -- in  std_logic;
         -- Status
         enc_ready          => enc_ready,           -- out std_logic;
         enc_size           => enc_size,            -- out std_logic_vector(23 downto 0);
         -- Image in
         iram_wdata         => iram_wdata,          -- in  std_logic_vector(C_PIXEL_BITS-1 downto 0);
         iram_wren          => iram_wren,           -- in  std_logic;
         iram_fifo_afull    => iram_fifo_afull,     -- out std_logic;
         -- Output
         ram_byte           => ram_byte,            -- out std_logic_vector(7 downto 0);
         ram_wren           => ram_wren,            -- out std_logic;
         ram_wraddr         => open,                -- out std_logic_vector(23 downto 0);
         outif_almost_full  => '0'                  -- in  std_logic
         );

   -- TODO refactor this process
   ds_makewords : process (clk_enc)
   begin
      if rising_edge(clk_enc) then

         ds_afull        <= jpeg_data_afull or jpeg_addr_afull;
         ram_wren_p1     <= ram_wren;
         ram_byte_p1     <= ram_byte;
         ce_enc_p1       <= ce_enc;
         ce_enc_p2       <= ce_enc_p1;
         enc_ready_p1    <= enc_ready;
         jpeg_word_valid <= '0';
         jpeg_word_wlast <= '0';
         addr_valid      <= '0';

         case data_state is
            when data_idle =>
               override_enc_size     <= '0';
               enc_ready_and_wr_done <= '1';
               if enc_ready = '0' then
                  enc_ready_and_wr_done <= '0';
                  addr_wr_size          <= addr_wr_base_clk_enc;
                  addr_wr_next          <= std_logic_vector(unsigned(addr_wr_base_clk_enc)+unsigned(ADDR_STEP));
                  data_state            <= data_fwd;
                  write_in_progress     <= '1';
               end if;
            when data_fwd =>
               if ram_wren_p1 = '1' and ce_enc_p2 = '1' then
                  for i in 0 to jpeg_word'length/ram_byte'length-1 loop
                     if byte_cnt = jpeg_word'length/ram_byte'length-1-i then
                        jpeg_word((i+1)*ram_byte'length-1 downto i*ram_byte'length) <= ram_byte_p1;
                     end if;
                  end loop;
                  if byte_cnt = jpeg_word'length/ram_byte'length-1 then
                     byte_cnt        <= 0;
                     jpeg_word_valid <= '1';
                     if burst_words_left = 0 then
                        burst_words_left <= BURST_LEN-1;
                     else
                        burst_words_left <= burst_words_left - 1;
                     end if;
                     if burst_words_left = 1 then
                        jpeg_word_wlast <= '1';
                        addr_valid      <= '1';
                        addr_wr         <= addr_wr_next;
                        addr_wr_next    <= std_logic_vector(unsigned(addr_wr_next)+unsigned(ADDR_STEP));
                     end if;
                  else
                     byte_cnt <= byte_cnt + 1;
                  end if;
               elsif (enc_ready = '1') or (px_stable = '0') then
                  data_state        <= data_term_burst;
                  override_enc_size <= not px_stable;
                  byte_cnt          <= 0;
                  jpeg_word_valid   <= '1';
                  if burst_words_left = 0 then
                     burst_words_left <= BURST_LEN-1;
                  else
                     burst_words_left <= burst_words_left - 1;
                  end if;
                  if burst_words_left = 1 then
                     jpeg_word_wlast <= '1';
                     addr_valid      <= '1';
                     addr_wr         <= addr_wr_next;
                     addr_wr_next    <= std_logic_vector(unsigned(addr_wr_next)+unsigned(ADDR_STEP));
                  end if;
               end if;
            when data_term_burst =>
               jpeg_word_valid  <= '1';
               if burst_words_left = 0 then
                  if override_enc_size = '1' then
                     jpeg_word <= (others => '1');
                  else
                     jpeg_word <= byte_reverse(pad(enc_size, jpeg_word'length));
                  end if;
                  burst_words_left <= BURST_LEN-1;
                  data_state       <= data_wr_length;
               else
                  burst_words_left <= burst_words_left - 1;
                  jpeg_word        <= (others => '0');
               end if;
               if burst_words_left = 1 then
                  jpeg_word_wlast <= '1';
                  addr_valid      <= '1';
                  addr_wr         <= addr_wr_next;
                  addr_wr_next    <= (others => '-');
               end if;
            when data_wr_length =>
               if burst_words_left = 0 then
                  data_state <= data_wait_wr_done;
               else
                  burst_words_left <= burst_words_left - 1;
                  jpeg_word        <= (others => '0');
                  jpeg_word_valid  <= '1';
               end if;
               if burst_words_left = 1 then
                  jpeg_word_wlast <= '1';
                  addr_valid      <= '1';
                  addr_wr         <= addr_wr_size;
               end if;
            when data_wait_wr_done =>
               if have_pending_writes = '0' then
                  data_state        <= data_post_reset;
                  write_in_progress <= '0';
               end if;
            when others =>  -- data_post_reset
               enc_ready_and_wr_done <= '0';
               if enc_ready = '1' then
                  data_state <= data_idle;
               end if;
         end case;
         if rst_enc = '1' then
            byte_cnt          <= 0;
            burst_words_left  <= 0;
            write_in_progress <= '0';
            data_state        <= data_post_reset;
         end if;
      end if;
   end process ds_makewords;

   write_bookkeeping : process (clk_enc)
   begin
      if rising_edge(clk_enc) then
         wack <= '0';
         if m_axi_in.bvalid = '1' then
            if m_axi_in.bresp(1) = '0' then  -- OKAY / EXOKAY
               wack <= '1';
            else
               write_fault <= '1';
            end if;
         end if;
         if addr_valid = '1' and wack = '0' then
            outstanding_write_cnt <= outstanding_write_cnt + 1;
            if outstanding_write_cnt = 0 then
               have_pending_writes <= '1';
            end if;
         elsif addr_valid = '0' and wack = '1' then
            outstanding_write_cnt <= outstanding_write_cnt - 1;
            if outstanding_write_cnt = 1 then
               have_pending_writes <= '0';
            end if;
            if outstanding_write_cnt = 0 then
               write_fault <= '1';
            end if;
         end if;
         if rst_enc = '1' then
            write_fault           <= '0';
            outstanding_write_cnt <= 0;
            have_pending_writes   <= '0';
         end if;
      end if;
   end process write_bookkeeping;

   jpeg_word_swap <= byte_reverse(jpeg_word);

   fifo_dout : xpm_fifo_sync
      generic map (
         FIFO_MEMORY_TYPE    => "block",                      -- string  := "block";
         FIFO_WRITE_DEPTH    => JPEG_FIFO_DEPTH,              -- integer := 2048;
         WRITE_DATA_WIDTH    => jpeg_word'length+1,           -- integer := 32;
         READ_MODE           => "fwft",                       -- string  := "std";
         FIFO_READ_LATENCY   => 0,                            -- integer := 1;
         FULL_RESET_VALUE    => 0,                            -- integer := 0;
         USE_ADV_FEATURES    => "0707",                       -- string  := "0707";
         READ_DATA_WIDTH     => jpeg_word'length+1,           -- integer := 32;
         WR_DATA_COUNT_WIDTH => log2(JPEG_FIFO_DEPTH),        -- integer := 12;
         PROG_FULL_THRESH    => JPEG_FIFO_DEPTH-3*BURST_LEN,  -- integer := 10;
         RD_DATA_COUNT_WIDTH => log2(JPEG_FIFO_DEPTH),        -- integer := 12;
         PROG_EMPTY_THRESH   => BURST_LEN,                    -- integer := 10;
         DOUT_RESET_VALUE    => "0",                          -- string  := "0";
         ECC_MODE            => "no_ecc",                     -- string  := "no_ecc";
         WAKEUP_TIME         => 0                             -- integer := 0
         )
      port map (
         sleep                  => '0',                       -- in  std_logic;
         rst                    => rst_enc,                   -- in  std_logic;
         wr_clk                 => clk_enc,                   -- in  std_logic;
         wr_en                  => jpeg_word_valid,           -- in  std_logic;
         din(jpeg_word'length)  => jpeg_word_wlast,           -- in  std_logic_vector(WRITE_DATA_WIDTH-1 downto 0);
         din(jpeg_word'range)   => jpeg_word_swap,            -- in  std_logic_vector(WRITE_DATA_WIDTH-1 downto 0);
         full                   => open,                      -- out std_logic;
         prog_full              => jpeg_data_afull,           -- out std_logic;
         wr_data_count          => open,                      -- out std_logic_vector(WR_DATA_COUNT_WIDTH-1 downto 0);
         overflow               => open,                      -- out std_logic;
         wr_rst_busy            => open,                      -- out std_logic;
         almost_full            => open,                      -- out std_logic;
         wr_ack                 => open,                      -- out std_logic;
         rd_en                  => m_axi_wready_g,            -- in  std_logic;
         dout(jpeg_word'length) => m_axi_out.wlast,           -- out std_logic_vector(READ_DATA_WIDTH-1 downto 0);
         dout(jpeg_word'range)  => m_axi_out.wdata,           -- out std_logic_vector(READ_DATA_WIDTH-1 downto 0);
         empty                  => m_axi_wvalid_n,            -- out std_logic;
         prog_empty             => open,                      -- out std_logic;
         rd_data_count          => open,                      -- out std_logic_vector(RD_DATA_COUNT_WIDTH-1 downto 0);
         underflow              => open,                      -- out std_logic;
         rd_rst_busy            => open,                      -- out std_logic;
         almost_empty           => open,                      -- out std_logic;
         data_valid             => open,                      -- out std_logic;
         injectsbiterr          => '0',                       -- in  std_logic;
         injectdbiterr          => '0',                       -- in  std_logic;
         sbiterr                => open,                      -- out std_logic;
         dbiterr                => open                       -- out std_logic
         );
   m_axi_out.wvalid <= not m_axi_wvalid_n;
   m_axi_wready_g   <= m_axi_in.wready and not m_axi_wvalid_n;

   fifo_aout : xpm_fifo_sync
      generic map (
         FIFO_MEMORY_TYPE    => "block",                          -- string  := "block";
         FIFO_WRITE_DEPTH    => JPEG_FIFO_DEPTH/BURST_LEN,        -- integer := 2048;
         WRITE_DATA_WIDTH    => m_axi_out.awaddr'length,          -- integer := 32;
         READ_MODE           => "fwft",                           -- string  := "std";
         FIFO_READ_LATENCY   => 0,                                -- integer := 1;
         FULL_RESET_VALUE    => 0,                                -- integer := 0;
         USE_ADV_FEATURES    => "0707",                           -- string  := "0707";
         READ_DATA_WIDTH     => m_axi_out.awaddr'length,          -- integer := 32;
         WR_DATA_COUNT_WIDTH => log2(JPEG_FIFO_DEPTH/BURST_LEN),  -- integer := 12;
         PROG_FULL_THRESH    => JPEG_FIFO_DEPTH/BURST_LEN-5,      -- integer := 10;
         RD_DATA_COUNT_WIDTH => log2(JPEG_FIFO_DEPTH/BURST_LEN),  -- integer := 12;
         PROG_EMPTY_THRESH   => 10,                               -- integer := 10;
         DOUT_RESET_VALUE    => "0",                              -- string  := "0";
         ECC_MODE            => "no_ecc",                         -- string  := "no_ecc";
         WAKEUP_TIME         => 0                                 -- integer := 0
         )
      port map (
         sleep         => '0',                                    -- in  std_logic;
         rst           => rst_enc,                                -- in  std_logic;
         wr_clk        => clk_enc,                                -- in  std_logic;
         wr_en         => addr_valid,                             -- in  std_logic;
         din           => addr_wr,                                -- in  std_logic_vector(WRITE_DATA_WIDTH-1 downto 0);
         full          => open,                                   -- out std_logic;
         prog_full     => jpeg_addr_afull,                        -- out std_logic;
         wr_data_count => open,                                   -- out std_logic_vector(WR_DATA_COUNT_WIDTH-1 downto 0);
         overflow      => open,                                   -- out std_logic;
         wr_rst_busy   => open,                                   -- out std_logic;
         almost_full   => open,                                   -- out std_logic;
         wr_ack        => open,                                   -- out std_logic;
         rd_en         => m_axi_awready_g,                        -- in  std_logic;
         dout          => m_axi_out.awaddr,                       -- out std_logic_vector(READ_DATA_WIDTH-1 downto 0);
         empty         => m_axi_awvalid_n,                        -- out std_logic;
         prog_empty    => open,                                   -- out std_logic;
         rd_data_count => open,                                   -- out std_logic_vector(RD_DATA_COUNT_WIDTH-1 downto 0);
         underflow     => open,                                   -- out std_logic;
         rd_rst_busy   => open,                                   -- out std_logic;
         almost_empty  => open,                                   -- out std_logic;
         data_valid    => open,                                   -- out std_logic;
         injectsbiterr => '0',                                    -- in  std_logic;
         injectdbiterr => '0',                                    -- in  std_logic;
         sbiterr       => open,                                   -- out std_logic;
         dbiterr       => open                                    -- out std_logic
         );
   m_axi_out.awvalid <= not m_axi_awvalid_n;
   m_axi_awready_g   <= m_axi_in.awready and not m_axi_awvalid_n;

   m_axi_out.araddr  <= (others => '0');
   m_axi_out.arburst <= "01";
   m_axi_out.arcache <= "0011";
   m_axi_out.arlen   <= (others => '0');
   m_axi_out.arlock  <= (others => '0');
   m_axi_out.arprot  <= (others => '0');
   m_axi_out.arqos   <= (others => '0');
   m_axi_out.arsize  <= (others => '0');
   m_axi_out.arvalid <= '0';
   m_axi_out.rready  <= '0';

   m_axi_out.awburst <= "01";    -- INCR
   m_axi_out.awcache <= "0011";  -- Normal Non-cacheable Bufferable
   m_axi_out.awlen   <= std_logic_vector(to_unsigned(BURST_LEN-1, m_axi_out.awlen'length));
   m_axi_out.awlock  <= (others => '0');
   m_axi_out.awprot  <= (others => '0');
   m_axi_out.awqos   <= (others => '0');
   m_axi_out.awsize  <= std_logic_vector(to_unsigned(log2(jpeg_word'length/8), m_axi_out.awsize'length));
   m_axi_out.bready  <= '1';
   m_axi_out.wstrb   <= (others => '1');

end rtl;