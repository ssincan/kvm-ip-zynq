library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

entity colorspace_conv is
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        vid_data_in   : in  std_logic_vector(23 downto 0);
        vid_dval_in   : in  std_logic;
        vid_hsync_in  : in  std_logic;
        vid_vsync_in  : in  std_logic;
        vid_data_out  : out std_logic_vector(23 downto 0);
        vid_dval_out  : out std_logic;
        vid_hsync_out : out std_logic;
        vid_vsync_out : out std_logic
        );
end colorspace_conv;

architecture rtl of colorspace_conv is

    constant C_Y_1  : std_logic_vector(17 downto 0) := std_logic_vector(to_signed(4899, 18));
    constant C_Y_2  : std_logic_vector(17 downto 0) := std_logic_vector(to_signed(9617, 18));
    constant C_Y_3  : std_logic_vector(17 downto 0) := std_logic_vector(to_signed(1868, 18));
    constant C_Cb_1 : std_logic_vector(17 downto 0) := std_logic_vector(to_signed(-2764, 18));
    constant C_Cb_2 : std_logic_vector(17 downto 0) := std_logic_vector(to_signed(-5428, 18));
    constant C_Cb_3 : std_logic_vector(17 downto 0) := std_logic_vector(to_signed(8192, 18));
    constant C_Cr_1 : std_logic_vector(17 downto 0) := std_logic_vector(to_signed(8192, 18));
    constant C_Cr_2 : std_logic_vector(17 downto 0) := std_logic_vector(to_signed(-6860, 18));
    constant C_Cr_3 : std_logic_vector(17 downto 0) := std_logic_vector(to_signed(-1332, 18));
    constant t_zero : std_logic_vector(47 downto 0) := (others => '0');
    constant t_CbCr : std_logic_vector(47 downto 0) := std_logic_vector(to_signed(128*(2**14), 48));
    signal R_s      : std_logic_vector(17 downto 0);
    signal G_s      : std_logic_vector(17 downto 0);
    signal B_s      : std_logic_vector(17 downto 0);
    signal Y_dsp    : std_logic_vector(47 downto 0);
    signal Cb_dsp   : std_logic_vector(47 downto 0);
    signal Cr_dsp   : std_logic_vector(47 downto 0);

begin

    sreg_inferred_inst : entity work.sreg_inferred
        generic map (
            sreg_width => 3,         -- positive       := 18;                    -- shift register width
            sreg_depth => 1+4+1      -- positive       := 1                      -- shift register depth
            )
        port map (
            rst   => '0',            -- in  std_logic := '0';                         -- asynchronous reset
            clk   => clk,            -- in  std_logic;                                -- clock
            en    => '1',            -- in  std_logic := '1';                         -- clock enable
            d(2)  => vid_dval_in,    -- in  std_logic_vector(sreg_width-1 downto 0);  -- data in
            d(1)  => vid_hsync_in,   -- in  std_logic_vector(sreg_width-1 downto 0);  -- data in
            d(0)  => vid_vsync_in,   -- in  std_logic_vector(sreg_width-1 downto 0);  -- data in
            q(2)  => vid_dval_out,   -- out std_logic_vector(sreg_width-1 downto 0)   -- data out
            q(1)  => vid_hsync_out,  -- out std_logic_vector(sreg_width-1 downto 0)   -- data out
            q(0)  => vid_vsync_out   -- out std_logic_vector(sreg_width-1 downto 0)   -- data out
            );

    process (clk, rst)
    begin
        if rising_edge(clk) then
            R_s                        <= std_logic_vector(resize(signed('0' & vid_data_in(7 downto 0)), R_s'length));
            G_s                        <= std_logic_vector(resize(signed('0' & vid_data_in(15 downto 8)), G_s'length));
            B_s                        <= std_logic_vector(resize(signed('0' & vid_data_in(23 downto 16)), B_s'length));
            vid_data_out(7 downto 0)   <= std_logic_vector(Y_dsp(21 downto 14));
            vid_data_out(15 downto 8)  <= std_logic_vector(Cb_dsp(21 downto 14));
            vid_data_out(23 downto 16) <= std_logic_vector(Cr_dsp(21 downto 14));
        end if;
        if rst = '1' then
            -- prevent absorbtion of these registers into DSPs
            R_s          <= (others => '0');
            G_s          <= (others => '0');
            B_s          <= (others => '0');
            vid_data_out <= (others => '0');
        end if;
    end process;

    csc_comp_Y : entity work.csc_comp
        port map (
            clk   => clk,     -- in  std_logic;
            rst   => rst,     -- in  std_logic;
            a_in  => R_s,     -- in  std_logic_vector(17 downto 0);
            b_in  => G_s,     -- in  std_logic_vector(17 downto 0);
            c_in  => B_s,     -- in  std_logic_vector(17 downto 0);
            x_in  => C_Y_1,   -- in  std_logic_vector(17 downto 0);
            y_in  => C_Y_2,   -- in  std_logic_vector(17 downto 0);
            z_in  => C_Y_3,   -- in  std_logic_vector(17 downto 0);
            t_in  => t_zero,  -- in  std_logic_vector(47 downto 0);
            p_out => Y_dsp    -- out std_logic_vector(47 downto 0)
            );

    csc_comp_Cb : entity work.csc_comp
        port map (
            clk   => clk,     -- in  std_logic;
            rst   => rst,     -- in  std_logic;
            a_in  => R_s,     -- in  std_logic_vector(17 downto 0);
            b_in  => G_s,     -- in  std_logic_vector(17 downto 0);
            c_in  => B_s,     -- in  std_logic_vector(17 downto 0);
            x_in  => C_Cb_1,  -- in  std_logic_vector(17 downto 0);
            y_in  => C_Cb_2,  -- in  std_logic_vector(17 downto 0);
            z_in  => C_Cb_3,  -- in  std_logic_vector(17 downto 0);
            t_in  => t_CbCr,  -- in  std_logic_vector(47 downto 0);
            p_out => Cb_dsp   -- out std_logic_vector(47 downto 0)
            );

    csc_comp_Cr : entity work.csc_comp
        port map (
            clk   => clk,     -- in  std_logic;
            rst   => rst,     -- in  std_logic;
            a_in  => R_s,     -- in  std_logic_vector(17 downto 0);
            b_in  => G_s,     -- in  std_logic_vector(17 downto 0);
            c_in  => B_s,     -- in  std_logic_vector(17 downto 0);
            x_in  => C_Cr_1,  -- in  std_logic_vector(17 downto 0);
            y_in  => C_Cr_2,  -- in  std_logic_vector(17 downto 0);
            z_in  => C_Cr_3,  -- in  std_logic_vector(17 downto 0);
            t_in  => t_CbCr,  -- in  std_logic_vector(47 downto 0);
            p_out => Cr_dsp   -- out std_logic_vector(47 downto 0)
            );

end rtl;