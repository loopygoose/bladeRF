--
-- (c) Distributed Radio Limited 2016
--     steve@distributedradio.com
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.btle_common.all;

entity btle_aa_detector is
	port(
		clock:			in std_logic;
		reset:			in std_logic;

		-- input signal
		in_seq:			in std_logic;
		in_valid:       in std_logic;

		-- output bits
		out_seq:		out std_logic;
		out_valid:		out std_logic;
		out_detect:		out std_logic
	);
end btle_aa_detector;


architecture rtl of btle_aa_detector is
begin
	aa_detector:
	process(clock, reset) is

		variable memory: std_logic_vector (BTLE_PREAMBLE_LEN + BTLE_AA_LEN - 1 downto 0);
	
		begin
			if reset = '1' then

				memory := (others => '0');
				out_detect <= '0';
				
			elsif rising_edge(clock) then

				out_detect <= '0';
				out_valid <= in_valid;
				out_seq <= in_seq;
				
				if in_valid = '1' then
	
					-- > Shift memory
					-- > Add new bit
					-- > Check correlation

					memory := memory(BTLE_PREAMBLE_LEN + BTLE_AA_LEN - 2 downto 0) & in_seq;

					if memory = BTLE_BED6 then
						out_detect <= '1';
					end if;					
				end if;
			end if;
		end
	process;
end rtl;
