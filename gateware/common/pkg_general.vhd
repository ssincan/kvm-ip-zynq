library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package pkg_general is

   -- unconstrained array of positive
   type positive_array is array (natural range <>) of positive;

   -- unconstrained array of boolean
   type boolean_array is array (natural range <>) of boolean;

   -- unconstrained array of real
   type real_array is array (natural range <>) of real;

   -- unconstrained array of std_logic_vector
   type slv16d_array is array (natural range <>) of std_logic_vector(15 downto 0);
   type slv32d_array is array (natural range <>) of std_logic_vector(31 downto 0);
   type slv64d_array is array (natural range <>) of std_logic_vector(63 downto 0);

   -- reduce vector to std_logic using xor
   function xor_reduce (
      vec : std_logic_vector
      ) return std_logic;

   -- reduce vector to std_logic using or
   function or_reduce (
      vec : std_logic_vector
      ) return std_logic;

   -- reduce vector to std_logic using and
   function and_reduce (
      vec : std_logic_vector
      ) return std_logic;

   -- calculate log base 2 of an number, rounding up
   function log2 (
      number : positive
      ) return natural;

   -- calculate bits required to represent a number
   function num_bits (
      number : natural
      ) return natural;

   -- modulo increment
   function inc_mod (
      value            : std_logic_vector;
      constant modulus : positive
      ) return std_logic_vector;

   -- modulo decrement
   function dec_mod (
      value            : std_logic_vector;
      constant modulus : positive
      ) return std_logic_vector;

   -- convert std_logic to number
   function conv_nat (
      sl : std_logic
      ) return natural;

   -- convert boolean to number
   function conv_nat (
      bool : boolean
      ) return natural;

   -- convert boolean to standard logic
   function conv_sl (
      bool : boolean
      ) return std_logic;

   -- pad MSBs of a std_logic_vector with pad_bit
   function pad (
      slv     : std_logic_vector;
      len     : positive;
      pad_bit : std_logic := '0'
      ) return std_logic_vector;

   -- left pad string with pad_chr
   function pad (
      value   : string;
      len     : integer;
      pad_chr : character := '0'
      ) return string;

   -- reverse byte order in SLV
   function byte_reverse (
      din : std_logic_vector
      ) return std_logic_vector;

   -- select a slice from std_logic_vector
   function select_slice (
      source      : std_logic_vector;
      slice_width : positive;
      slice_no    : natural
      ) return std_logic_vector;

   -- count number of '1' in a SLV
   function count_ones (
      vec : std_logic_vector
      ) return natural;

end package;

