library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.pkg_general.all;
use work.pkg_axi.all;

entity video_capture_tb is
end video_capture_tb;

architecture sim of video_capture_tb is

    type binfile is file of character;

    constant num_chan    : positive := 4;
    constant ver_addr_px : positive := 720;
    constant hor_addr_px : positive := 1280;

    signal rst_async     : std_logic                                := '1';
    signal clk_px        : std_logic                                := '1';
    signal px_addr_v     : std_logic_vector(log2(ver_addr_px)-1 downto 0);
    signal px_addr_h     : std_logic_vector(log2(hor_addr_px)-1 downto 0);
    signal px_en         : std_logic;
    signal h_sync        : std_logic;
    signal v_sync        : std_logic;
    signal vid_dval_in   : std_logic;
    signal vid_hsync_in  : std_logic;
    signal vid_vsync_in  : std_logic;
    signal vid_data_in   : std_logic_vector(23 downto 0);
    signal clk_enc       : std_logic                                := '1';
    signal res_stable    : std_logic;
    signal enc_m_axi_out : axi4_mout_sin_array(num_chan-1 downto 0) := (others => axi4_mout_sin_zero);
    signal enc_m_axi_in  : axi4_min_sout_array(num_chan-1 downto 0) := (others => axi4_min_sout_zero);
    signal reg_s_axi_in  : axi4lite_mout_sin                        := axi4lite_mout_sin_zero;
    signal reg_s_axi_out : axi4lite_min_sout                        := axi4lite_min_sout_zero;

    signal mem_waddr : slv32d_array(num_chan-1 downto 0);
    signal mem_wdata : slv64d_array(num_chan-1 downto 0);
    signal mem_wdval : std_logic_vector(num_chan-1 downto 0) := (others => '0');
    signal mem_raddr : std_logic_vector(31 downto 0)         := (others => '0');
    signal mem_rdata : std_logic_vector(63 downto 0);

