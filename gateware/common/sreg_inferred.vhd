library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity sreg_inferred is
   generic (
      sreg_width : positive       := 18;                    -- shift register width
      sreg_depth : positive       := 1                      -- shift register depth
      );
   port (
      rst   : in  std_logic := '0';                         -- asynchronous reset
      clk   : in  std_logic;                                -- clock
      en    : in  std_logic := '1';                         -- clock enable
      d     : in  std_logic_vector(sreg_width-1 downto 0);  -- data in
      q     : out std_logic_vector(sreg_width-1 downto 0)   -- data out
      );
end entity sreg_inferred;

architecture rtl of sreg_inferred is

   type sreg_inferred_type is array (natural range <>) of std_logic_vector(sreg_width-1 downto 0);
   signal shift_register : sreg_inferred_type(0 to sreg_depth-1);

begin

   sreg_process : process(clk, rst)
   begin
      if rising_edge(clk) then
         if en = '1' then
            for i in 0 to sreg_depth-1 loop
               if i = 0 then
                  shift_register(i) <= d;
               else
                  shift_register(i) <= shift_register(i-1);
               end if;
            end loop;
         end if;
      end if;
      if rst = '1' then
         shift_register <= (others => (others => '0'));
      end if;
   end process sreg_process;
   
   q <= shift_register(sreg_depth-1);

end architecture rtl;