package body pkg_general is

   -- reduce vector to std_logic using xor
   function xor_reduce (
      vec : std_logic_vector
      ) return std_logic is
      variable result : std_logic := '0';
   begin
      for i in vec'range loop
         result := result xor vec(i);
      end loop;
      return result;
   end function xor_reduce;

   -- reduce vector to std_logic using or
   function or_reduce (
      vec : std_logic_vector
      ) return std_logic is
      variable result : std_logic := '0';
   begin
      for i in vec'range loop
         result := result or vec(i);
      end loop;
      return result;
   end function or_reduce;

   -- reduce vector to std_logic using and
   function and_reduce (
      vec : std_logic_vector
      ) return std_logic is
      variable result : std_logic := '1';
   begin
      for i in vec'range loop
         result := result and vec(i);
      end loop;
      return result;
   end function and_reduce;

   -- calculate log base 2 of a number, rounding up
   function log2 (
      number : positive
      ) return natural is
      variable result : natural;
   begin
      result := 0;
      while (2**result < number) loop
         result := result + 1;
      end loop;
      return result;
   end function log2;

   -- calculate bits required to represent a number
   function num_bits (
      number : natural
      ) return natural is
   begin
      return log2(number+1);
   end function num_bits;

   -- modulo increment
   function inc_mod (
      value            : std_logic_vector;
      constant modulus : positive
      ) return std_logic_vector is
      variable result : std_logic_vector(value'range);
   begin
      if unsigned(value) = modulus-1 then
         result := (others => '0');
      else
         result := std_logic_vector(unsigned(value)+1);
      end if;
      return result;
   end function inc_mod;

   -- modulo decrement
   function dec_mod (
      value            : std_logic_vector;
      constant modulus : positive
      ) return std_logic_vector is
      variable result : std_logic_vector(value'range);
   begin
      if unsigned(value) = 0 then
         result := std_logic_vector(to_unsigned(modulus-1, result'length));
      else
         result := std_logic_vector(unsigned(value)-1);
      end if;
      return result;
   end function dec_mod;

   -- convert std_logic to number
   function conv_nat (
      sl : std_logic
      ) return natural is
      variable result : natural range 0 to 1;
   begin
      result := 0;
      if sl = '1' then
         result := 1;
      end if;
      return result;
   end function conv_nat;

   -- convert boolean to number
   function conv_nat (
      bool : boolean
      ) return natural is
      variable result : natural range 0 to 1;
   begin
      result := 0;
      if bool then
         result := 1;
      end if;
      return result;
   end function conv_nat;

   -- convert boolean to standard logic
   function conv_sl (
      bool : boolean
      ) return std_logic is
      variable result : std_logic;
   begin
      result := '0';
      if bool then
         result := '1';
      end if;
      return result;
   end function conv_sl;

   -- pad MSBs of a std_logic_vector with pad_bit
   function pad (
      slv     : std_logic_vector;
      len     : positive;
      pad_bit : std_logic := '0'
      ) return std_logic_vector is
      variable result : std_logic_vector(len-1 downto 0) := (others => pad_bit);
   begin
      result(slv'length-1 downto 0) := slv;
      return result;
   end pad;

   -- left pad string with pad_chr
   function pad (
      value   : string;
      len     : integer;
      pad_chr : character := '0'
      ) return string is
      constant pad_str : string(1 to 1) := (1 => pad_chr);
   begin
      if value'length >= len then
         return value;
      end if;
      return pad(pad_str & value, len, pad_chr);
   end function pad;

   -- reverse byte order in SLV
   function byte_reverse (
      din : std_logic_vector
      ) return std_logic_vector is
      variable din_v      : std_logic_vector(din'length-1 downto 0);
      variable dout       : std_logic_vector(din'length-1 downto 0);
      constant dout_bytes : integer := dout'length/8;
   begin
      assert din'length = dout_bytes*8 report "Input data is not an integer number of bytes!" severity failure;
      din_v := din;
      for i in dout_bytes-1 downto 0 loop
         dout((i+1)*8-1 downto i*8) := din_v((dout_bytes-i)*8-1 downto (dout_bytes-1-i)*8);
      end loop;
      return dout;
   end function byte_reverse;

   -- select a slice from std_logic_vector
   function select_slice (
      source      : std_logic_vector;
      slice_width : positive;
      slice_no    : natural
      ) return std_logic_vector is
      constant num_slices : natural := source'length / slice_width;
      variable result     : std_logic_vector(slice_width-1 downto 0);
   begin
      result := (others => '0');
      if source'length mod slice_width /= 0 then
         assert false
            report "Slice width must be a divisor of SLV length!"
            severity failure;
         return result;
      end if;
      for i in 0 to num_slices-1 loop
         if i = slice_no then
            result := source((i+1)*slice_width-1 downto i*slice_width);
         end if;
      end loop;
      return result;
   end function select_slice;

   -- count number of '1' in a SLV
   function count_ones (
      vec : std_logic_vector
      ) return natural is
      variable result : natural range 0 to vec'length;
   begin
      result := 0;
      for i in vec'range loop
         result := result + to_integer(unsigned(vec(i downto i)));
      end loop;
      return result;
   end function count_ones;

end package body;