begin

    rst_async <= '0'         after 100 ns;
    clk_enc   <= not clk_enc after 3500 ps;
    clk_px    <= not clk_px  after 6734 ps;

    video_sync_inst : entity work.video_sync
        generic map (
            h_sync_active_high => true,         -- boolean  := true;
            v_sync_active_high => true,         -- boolean  := true;
            ver_addr_px        => ver_addr_px,  -- positive := 1024;
            ver_front_porch_px => 5,            -- positive := 1;
            ver_sync_px        => 5,            -- positive := 3;
            ver_back_porch_px  => 20,           -- positive := 44;
            hor_addr_px        => hor_addr_px,  -- positive := 1280;
            hor_front_porch_px => 110,          -- positive := 64;
            hor_sync_px        => 40,           -- positive := 160;
            hor_back_porch_px  => 220           -- positive := 224
            )
        port map (
            reset     => rst_async,             -- in  std_logic;
            clk       => clk_px,                -- in  std_logic;
            px_addr_v => open,                  -- out std_logic_vector(log2(ver_addr_px)-1 downto 0);
            px_addr_h => open,                  -- out std_logic_vector(log2(hor_addr_px)-1 downto 0);
            px_en     => px_en,                 -- out std_logic;
            h_sync    => h_sync,                -- out std_logic;
            v_sync    => v_sync                 -- out std_logic
            );

    vid_hsync_in <= h_sync when rising_edge(clk_px);
    vid_vsync_in <= v_sync when rising_edge(clk_px);

    img_stimulus : process
        file img_in_file : binfile;

        variable img_in_index : integer range 0 to 255;
        variable r            : character;
        variable g            : character;
        variable b            : character;

        function get_in_file_name (index : integer) return string is
        begin
            return "stim_img_" & pad(integer'image(index), 8) & ".data";
        end function get_in_file_name;

    begin

        img_in_index := 0;
        file_open(img_in_file, get_in_file_name(img_in_index), read_mode);

        while true loop
            wait until rising_edge(clk_px);
            wait for 1 ps;
            if px_en = '1' then
                if endfile(img_in_file) then
                    file_close(img_in_file);
                    img_in_index := (img_in_index + 1) mod 256;
                    file_open(img_in_file, get_in_file_name(img_in_index), read_mode);
                end if;
                read(img_in_file, r);
                read(img_in_file, g);
                read(img_in_file, b);
                vid_data_in <= std_logic_vector(to_unsigned(character'pos(b), 8) & to_unsigned(character'pos(g), 8) & to_unsigned(character'pos(r), 8));
                vid_dval_in <= '1';
            else
                vid_data_in <= (others => '0');
                vid_dval_in <= '0';
            end if;
        end loop;

        wait;

    end process img_stimulus;

    DUT : entity work.video_capture
        generic map (
            num_chan    => num_chan,               -- integer := 4;
            clk_enc_mhz => 1000.0/7.0              -- real    := 1000.0/7.0
            )
        port map (
            clk_px          => clk_px,             -- in  std_logic;
            vid_data_in     => vid_data_in,        -- in  std_logic_vector(23 downto 0);
            vid_dval_in     => vid_dval_in,        -- in  std_logic;
            vid_hsync_in    => vid_hsync_in,       -- in  std_logic;
            vid_vsync_in    => vid_vsync_in,       -- in  std_logic;
            clk_enc         => clk_enc,            -- in  std_logic;
            rst_enc         => rst_async,          -- in  std_logic;
            res_detect_rst  => rst_async,          -- in  std_logic;
            res_stable      => res_stable,         -- out std_logic;
            capture_rst     => "not"(res_stable),  -- in  std_logic;
            capture_wr_done => open,               -- out std_logic;  -- pulse when write to memory completes
            enc_m_axi_out   => enc_m_axi_out,      -- out axi4_mout_sin_array(num_chan-1 downto 0);
            enc_m_axi_in    => enc_m_axi_in,       -- in  axi4_min_sout_array(num_chan-1 downto 0);
            reg_s_axi_in    => reg_s_axi_in,       -- in  axi4lite_mout_sin;
            reg_s_axi_out   => reg_s_axi_out       -- out axi4lite_min_sout
            );

    gen_axi_s : for i in enc_m_axi_in'range generate
    begin
        process (clk_enc)
            variable waddr : std_logic_vector(31 downto 0);
        begin
            if rising_edge(clk_enc) then
                enc_m_axi_in(i).bvalid <= '0';
                if enc_m_axi_out(i).awvalid = '1' then
                    enc_m_axi_in(i).awready <= '0';
                    enc_m_axi_in(i).wready  <= '1';
                    waddr                   := enc_m_axi_out(i).awaddr;
                end if;
                if enc_m_axi_in(i).wready = '1' and enc_m_axi_out(i).wvalid = '1' and enc_m_axi_out(i).wlast = '1' then
                    enc_m_axi_in(i).awready <= '1';
                    enc_m_axi_in(i).wready  <= '0';
                    enc_m_axi_in(i).bvalid  <= '1';
                end if;
                if enc_m_axi_in(i).wready = '1' and enc_m_axi_out(i).wvalid = '1'then
                    mem_waddr(i) <= waddr;
                    waddr        := std_logic_vector(unsigned(waddr) + enc_m_axi_out(i).wdata'length/8);
                    mem_wdata(i) <= enc_m_axi_out(i).wdata;
                    mem_wdval(i) <= '1';
                else
                    mem_waddr(i) <= (others => '-');
                    mem_wdata(i) <= (others => '-');
                    mem_wdval(i) <= '0';
                end if;

                if rst_async = '1' then
                    enc_m_axi_in(i).awready <= '1';
                    enc_m_axi_in(i).wready  <= '0';
                end if;
            end if;
        end process;
    end generate gen_axi_s;

    mem : entity work.memory_model
        port map (
            clk    => clk_enc,
            waddr0 => mem_waddr(0),
            wdata0 => mem_wdata(0),
            wen0   => mem_wdval(0),
            waddr1 => mem_waddr(1),
            wdata1 => mem_wdata(1),
            wen1   => mem_wdval(1),
            waddr2 => mem_waddr(2),
            wdata2 => mem_wdata(2),
            wen2   => mem_wdval(2),
            waddr3 => mem_waddr(3),
            wdata3 => mem_wdata(3),
            wen3   => mem_wdval(3),
            raddr  => mem_raddr,
            rdata  => mem_rdata
            );

    jpeg_extract : process

        procedure poke (
            constant waddr : in std_logic_vector(31 downto 0);
            constant wdata : in std_logic_vector(31 downto 0)
            ) is
        begin
            wait until rising_edge(clk_enc);
            reg_s_axi_in.awaddr  <= waddr;
            reg_s_axi_in.awvalid <= '1';
            reg_s_axi_in.wdata   <= wdata;
            reg_s_axi_in.wstrb   <= (others => '1');
            reg_s_axi_in.wvalid  <= '1';
            reg_s_axi_in.bready  <= '1';
            wait for 1 ps;
            while (reg_s_axi_in.awvalid or reg_s_axi_in.wvalid or reg_s_axi_in.bready) = '1' loop
                wait until rising_edge(clk_enc);
                if reg_s_axi_out.awready = '1' then
                    reg_s_axi_in.awvalid <= '0';
                end if;
                if reg_s_axi_out.wready = '1' then
                    reg_s_axi_in.wvalid <= '0';
                end if;
                if reg_s_axi_out.bvalid = '1' then
                    assert reg_s_axi_out.bresp(1) = '0' report "Invalid write response!" severity failure;
                    reg_s_axi_in.bready <= '0';
                end if;
                wait for 1 ps;
            end loop;
            reg_s_axi_in <= axi4lite_mout_sin_zero;
        end procedure poke;

        procedure peek (
            constant raddr : in    std_logic_vector(31 downto 0);
            variable rdata : inout std_logic_vector(31 downto 0)
            ) is
        begin
            wait until rising_edge(clk_enc);
            reg_s_axi_in.araddr  <= raddr;
            reg_s_axi_in.arvalid <= '1';
            reg_s_axi_in.rready  <= '1';
            wait for 1 ps;
            while (reg_s_axi_in.arvalid or reg_s_axi_in.rready) = '1' loop
                wait until rising_edge(clk_enc);
                if reg_s_axi_out.arready = '1' then
                    reg_s_axi_in.arvalid <= '0';
                end if;
                if reg_s_axi_out.rvalid = '1' then
                    assert reg_s_axi_out.rresp(1) = '0' report "Invalid read response!" severity failure;
                    reg_s_axi_in.rready <= '0';
                    rdata               := reg_s_axi_out.rdata;
                end if;
                wait for 1 ps;
            end loop;
            reg_s_axi_in <= axi4lite_mout_sin_zero;
        end procedure peek;

        procedure mem_rd (
            constant raddr : in    std_logic_vector(31 downto 0);
            variable rdata : inout std_logic_vector(63 downto 0)
            ) is
        begin
            mem_raddr <= raddr;
            wait until rising_edge(clk_enc);
            wait for 1 ps;
            rdata     := mem_rdata;
        end procedure mem_rd;

        function get_out_file_name (
            index   : integer;
            channel : integer
            ) return string is
        begin
            return "cap_img_" & pad(integer'image(index), 8) & "_ch" & integer'image(channel) & ".jpg";
        end function get_out_file_name;

        file img_out_file : binfile;

        procedure write_bytes (
            wdata : std_logic_vector
            ) is
            variable wdata_int : std_logic_vector(wdata'length-1 downto 0);
        begin
            wdata_int := wdata;
            for i in wdata_int'length/8-1 downto 0 loop
                write(img_out_file, character'val(to_integer(unsigned(wdata_int((i+1)*8-1 downto i*8)))));
            end loop;
        end procedure write_bytes;

        procedure mem_dump (
            base_address : unsigned;
            byte_length  : unsigned;
            out_file     : string
            ) is
            variable num_reads   : integer;
            variable num_bytes   : integer;
            variable raddr       : std_logic_vector(31 downto 0);
            variable rdata       : std_logic_vector(63 downto 0);
            constant rdata_bytes : integer := rdata'length / 8;
        begin
            file_open(img_out_file, out_file, write_mode);
            num_reads := to_integer(byte_length) / rdata_bytes;
            if byte_length mod rdata_bytes /= 0 then
                num_reads := num_reads + 1;
            end if;
            raddr     := std_logic_vector(base_address);
            num_bytes := to_integer(byte_length);
            for i in 1 to num_reads loop
                assert (num_bytes > 0) report "No more bytes left to read!" severity failure;
                mem_rd(raddr, rdata);
                rdata := byte_reverse(rdata);
                raddr := std_logic_vector(unsigned(raddr)+8);
                if num_bytes >= rdata_bytes then
                    write_bytes(rdata);
                    num_bytes := num_bytes - rdata_bytes;
                else
                    write_bytes(rdata(rdata'high downto rdata'high-num_bytes*8+1));
                    num_bytes := 0;
                end if;
            end loop;
            file_close(img_out_file);
        end procedure mem_dump;

        variable data          : std_logic_vector(31 downto 0) := (others => '0');
        variable addr_a        : std_logic_vector(31 downto 0) := (others => '0');
        variable addr_b        : std_logic_vector(31 downto 0) := (others => '0');
        variable addr_c        : std_logic_vector(31 downto 0) := (others => '0');
        variable addr_d        : std_logic_vector(31 downto 0) := (others => '0');
        variable size_a        : std_logic_vector(63 downto 0) := (others => '0');
        variable size_b        : std_logic_vector(63 downto 0) := (others => '0');
        variable size_c        : std_logic_vector(63 downto 0) := (others => '0');
        variable size_d        : std_logic_vector(63 downto 0) := (others => '0');
        variable img_out_index : integer                       := 0;

    begin

        img_out_index := 0;
        wait for 150 ms;

        while true loop
            poke(x"40000000", data);
            wait for 5 us;
            poke(x"40000010", data);
            wait for 5 us;
            poke(x"40000020", data);
            wait for 5 us;
            poke(x"40000030", data);
            wait for 5 us;

            peek(x"4000000C", addr_a);
            peek(x"4000001C", addr_b);
            peek(x"4000002C", addr_c);
            peek(x"4000003C", addr_d);

            assert false report "Read addresses." severity note;

            assert (unsigned(addr_a) >= 16#3800_0000#) and (unsigned(addr_a) <= 16#3FFF_FFFF#) report "Bad address, channel A!" severity failure;
            assert (unsigned(addr_b) >= 16#3800_0000#) and (unsigned(addr_b) <= 16#3FFF_FFFF#) report "Bad address, channel B!" severity failure;
            assert (unsigned(addr_c) >= 16#3800_0000#) and (unsigned(addr_c) <= 16#3FFF_FFFF#) report "Bad address, channel C!" severity failure;
            assert (unsigned(addr_d) >= 16#3800_0000#) and (unsigned(addr_d) <= 16#3FFF_FFFF#) report "Bad address, channel D!" severity failure;

            mem_rd(addr_a, size_a);
            mem_rd(addr_b, size_b);
            mem_rd(addr_c, size_c);
            mem_rd(addr_d, size_d);

            assert false report "Read sizes." severity note;

            assert or_reduce(size_a(size_a'high downto 22)) = '0' report "Bad size, channel A!" severity failure;
            assert or_reduce(size_b(size_b'high downto 22)) = '0' report "Bad size, channel B!" severity failure;
            assert or_reduce(size_c(size_c'high downto 22)) = '0' report "Bad size, channel C!" severity failure;
            assert or_reduce(size_d(size_d'high downto 22)) = '0' report "Bad size, channel D!" severity failure;

            -- 4 MB cap
            mem_dump(unsigned(addr_a)+16*8, unsigned(size_a(21 downto 0)), get_out_file_name(img_out_index, 0));
            mem_dump(unsigned(addr_b)+16*8, unsigned(size_b(21 downto 0)), get_out_file_name(img_out_index, 1));
            mem_dump(unsigned(addr_c)+16*8, unsigned(size_c(21 downto 0)), get_out_file_name(img_out_index, 2));
            mem_dump(unsigned(addr_d)+16*8, unsigned(size_d(21 downto 0)), get_out_file_name(img_out_index, 3));

            assert false report "Dump done." severity note;

            img_out_index := img_out_index + 1;

            poke(x"40000004", data);
            wait for 5 us;
            poke(x"40000014", data);
            wait for 5 us;
            poke(x"40000024", data);
            wait for 5 us;
            poke(x"40000034", data);
            wait for 5 us;

            wait for 90 ms;
        end loop;

        wait;

    end process jpeg_extract;

end sim;