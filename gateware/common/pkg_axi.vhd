library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pkg_axi is

   type axi4_mout_sin is record
      araddr   : std_logic_vector(31 downto 0);
      arburst  : std_logic_vector(1 downto 0);
      arcache  : std_logic_vector(3 downto 0);
      arlen    : std_logic_vector(7 downto 0);
      arlock   : std_logic_vector(0 to 0);
      arprot   : std_logic_vector(2 downto 0);
      arqos    : std_logic_vector(3 downto 0);
      arregion : std_logic_vector(3 downto 0);
      arsize   : std_logic_vector(2 downto 0);
      arvalid  : std_logic;
      awaddr   : std_logic_vector(31 downto 0);
      awburst  : std_logic_vector(1 downto 0);
      awcache  : std_logic_vector(3 downto 0);
      awlen    : std_logic_vector(7 downto 0);
      awlock   : std_logic_vector(0 to 0);
      awprot   : std_logic_vector(2 downto 0);
      awqos    : std_logic_vector(3 downto 0);
      awregion : std_logic_vector(3 downto 0);
      awsize   : std_logic_vector(2 downto 0);
      awvalid  : std_logic;
      bready   : std_logic;
      rready   : std_logic;
      wdata    : std_logic_vector(63 downto 0);
      wlast    : std_logic;
      wstrb    : std_logic_vector(7 downto 0);
      wvalid   : std_logic;
   end record;

   constant axi4_mout_sin_zero : axi4_mout_sin := (
      araddr   => (others => '0'),
      arburst  => (others => '0'),
      arcache  => (others => '0'),
      arlen    => (others => '0'),
      arlock   => (others => '0'),
      arprot   => (others => '0'),
      arqos    => (others => '0'),
      arregion => (others => '0'),
      arsize   => (others => '0'),
      arvalid  => '0',
      awaddr   => (others => '0'),
      awburst  => (others => '0'),
      awcache  => (others => '0'),
      awlen    => (others => '0'),
      awlock   => (others => '0'),
      awprot   => (others => '0'),
      awqos    => (others => '0'),
      awregion => (others => '0'),
      awsize   => (others => '0'),
      awvalid  => '0',
      bready   => '0',
      rready   => '0',
      wdata    => (others => '0'),
      wlast    => '0',
      wstrb    => (others => '0'),
      wvalid   => '0'
      );

   type axi4_min_sout is record
      arready : std_logic;
      awready : std_logic;
      bresp   : std_logic_vector(1 downto 0);
      bvalid  : std_logic;
      rdata   : std_logic_vector(63 downto 0);
      rlast   : std_logic;
      rresp   : std_logic_vector(1 downto 0);
      rvalid  : std_logic;
      wready  : std_logic;
   end record;

   constant axi4_min_sout_zero : axi4_min_sout := (
      arready => '0',
      awready => '0',
      bresp   => (others => '0'),
      bvalid  => '0',
      rdata   => (others => '0'),
      rlast   => '0',
      rresp   => (others => '0'),
      rvalid  => '0',
      wready  => '0'
      );

   type axi4lite_mout_sin is record
      awaddr  : std_logic_vector(31 downto 0);
      awprot  : std_logic_vector(2 downto 0);
      awvalid : std_logic;
      wdata   : std_logic_vector(31 downto 0);
      wstrb   : std_logic_vector(3 downto 0);
      wvalid  : std_logic;
      bready  : std_logic;
      araddr  : std_logic_vector(31 downto 0);
      arprot  : std_logic_vector(2 downto 0);
      arvalid : std_logic;
      rready  : std_logic;
   end record;

   constant axi4lite_mout_sin_zero : axi4lite_mout_sin := (
      awaddr  => (others => '0'),
      awprot  => (others => '0'),
      awvalid => '0',
      wdata   => (others => '0'),
      wstrb   => (others => '0'),
      wvalid  => '0',
      bready  => '0',
      araddr  => (others => '0'),
      arprot  => (others => '0'),
      arvalid => '0',
      rready  => '0'
      );

   type axi4lite_min_sout is record
      awready : std_logic;
      wready  : std_logic;
      bresp   : std_logic_vector(1 downto 0);
      bvalid  : std_logic;
      arready : std_logic;
      rdata   : std_logic_vector(31 downto 0);
      rresp   : std_logic_vector(1 downto 0);
      rvalid  : std_logic;
   end record;

   constant axi4lite_min_sout_zero : axi4lite_min_sout := (
      awready => '0',
      wready  => '0',
      bresp   => (others => '0'),
      bvalid  => '0',
      arready => '0',
      rdata   => (others => '0'),
      rresp   => (others => '0'),
      rvalid  => '0'
      );

   type axi4_mout_sin_array is array (natural range <>) of axi4_mout_sin;
   type axi4_min_sout_array is array (natural range <>) of axi4_min_sout;

end package;

package body pkg_axi is
end package body;