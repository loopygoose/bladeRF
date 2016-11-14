--
-- (c) Distributed Radio Limited 2016
--     steve@distributedradio.com
--

library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.btle_complex.all;
use work.btle_common.all;


entity btle_channel_receiver is
	generic(
		samples_per_bit : natural := 2
	);
	port(
		clock:			in std_logic;
		reset:			in std_logic;

		in_real:		in signed(15 downto 0);
		in_imag:		in signed(15 downto 0);
		in_valid:       in std_logic;

		in_cts:         in std_logic;
		out_rts:        out std_logic;
		
		out_detected:   buffer std_logic;
		out_real:		out signed(15 downto 0);
		out_imag:		out signed(15 downto 0);
		out_valid:      out std_logic
	);
end btle_channel_receiver;


architecture rtl of btle_channel_receiver is

	type ch_state_type is ( STATE_WAIT_DETECT, STATE_WAIT_CTS, STATE_COUNTDOWN );
	signal state : ch_state_type;

	signal iq_to_mem : 					std_logic_vector(31 downto 0) := (others => '0');
	signal iq_to_mem_wr_addr :			unsigned(9 downto 0) := (others => '0');
	signal iq_to_mem_valid : 			std_logic := '0';

	signal iq_from_mem : 				std_logic_vector(31 downto 0) := (others => '0');
	signal iq_from_mem_rd_addr :		unsigned(9 downto 0) := (others => '0');

    signal bits: std_logic := '0';
    signal bits_valid: std_logic := '0';
    signal detection : std_logic := '0';

begin

	iq_memory:
	entity work.btle_dpram
	port map(
		clock			=> 	clock,
		reset			=>	reset,	
		in_wr_data		=> 	iq_to_mem,
		in_wr_addr		=>	iq_to_mem_wr_addr,
		in_wr_en		=>	iq_to_mem_valid,
		in_rd_addr		=>	iq_from_mem_rd_addr,
		out_rd_data		=>  iq_from_mem
	);

	demod: 
	entity work.btle_demod_matched 
	port map (
    	clock => clock,
    	reset => reset,
        in_real => in_real,
        in_imag => in_imag,
        in_valid => in_valid,
        out_bit => bits,
        out_valid => bits_valid
  	);

   	detect: 
   	entity work.btle_aa_detector 
   	port map (
    	clock => clock,
    	reset => reset,
		in_bit => bits,
		in_valid => bits_valid,
		out_detect => detection
	);

	detector:
	process(clock, reset)
		begin
			if reset = '1' then
				out_detected <= '0';
			elsif rising_edge(clock) then
				out_detected <= detection;
			end if;
		end
	process;

	memory_in: 
	process(clock, reset) is
		begin
			if reset = '1' then

				iq_to_mem <= (others => '0');
				iq_to_mem_wr_addr <= (others => '0');
	 			iq_to_mem_valid <= '0';
	
			elsif rising_edge(clock) then

				iq_to_mem_valid <= '0';

				if in_valid = '1' then		
					
 					iq_to_mem <=  std_logic_vector(in_real & in_imag);
					iq_to_mem_valid <= '1';

					if iq_to_mem_wr_addr = 1023 then
						iq_to_mem_wr_addr <= to_unsigned(0, iq_to_mem_wr_addr'length);
					else
						iq_to_mem_wr_addr <= iq_to_mem_wr_addr + 1;
					end if;
				end if;				
			end if;
		end 
	process;


	state_fsm:
	process(clock, reset) is

		variable sample_pairs_count : integer := 0;
		begin

			if reset = '1' then
			
				out_rts <= '0';
				out_real <= (others => '0');
				out_imag <= (others => '0');
				out_valid <= '0';
				iq_from_mem_rd_addr <= (others => '0');
				
				state <= STATE_WAIT_DETECT;
				
			elsif rising_edge(clock) then
					
				case state is
					when STATE_WAIT_DETECT =>

						out_rts <= '0';
						out_real <= (others => '0');
						out_imag <= (others => '0');
						out_valid <= '0';
						
						if detection = '1' then

							iq_from_mem_rd_addr <= (iq_to_mem_wr_addr + 1024 - BTLE_DEMOD_TAP_POSITION) mod 1024;
							out_rts <= '1';
							state <= STATE_WAIT_CTS;
	
						end if;

					when STATE_WAIT_CTS =>

						out_rts <= '1';
						out_real <= (others => '0');
						out_imag <= (others => '0');
						out_valid <= '0';	

						if in_cts = '1' then
						
							out_real <= x"AAAA";
							out_imag <= x"5555";
							out_valid <= '1';
							state <= STATE_COUNTDOWN;

 							sample_pairs_count := 1;
						end if;

					when STATE_COUNTDOWN =>

						out_rts <= '1';
						out_valid <= '0';

						if sample_pairs_count <= BTLE_MEMORY_LEN then

							if iq_from_mem_rd_addr /= iq_to_mem_wr_addr then
							
								out_real <= signed(iq_from_mem (31 downto 16));
								out_imag <= signed(iq_from_mem (15 downto  0));
								out_valid <= '1';

								sample_pairs_count := sample_pairs_count + 1;

								if iq_from_mem_rd_addr = 1023 then
									iq_from_mem_rd_addr <= to_unsigned(0, iq_from_mem_rd_addr'length) ;
								else
									iq_from_mem_rd_addr <= iq_from_mem_rd_addr + 1;
								
								end if;
								
							end if;

						elsif sample_pairs_count < 1024 then

							out_real <= (others => '0');
							out_imag <= (others => '0');
							out_valid <= '1';

							sample_pairs_count := sample_pairs_count + 1;

						else
						
							sample_pairs_count := 0;
							state <= STATE_WAIT_DETECT;

						end if;

					when others =>
					
						out_rts <= '0';
						out_real <= (others => '0');
						out_imag <= (others => '0');
						out_valid <= '0';
						state <= STATE_WAIT_DETECT;
				
				end case;

			end if;
		end
	process;

	
end rtl;




