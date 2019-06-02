library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg_general.all;
use work.pkg_axi.all;

entity striped_encoders is
    generic (
        num_chan : integer := 4
        );
    port (
        clk_px          : in  std_logic;
        rst_px          : in  std_logic;
        vid_data_in     : in  std_logic_vector(23 downto 0);
        vid_dval_in     : in  std_logic;
        vid_hsync_in    : in  std_logic;
        vid_vsync_in    : in  std_logic;
        vid_res_x       : in  std_logic_vector(15 downto 0);
        vid_res_y       : in  std_logic_vector(15 downto 0);
        clk_enc         : in  std_logic;
        rst_enc         : in  std_logic;
        px_stable       : in  std_logic;
        capture_wr_done : out std_logic;  -- pulse when write to memory completes
        enc_m_axi_out   : out axi4_mout_sin_array(num_chan-1 downto 0);
        enc_m_axi_in    : in  axi4_min_sout_array(num_chan-1 downto 0);
        reg_s_axi_in    : in  axi4lite_mout_sin;
        reg_s_axi_out   : out axi4lite_min_sout
        );
end striped_encoders;

architecture rtl of striped_encoders is

    signal rst_enc_n               : std_logic;
    signal vid_data_csc            : std_logic_vector(23 downto 0);
    signal vid_dval_csc            : std_logic;
    signal vid_hsync_csc           : std_logic;
    signal vid_vsync_csc           : std_logic;
    signal vid_data_shim           : std_logic_vector(23 downto 0);
    signal vid_dval_shim           : std_logic;
    signal vid_dval_shim_1st       : std_logic;
    signal vid_dval_shim_last      : std_logic;
    signal vid_dval_shim_1st_early : std_logic;
    signal stripe_x_out            : slv16d_array(num_chan-1 downto 0);
    signal stripe_y_out            : std_logic_vector(15 downto 0);
    signal stripe_x_nopad_out      : slv16d_array(num_chan-1 downto 0);
    signal stripe_y_nopad_out      : std_logic_vector(15 downto 0);
    signal stripe_start_out        : std_logic;
    signal stripe_data_out         : std_logic_vector(23 downto 0);
    signal stripe_dval_out         : std_logic_vector(num_chan-1 downto 0);
    signal stripe_dval_1st_out     : std_logic_vector(num_chan-1 downto 0);
    signal stripe_dval_last_out    : std_logic_vector(num_chan-1 downto 0);
    signal fault_bad_res           : std_logic;
    signal any_write_in_progress   : std_logic;
    signal write_in_progress       : std_logic_vector(num_chan-1 downto 0);
    signal write_fault             : std_logic_vector(num_chan-1 downto 0);
    signal enc_ready               : std_logic_vector(num_chan-1 downto 0);
    signal all_enc_ready           : std_logic;
    signal start_read              : std_logic_vector(num_chan-1 downto 0);
    signal end_read                : std_logic_vector(num_chan-1 downto 0);
    signal read_channel            : std_logic_vector(1 downto 0);
    signal write_channel           : std_logic_vector(1 downto 0);
    signal end_write               : std_logic;
    signal img_base_addr           : slv32d_array(num_chan-1 downto 0);
    signal reg_rdata               : slv32d_array(0 to 4*num_chan-1);
    signal reg_wdata               : slv32d_array(0 to 4*num_chan-1);
    signal reg_wpulse              : std_logic_vector(0 to 4*num_chan-1);

