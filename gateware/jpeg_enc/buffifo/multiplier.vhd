----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    12:18:01 03/12/2011 
-- Design Name: 
-- Module Name:    multiplier - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;




-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;
library UNIMACRO;
use UNIMACRO.Vcomponents.all;
entity multiplier is
    port (
        CLK        : in std_logic;
        RST        : in std_logic;
        -- 
        img_size_x : in std_logic_vector(15 downto 0);
        img_size_y : in std_logic_vector(15 downto 0);

        --
        result : out std_logic_vector(31 downto 0)
        );
end multiplier;

architecture Behavioral of multiplier is

    signal A : std_logic_vector(18-1 downto 0);
    signal B : std_logic_vector(18-1 downto 0);
    signal P : std_logic_vector(18+18-1 downto 0);

begin

    A      <= "00" & img_size_x;
    B      <= "00" & img_size_y;
    result <= P(result'range);

    MULT_MACRO_inst : MULT_MACRO
        generic map (
            DEVICE  => "7SERIES",       -- Target Device: "VIRTEX5", "7SERIES", "SPARTAN6"
            LATENCY => 3,               -- Desired clock cycle latency, 0-4
            WIDTH_A => 18,              -- Multiplier A-input bus width, 1-25
            WIDTH_B => 18)              -- Multiplier B-input bus width, 1-18
        port map (
            P   => P,                   -- Multiplier output bus, width determined by WIDTH_P generic
            A   => A,                   -- Multiplier input A bus, width determined by WIDTH_A generic
            B   => B,                   -- Multiplier input B bus, width determined by WIDTH_B generic
            CE  => '1',                 -- 1-bit active high input clock enable
            CLK => CLK,                 -- 1-bit positive edge clock input
            RST => RST                  -- 1-bit input active high reset
            );
end Behavioral;
