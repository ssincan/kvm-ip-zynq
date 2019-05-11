--------------------------------------------------------------------------------
--                                                                            --
--                          V H D L    F I L E                                --
--                          COPYRIGHT (C) 2009                                --
--                                                                            --
--------------------------------------------------------------------------------
--                                                                            --
-- Title       : DIVIDER                                                      --
-- Design      : Divider using reciprocal table                               --
-- Author      : Michal Krepa                                                 --
--                                                                            --
--------------------------------------------------------------------------------
--                                                                            --
-- File        : R_DIVIDER.VHD                                                --
-- Created     : Wed 18-03-2009                                               --
--                                                                            --
--------------------------------------------------------------------------------
--                                                                            --
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- MAIN DIVIDER top level
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity r_divider is
  port
    (
      rst : in std_logic;
      clk : in std_logic;
      a   : in std_logic_vector(11 downto 0);
      d   : in std_logic_vector(7 downto 0);

      q : out std_logic_vector(11 downto 0)
      );
end r_divider;

architecture rtl of r_divider is

  signal romr_datao    : std_logic_vector(15 downto 0);
  signal romr_addr     : std_logic_vector(7 downto 0);
  signal dividend      : signed(11 downto 0);
  signal dividend_d1   : signed(11 downto 0);
  signal dividend_d2   : signed(11 downto 0);
  signal reciprocal    : signed(16 downto 0);
  signal reciprocal_d1 : signed(16 downto 0);
  signal mult_out      : signed(28 downto 0);
  signal mult_out_s    : signed(11 downto 0);
  signal signbit       : std_logic;
  signal signbit_d1    : std_logic;
  signal signbit_d2    : std_logic;
  signal signbit_d3    : std_logic;
  signal round         : std_logic;

begin

  U_ROMR : entity work.ROMR
    generic map
    (
      ROMADDR_W => 8,
      ROMDATA_W => 16
      )
    port map
    (
      addr  => romr_addr,
      clk   => CLK,
      datao => romr_datao
      );

  romr_addr <= d;

  process(clk, rst)
  begin
    if rising_edge(clk) then
      reciprocal    <= signed('0'&romr_datao);
      reciprocal_d1 <= reciprocal;
      dividend      <= signed(a);
    end if;
    if rst = '1' then
      reciprocal <= (others => '0');
    end if;
  end process;
  signbit <= dividend(dividend'high);

  rdiv : process(clk, rst)
  begin
    if clk = '1' and clk'event then
      signbit_d1  <= signbit;
      signbit_d2  <= signbit_d1;
      signbit_d3  <= signbit_d2;
      dividend_d1 <= dividend;
      dividend_d2 <= dividend_d1;

      mult_out <= dividend_d2 * reciprocal_d1;

      mult_out_s <= resize(mult_out(27 downto 16), mult_out_s'length);
      round      <= mult_out(15);

      if round = '1' then
        q <= std_logic_vector(mult_out_s + 1);
      else
        q <= std_logic_vector(mult_out_s);
      end if;

      if rst = '1' then
        mult_out    <= (others => '0');
        dividend_d1 <= (others => '0');
        q           <= (others => '0');
        signbit_d1  <= '0';
        signbit_d2  <= '0';
        signbit_d3  <= '0';
      end if;
    end if;
    if rst = '1' then
      mult_out_s <= (others => '0');
      round      <= '0';
    end if;
  end process;

end rtl;