begin

    rst_enc_n <= not rst_enc;

    -- RGB to YCbCr
    colorspace_conv_inst : entity work.colorspace_conv
        port map (
            clk           => clk_px,         -- in  std_logic;
            rst           => rst_px,         -- in  std_logic;
            vid_data_in   => vid_data_in,    -- in  std_logic_vector(23 downto 0);
            vid_dval_in   => vid_dval_in,    -- in  std_logic;
            vid_hsync_in  => vid_hsync_in,   -- in  std_logic;
            vid_vsync_in  => vid_vsync_in,   -- in  std_logic;
            vid_data_out  => vid_data_csc,   -- out std_logic_vector(23 downto 0);
            vid_dval_out  => vid_dval_csc,   -- out std_logic;
            vid_hsync_out => vid_hsync_csc,  -- out std_logic;
            vid_vsync_out => vid_vsync_csc   -- out std_logic
            );

    image_shim_inst : entity work.image_shim
        port map (
            clk                    => clk_px,                  -- in  std_logic;
            rst                    => rst_px,                  -- in  std_logic;
            vid_data_in            => vid_data_csc,            -- in  std_logic_vector(23 downto 0);
            vid_dval_in            => vid_dval_csc,            -- in  std_logic;
            vid_hsync_pos          => vid_hsync_csc,           -- in  std_logic;
            vid_vsync_pos          => vid_vsync_csc,           -- in  std_logic;
            downstream_ready       => all_enc_ready,           -- in  std_logic;
            vid_res_x              => vid_res_x,               -- in  std_logic_vector(15 downto 0);
            vid_res_y              => vid_res_y,               -- in  std_logic_vector(15 downto 0);
            vid_data_out           => vid_data_shim,           -- out std_logic_vector(23 downto 0);
            vid_dval_out           => vid_dval_shim,           -- out std_logic;
            vid_dval_out_1st       => vid_dval_shim_1st,       -- out std_logic;
            vid_dval_out_last      => vid_dval_shim_last,      -- out std_logic;
            vid_dval_out_1st_early => vid_dval_shim_1st_early  -- out std_logic  -- 16 cycles ahead of vid_dval_1st
            );

    image_stripe_inst : entity work.image_stripe
        generic map (
            num_chan => num_chan                          -- integer := 4
            )
        port map (
            clk              => clk_px,                   -- in  std_logic;
            rst              => rst_px,                   -- in  std_logic;
            res_x_in         => vid_res_x,                -- in  std_logic_vector(15 downto 0);
            res_y_in         => vid_res_y,                -- in  std_logic_vector(15 downto 0);
            img_start_in     => vid_dval_shim_1st_early,  -- in  std_logic;
            px_data_in       => vid_data_shim,            -- in  std_logic_vector(23 downto 0);
            px_dval_in       => vid_dval_shim,            -- in  std_logic;  -- assumed to be continually high for each line
            res_x_out        => stripe_x_out,             -- out slv16d_array(num_chan-1 downto 0);
            res_y_out        => stripe_y_out,             -- out std_logic_vector(15 downto 0);
            res_x_nopad_out  => stripe_x_nopad_out,       -- out slv16d_array(num_chan-1 downto 0);
            res_y_nopad_out  => stripe_y_nopad_out,       -- out std_logic_vector(15 downto 0);
            img_start_out    => stripe_start_out,         -- out std_logic;
            px_data_out      => stripe_data_out,          -- out std_logic_vector(23 downto 0);
            px_dval_out      => stripe_dval_out,          -- out std_logic_vector(num_chan-1 downto 0);
            px_dval_1st_out  => stripe_dval_1st_out,      -- out std_logic_vector(num_chan-1 downto 0);
            px_dval_last_out => stripe_dval_last_out,     -- out std_logic_vector(num_chan-1 downto 0);
            fault_bad_res    => fault_bad_res             -- out std_logic
            );

    gen_encoders : for i in 0 to num_chan-1 generate
    begin
        buffered_encoder_inst : entity work.buffered_encoder
            port map (
                clk_px            => clk_px,                   -- in  std_logic;
                rst_px            => rst_px,                   -- in  std_logic;
                res_x_in          => stripe_x_out(i),          -- in  std_logic_vector(15 downto 0);
                res_y_in          => stripe_y_out,             -- in  std_logic_vector(15 downto 0);
                res_x_nopad_in    => stripe_x_nopad_out(i),    -- in  std_logic_vector(15 downto 0);
                res_y_nopad_in    => stripe_y_nopad_out,       -- in  std_logic_vector(15 downto 0);
                img_start_in      => stripe_start_out,         -- in  std_logic;
                img_base_addr     => img_base_addr(i),         -- in  std_logic_vector(31 downto 0);
                px_data_in        => stripe_data_out,          -- in  std_logic_vector(23 downto 0);
                px_dval_in        => stripe_dval_out(i),       -- in  std_logic;
                px_dval_1st_in    => stripe_dval_1st_out(i),   -- in  std_logic;  -- first pixel in image
                px_dval_last_in   => stripe_dval_last_out(i),  -- in  std_logic;  -- last pixel in image
                this_enc_ready    => enc_ready(i),             -- out std_logic;
                clk_enc           => clk_enc,                  -- in  std_logic;
                rst_enc           => rst_enc,                  -- in  std_logic;
                px_stable         => px_stable,                -- in  std_logic;
                write_in_progress => write_in_progress(i),     -- out std_logic;
                write_fault       => write_fault(i),           -- out std_logic;
                M_AXI_OUT         => enc_m_axi_out(i),         -- out axi4_mout_sin;
                M_AXI_IN          => enc_m_axi_in(i)           -- in  axi4_min_sout
                );
    end generate gen_encoders;

    all_enc_ready <= and_reduce(enc_ready) when rising_edge(clk_px);

    triple_frame_buffer_controller_inst : entity work.triple_frame_buffer_controller
        generic map (
            num_chan => num_chan             -- positive := 4
            )
        port map (
            clk           => clk_enc,        -- in  std_logic;
            rst           => rst_enc,        -- in  std_logic;
            start_read    => start_read,     -- in  std_logic_vector(num_chan-1 downto 0);
            end_read      => end_read,       -- in  std_logic_vector(num_chan-1 downto 0);
            read_channel  => read_channel,   -- out std_logic_vector(1 downto 0);  -- 00: none locked, 01 - 11: locked channel
            write_channel => write_channel,  -- out std_logic_vector(1 downto 0);  -- 01 - 11: write channel
            end_write     => end_write       -- in  std_logic
            );

    -- TODO parameterize with num_chan (currently hard coded for num_chan=4)
    axi4lite_reg_file_inst : entity work.axi4lite_reg_file
        generic map (
            G_S_AXI_NUM_REGISTERS => 4*num_chan,         -- integer          := 4;
            G_S_AXI_REG_IS_STATUS => "0001000100010001"  -- std_logic_vector := "0000"               -- if G_S_AXI_REG_IS_STATUS(i) = '1', register i will be read from reg_rdata(i)
            )
        port map (
            -- AXI4-Lite Bus
            S_AXI_ACLK    => clk_enc,                    -- in  std_logic;
            S_AXI_ARESETN => rst_enc_n,                  -- in  std_logic;
            S_AXI_IN      => reg_s_axi_in,               -- in  axi4lite_mout_sin;
            S_AXI_OUT     => reg_s_axi_out,              -- out axi4lite_min_sout;
            -- register interface to/from fabric logic
            reg_rdata     => reg_rdata,                  -- in  slv32d_array(0 to G_S_AXI_NUM_REGISTERS-1);  -- applicable only for status registers
            reg_wdata     => reg_wdata,                  -- out slv32d_array(0 to G_S_AXI_NUM_REGISTERS-1);
            reg_wpulse    => reg_wpulse                  -- out std_logic_vector(0 to G_S_AXI_NUM_REGISTERS-1)
            );

    -- TODO parameterize with num_chan (currently hard coded for num_chan=4)
    process (clk_enc)
    begin
        if rising_edge(clk_enc) then
            any_write_in_progress <= or_reduce(write_in_progress);
            end_write             <= any_write_in_progress and not or_reduce(write_in_progress);
            capture_wr_done       <= end_write;
            -- stripe 0
            start_read(0)         <= reg_wpulse(0);
            end_read(0)           <= reg_wpulse(1);
            -- stripe 1
            start_read(1)         <= reg_wpulse(4);
            end_read(1)           <= reg_wpulse(5);
            -- stripe 2
            start_read(2)         <= reg_wpulse(8);
            end_read(2)           <= reg_wpulse(9);
            -- stripe 3
            start_read(3)         <= reg_wpulse(12);
            end_read(3)           <= reg_wpulse(13);
            case read_channel is
                when "01" =>
                    reg_rdata(3)  <= x"38000000";
                    reg_rdata(7)  <= x"38400000";
                    reg_rdata(11) <= x"38800000";
                    reg_rdata(15) <= x"38C00000";
                when "10" =>
                    reg_rdata(3)  <= x"39000000";
                    reg_rdata(7)  <= x"39400000";
                    reg_rdata(11) <= x"39800000";
                    reg_rdata(15) <= x"39C00000";
                when "11" =>
                    reg_rdata(3)  <= x"3A000000";
                    reg_rdata(7)  <= x"3A400000";
                    reg_rdata(11) <= x"3A800000";
                    reg_rdata(15) <= x"3AC00000";
                when others =>
                    reg_rdata(3)  <= x"DEFEC8ED";
                    reg_rdata(7)  <= x"DEFEC8ED";
                    reg_rdata(11) <= x"DEFEC8ED";
                    reg_rdata(15) <= x"DEFEC8ED";
            end case;
            case write_channel is
                when "01" =>
                    img_base_addr(0) <= x"38000000";
                    img_base_addr(1) <= x"38400000";
                    img_base_addr(2) <= x"38800000";
                    img_base_addr(3) <= x"38C00000";
                when "10" =>
                    img_base_addr(0) <= x"39000000";
                    img_base_addr(1) <= x"39400000";
                    img_base_addr(2) <= x"39800000";
                    img_base_addr(3) <= x"39C00000";
                when others =>
                    img_base_addr(0) <= x"3A000000";
                    img_base_addr(1) <= x"3A400000";
                    img_base_addr(2) <= x"3A800000";
                    img_base_addr(3) <= x"3AC00000";
            end case;
        end if;
    end process;

end rtl;