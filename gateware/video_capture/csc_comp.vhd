library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity csc_comp is
    port (
        clk   : in  std_logic;
        rst   : in  std_logic;
        a_in  : in  std_logic_vector(17 downto 0);
        b_in  : in  std_logic_vector(17 downto 0);
        c_in  : in  std_logic_vector(17 downto 0);
        x_in  : in  std_logic_vector(17 downto 0);
        y_in  : in  std_logic_vector(17 downto 0);
        z_in  : in  std_logic_vector(17 downto 0);
        t_in  : in  std_logic_vector(47 downto 0);
        p_out : out std_logic_vector(47 downto 0)  -- p=a*x+b*y+c*z+t, 4 cycle latency
        );
end csc_comp;

architecture rtl of csc_comp is

    signal a_p1    : signed(a_in'range);
    signal x_p1    : signed(x_in'range);
    signal t_p1    : signed(t_in'range);
    signal ax_t_p2 : signed(p_out'range);

    signal b_p1       : signed(b_in'range);
    signal y_p1       : signed(y_in'range);
    signal by_p2      : signed(b_in'length+y_in'length-1 downto 0);
    signal ax_by_t_p3 : signed(p_out'range);

    signal c_p1          : signed(c_in'range);
    signal z_p1          : signed(z_in'range);
    signal c_p2          : signed(c_in'range);
    signal z_p2          : signed(z_in'range);
    signal cz_p3         : signed(c_in'length+z_in'length-1 downto 0);
    signal ax_by_cz_t_p4 : signed(p_out'range);

begin

    -- DSP cascade of length 3, behavioral implementation
    process (clk)
    begin
        if rising_edge(clk) then

            -- DSP1
            a_p1    <= signed(a_in);                                                        -- A/B reg
            x_p1    <= signed(x_in);                                                        -- A/B reg
            t_p1    <= signed(t_in);                                                        -- C reg
            ax_t_p2 <= resize(t_p1, ax_t_p2'length) + resize(a_p1 * x_p1, ax_t_p2'length);  -- P reg

            -- DSP2, ax_t_p2 is PCIN
            b_p1       <= signed(b_in);                                -- A/B reg
            y_p1       <= signed(y_in);                                -- A/B reg
            by_p2      <= b_p1 * y_p1;                                 -- M reg
            ax_by_t_p3 <= ax_t_p2 + resize(by_p2, ax_by_t_p3'length);  -- P reg

            -- DSP3, ax_by_t_p3 is PCIN
            c_p1          <= signed(c_in);                                      -- A/B reg stage 1
            z_p1          <= signed(z_in);                                      -- A/B reg stage 1
            c_p2          <= c_p1;                                              -- A/B reg stage 2
            z_p2          <= z_p1;                                              -- A/B reg stage 2
            cz_p3         <= c_p2 * z_p2;                                       -- M reg
            ax_by_cz_t_p4 <= ax_by_t_p3 + resize(cz_p3, ax_by_cz_t_p4'length);  -- P reg

        end if;
    end process;

    p_out <= std_logic_vector(ax_by_cz_t_p4);

end rtl;