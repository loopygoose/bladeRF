--
-- (c) Distributed Radio Limited 2016
--     steve@distributedradio.com
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.btle_common.all;
use work.btle_channel.all;
use work.btle_window.all;
use work.btle_fft.all;

entity btle_wideband_receiver is
	generic(
		samples_per_bit : natural := 2;
		num_channels : natural := 16
	);
	port(
		clock: 			in std_logic;
		reset:			in std_logic;
		enable:			in std_logic;
		
		in_wb_real:		in signed(15 downto 0);
		in_wb_imag:		in signed(15 downto 0);
		in_wb_valid:	in std_logic;
		in_timestamp:   in unsigned(63 downto 0);

		in_control:		in std_logic_vector(31 downto 0);
		in_connect:		in std_logic_vector(31 downto 0);
		in_crc:			in std_logic_vector(23 downto 0);
		
		out_real:		out signed(15 downto 0);				
		out_imag: 		out signed(15 downto 0);
		out_valid:		out std_logic;
		out_detected:   out std_logic
	);

end btle_wideband_receiver;


architecture rtl of btle_wideband_receiver is

	type bus_array is array(num_channels - 1 downto 0) of sample_t;
	type config_array_t is array (num_channels - 1 downto 0) of aa_crc_config_t;
	
	type wb_state_type is ( 
							STATE_WAIT_RTS, 
							STATE_SENDING );
	signal state : wb_state_type;

	signal wideband_input : iq_bus_t;
	signal fft_output: tdm_iq_bus_t;

	signal demod_iq_input: tdm_iq_bus_t;
	signal demod_bit_output: tdm_bit_bus_t;

	signal mapper_bit_input: tdm_bit_bus_t;
	signal mapper_bit_output: tdm_bit_bus_t;
	signal mapper_ch_output: btle_ch_info_t;

	signal aa_bit_input: tdm_bit_bus_t;
	signal aa_ch_input: btle_ch_info_t;

	signal aa_bit_output: tdm_bit_bus_t;
	signal aa_ch_output: btle_ch_info_t;
	signal aa_detect_results: aa_crc_config_t;

	signal mux_dch_config: 		aa_crc_config_t;
	
	signal ch_out_dch_config: 	config_array_t;
	signal ch_in_cts_dch:		std_logic_vector(num_channels - 1 downto 0);
	signal ch_out_rts_dch:		std_logic_vector(num_channels - 1 downto 0);

	signal ch_in_bit:			std_logic;
	signal ch_in_bit_valid:		std_logic_vector(num_channels - 1 downto 0);

	signal ch_in_aa_detect_results: aa_crc_config_t;
	signal ch_in_aa_detect_valid:	std_logic_vector(num_channels - 1 downto 0);


	signal ch_in_real: 			sample_t;
	signal ch_in_imag: 			sample_t;
	signal ch_in_valid:			std_logic_vector(num_channels - 1 downto 0);
	signal ch_in_cts:			std_logic_vector(num_channels - 1 downto 0);

	signal ch_in_info:			btle_ch_info_t;
	signal ch_in_info_valid:		std_logic_vector(num_channels - 1 downto 0);

	signal ch_out_rts:			std_logic_vector(num_channels - 1 downto 0);
	signal ch_out_real: 		bus_array;
	signal ch_out_imag:			bus_array;
	signal ch_out_valid:    	std_logic_vector(num_channels - 1 downto 0);

	signal rx_timestamp:	unsigned(63 downto 0);
	signal rf_config: 		unsigned (1 downto 0);




--	attribute preserve : boolean;
--	attribute preserve of ch_in_real : signal is true;
--	attribute preserve of ch_in_imag : signal is true;
--	attribute preserve of ch_in_valid : signal is true;
--	attribute preserve of ch_in_cts : signal is true;
--	attribute preserve of ch_out_rts : signal is true;
--	attribute preserve of ch_out_real : signal is true;
--	attribute preserve of ch_out_imag : signal is true;
--	attribute preserve of ch_out_valid : signal is true;
--	attribute preserve of ch_out_detected : signal is true;

--	attribute syn_keep : boolean;
--	attribute syn_keep of ch_in_real : signal is true;
--	attribute syn_keep of ch_in_imag : signal is true;
--	attribute syn_keep of ch_in_valid : signal is true;
--	attribute syn_keep of ch_in_cts : signal is true;
--	attribute syn_keep of ch_out_rts : signal is true;
--	attribute syn_keep of ch_out_real : signal is true;
--	attribute syn_keep of ch_out_imag : signal is true;
--	attribute syn_keep of ch_out_valid : signal is true;
--	attribute syn_keep of ch_out_detected : signal is true;

begin

	rx_timestamp <= in_timestamp;
	rf_config <= unsigned(in_control(1 downto 0));
	
	demod:
	entity work.btle_demod_matched 
		generic map (
			samples_per_bit => samples_per_bit, 
			max_channels => num_channels
		)
		port map (
    		clock 		=> clock,
    		reset 		=> reset,
        	in_iq_bus 	=> demod_iq_input,
        	out_bit_bus => demod_bit_output
  		);

	mapper: entity work.btle_channel_mapper
		generic map (
			max_channels => num_channels
		)
		port map (
			clock		=> clock,
			reset		=> reset,
			rf_config	=> "00", --rf_config,
			in_bit_bus	=> mapper_bit_input,
			out_ch_info	=> mapper_ch_output,
			out_bit_bus	=> mapper_bit_output
		);
			
  	aa_detect: 
   	entity work.btle_aa_detector 
		generic map (
			num_timeslots => num_channels, 
			max_addresses => BTLE_MAXIMUM_AA_MEMORY
		)
   		port map (
    		clock => clock,
    		reset => reset,
    	
			in_bit_bus => aa_bit_input,
			in_ch_info => aa_ch_input,

			in_data_ch_cfg => mux_dch_config,

			out_bit_bus => aa_bit_output,
			out_ch_info => aa_ch_output,
			out_detect_results => aa_detect_results
		);



	demod_to_mapper:
	process(clock, reset) is
		begin
			if reset = '1' then
			
				mapper_bit_input.seq <= '0';
				mapper_bit_input.valid <= '0';
				mapper_bit_input.timeslot <= (others => '0');

			elsif rising_edge(clock) then

				mapper_bit_input <= demod_bit_output;
				
			end if;
		end
	process;	


	mapper_to_aa:
	process(clock, reset) is
		begin
			if reset = '1' then

				aa_bit_input.seq <= '0';
				aa_bit_input.valid <= '0';
				aa_bit_input.timeslot <= (others => '0');

				aa_ch_input.ch_idx <= to_unsigned(BTLE_CHANNEL_INVALID, aa_ch_input.ch_idx'length);
				aa_ch_input.adv <= '0';
				aa_ch_input.valid <= '0';

			elsif rising_edge(clock) then

				aa_bit_input <= mapper_bit_output;
				aa_ch_input <= mapper_ch_output;
					
			end if;
		end
	process;	


	mux_dch_consfig:
	process(clock, reset) is

		variable active_channel: integer := 0;
		variable state_dch: wb_state_type;

		begin
			if reset = '1' then

				mux_dch_config <= ( '0', (others => '0'), (others => '0') );
				ch_in_cts_dch <= (others => '0');

				state_dch := STATE_WAIT_RTS;
					
			elsif rising_edge(clock) then

				mux_dch_config <= ( '0', (others => '0'), (others => '0') );
				ch_in_cts_dch <= (others => '0');

				case state_dch is

					when STATE_WAIT_RTS =>

						for ch in 0 to num_channels - 1 loop

							if ch_out_rts_dch(ch) = '1' then

								ch_in_cts_dch(ch) <= '1';
								active_channel := ch;
								state_dch := STATE_SENDING;

								exit;
								
							end if;
									
						end loop;

					when STATE_SENDING =>

						if ch_out_rts_dch(active_channel) = '1' then
							
							ch_in_cts_dch(active_channel) <= '1';

							if ch_out_dch_config(active_channel).valid = '1' then
							
								mux_dch_config <= ch_out_dch_config(active_channel);
								state_dch := STATE_WAIT_RTS;

							end if;

						else							

							state_dch := STATE_WAIT_RTS;

						end if;

					when others =>

						state_dch := STATE_WAIT_RTS;

				end case;
					
			end if;
		end
	process;


	fft_based: if num_channels > 1 generate

		rx_bank : for i in 0 to num_channels - 1 
		generate

			valid: if btle_channel_get_idx(0, i) /= BTLE_CHANNEL_INVALID generate
		
				ch_rx: entity work.btle_channel_receiver
					generic map (
						samples_per_bit => samples_per_bit
					)
					port map (
						clock 						=> 	clock,
						reset 						=> 	reset,

						in_real 					=> 	ch_in_real,
						in_imag 					=> 	ch_in_imag,
						in_valid 					=> 	ch_in_valid(i),
						in_timestamp 				=>	rx_timestamp,

						in_demod_seq 				=> 	ch_in_bit,
						in_demod_valid 				=>	ch_in_bit_valid(i),
						
						in_cts 						=> 	ch_in_cts(i),
						out_rts 					=>	ch_out_rts(i),

						in_ch_info.valid 			=>	ch_in_info_valid(i),
						in_ch_info.adv				=>	ch_in_info.adv,
						in_ch_info.ch_idx 			=>	ch_in_info.ch_idx,
						
						in_aa_detect.valid 			=> 	ch_in_aa_detect_valid(i),
						in_aa_detect.preamble_aa 	=>	ch_in_aa_detect_results.preamble_aa,
						in_aa_detect.crc_init 		=> 	ch_in_aa_detect_results.crc_init,

						in_rf_config				=>  rf_config,
						in_ch_idx					=>  to_unsigned(btle_channel_get_idx(to_integer(rf_config), i), 6),
						
						in_cts_dch					=>	ch_in_cts_dch(i),
						out_rts_dch					=>	ch_out_rts_dch(i),
						out_dch_config				=> 	ch_out_dch_config(i),

						out_real 					=> 	ch_out_real(i),
						out_imag 					=> 	ch_out_imag(i),
						out_valid 					=> 	ch_out_valid(i)
					);	
			end generate;
		end generate;

		fft : entity work.btle_fft_streamer			
			generic map (
				order => num_channels,
				fft_type => BTLE_FFT_SPIRAL,
				fft_window => BTLE_WINDOW_HAMMING
			)
    		port map (
				clock 			=> clock,
				reset 			=> reset,
				enable			=> enable,
				in_iq_bus 		=> wideband_input,
				out_iq_bus		=> fft_output
    		);


		fft_input:
		process(clock, reset) is
			begin
				if reset = '1' then

					wideband_input.real <= (others => '0');
					wideband_input.imag <= (others => '0');
					wideband_input.valid <= '0';

				elsif rising_edge(clock) then

					wideband_input.real <= in_wb_real;
					wideband_input.imag <= in_wb_imag;
					wideband_input.valid <= in_wb_valid;
					
				end if;
			end
		process;

		fft_to_demod:
		process(clock, reset) is
			begin
				if reset = '1' then

					demod_iq_input.real <= (others => '0');
					demod_iq_input.imag <= (others => '0');
					demod_iq_input.valid <= '0';
					demod_iq_input.timeslot <= (others => '0');

				elsif rising_edge(clock) then

					demod_iq_input <= fft_output;
					
				end if;
			end
		process;	

		aa_to_ch:
		process(clock, reset) is
			begin
				if reset = '1' then

					ch_in_bit <= '0';
					ch_in_bit_valid <= (others => '0');

					ch_in_real <= (others => '0');
					ch_in_imag <= (others => '0');
					ch_in_valid <= (others => '0');
					
					ch_in_aa_detect_results.valid <= '0';
					ch_in_aa_detect_results.preamble_aa <= (others => '0');
					ch_in_aa_detect_results.crc_init <= (others => '0');
					ch_in_aa_detect_valid <= (others => '0');
					
					ch_in_info.valid <= '0';
					ch_in_info.adv <= '0';
					ch_in_info.ch_idx <= to_unsigned(BTLE_CHANNEL_INVALID, ch_in_info.ch_idx'length);
					ch_in_info_valid <= (others => '0');
					
				elsif rising_edge(clock) then

					ch_in_real <= (others => '0');
					ch_in_imag <= (others => '0');
					ch_in_valid <= (others => '0');
					
					if fft_output.valid = '1' then

						ch_in_real <= fft_output.real;
						ch_in_imag <= fft_output.imag;
						ch_in_valid(to_integer(fft_output.timeslot)) <= '1';

					end if;

					ch_in_bit <= '0';
					ch_in_bit_valid <= (others => '0');

					ch_in_aa_detect_results.valid <= '0';
					ch_in_aa_detect_results.preamble_aa <= (others => '0');
					ch_in_aa_detect_results.crc_init <= (others => '0');
					ch_in_aa_detect_valid <= (others => '0');

					ch_in_info.valid <= '0';
					ch_in_info.adv <= '0';
					ch_in_info.ch_idx <= to_unsigned(BTLE_CHANNEL_INVALID, ch_in_info.ch_idx'length);
					ch_in_info_valid <= (others => '0');

					if aa_bit_output.valid = '1' then

						ch_in_bit <= aa_bit_output.seq;
						ch_in_bit_valid(to_integer(aa_bit_output.timeslot)) <= '1';

						if aa_detect_results.valid = '1' then

							ch_in_aa_detect_results <= aa_detect_results;
							ch_in_aa_detect_valid(to_integer(aa_bit_output.timeslot)) <= '1';
							
						end if;

						if aa_ch_output.valid = '1' then

							ch_in_info <= aa_ch_output;
							ch_in_info_valid(to_integer(aa_bit_output.timeslot)) <= '1';

						end if;

					end if;
					
				end if;
			end
		process;

		ch_output:
		process(clock, reset) is

			variable active_channel: integer := 0;
			
			begin
				if reset = '1' then

					ch_in_cts <= (others => '0');
					out_real <= (others => '0');
					out_imag <= (others => '0');
					out_valid <= '0';

					state <= STATE_WAIT_RTS;
					
				elsif rising_edge(clock) then

					ch_in_cts <= (others => '0');
					out_real <= (others => '0');
					out_imag <= (others => '0');
					out_valid <= '0';

					case state is

						when STATE_WAIT_RTS =>

							for ch in 0 to num_channels - 1 loop

								if ch_out_rts(ch) = '1' then

									-- Found channel to send
									-- -> Store and transition

									ch_in_cts(ch) <= '1';
									active_channel := ch;
									state <= STATE_SENDING;
									exit;
									
								end if;
									
							end loop;

						when STATE_SENDING =>

							if ch_out_rts(active_channel) = '1' then

								ch_in_cts(active_channel) <= '1';

								if ch_out_valid(active_channel) = '1' then
						
									out_real <= ch_out_real(active_channel);
									out_imag <= ch_out_imag(active_channel);
									out_valid <= '1';	

								end if;
								
							else

								-- Channel released RTS, so is finished sending
								-- -> Wait for the next one
								
								state <= STATE_WAIT_RTS;

							end if;

						when others =>

							state <= STATE_WAIT_RTS;

					end case;
					
				end if;
			end
		process;

	else generate

		single_rx: entity work.btle_channel_receiver
			generic map(samples_per_bit => samples_per_bit)
			port map(
				clock 						=> 	clock,
				reset 						=> 	reset,

				in_real 					=> 	ch_in_real,
				in_imag 					=> 	ch_in_imag,
				in_valid 					=> 	ch_in_valid(0),
				in_timestamp 				=>	rx_timestamp,

				in_demod_seq 				=> ch_in_bit,
				in_demod_valid 				=> ch_in_bit_valid(0),

				in_cts 						=> 	ch_in_cts(0),
				out_rts 					=>	ch_out_rts(0),

				in_ch_info.valid 			=>	ch_in_info_valid(0),
				in_ch_info.adv				=>	ch_in_info.adv,
				in_ch_info.ch_idx 			=>	ch_in_info.ch_idx,

				in_aa_detect.valid 			=> 	ch_in_aa_detect_valid(0),
				in_aa_detect.preamble_aa 	=>	ch_in_aa_detect_results.preamble_aa,
				in_aa_detect.crc_init 		=> ch_in_aa_detect_results.crc_init,

				in_rf_config				=>  rf_config,
				in_ch_idx 					=>  to_unsigned(37, 6),
				in_cts_dch					=>	ch_in_cts_dch(0),
				out_rts_dch					=>	ch_out_rts_dch(0),
				out_dch_config				=> 	ch_out_dch_config(0),

				out_real 					=> 	ch_out_real(0),
				out_imag 					=> 	ch_out_imag(0),
				out_valid 					=> 	ch_out_valid(0)
			);



		input_to_demod:
		process(clock, reset) is
			begin
				if reset = '1' then

					demod_iq_input.real <= (others => '0');
					demod_iq_input.imag <= (others => '0');
					demod_iq_input.valid <= '0';
					demod_iq_input.timeslot <= (others => '0');

				elsif rising_edge(clock) then

					demod_iq_input.real  <= in_wb_real;
					demod_iq_input.imag  <= in_wb_imag;
					demod_iq_input.valid <= in_wb_valid;
					demod_iq_input.timeslot <= (others => '0');
					
				end if;
			end
		process;


		aa_to_ch:
			process(clock, reset) is
			begin
				if reset = '1' then

					ch_in_real  <= (others => '0');
					ch_in_imag  <= (others => '0');
					ch_in_valid <= (others => '0');
					
					ch_in_bit <='0';
					ch_in_bit_valid(0) <= '0';

					ch_in_aa_detect_results.valid <= '0';
					ch_in_aa_detect_results.preamble_aa <= (others => '0');
					ch_in_aa_detect_results.crc_init <= (others => '0');
					ch_in_aa_detect_valid <= (others => '0');

					ch_in_info.valid <= '0';
					ch_in_info.adv <= '0';
					ch_in_info.ch_idx <= to_unsigned(BTLE_CHANNEL_INVALID, ch_in_info.ch_idx'length);
					ch_in_info_valid <= (others => '0');
					
				elsif rising_edge(clock) then

					ch_in_real  <= in_wb_real;
					ch_in_imag  <= in_wb_imag;
					ch_in_valid(0) <= in_wb_valid;

					ch_in_bit <= '0';
					ch_in_bit_valid <= (others => '0');
					
					ch_in_aa_detect_results.valid <= '0';
					ch_in_aa_detect_results.preamble_aa <= (others => '0');
					ch_in_aa_detect_results.crc_init <= (others => '0');
					ch_in_aa_detect_valid <= (others => '0');

					ch_in_info.valid <= '0';
					ch_in_info.adv <= '0';
					ch_in_info.ch_idx <= to_unsigned(BTLE_CHANNEL_INVALID, ch_in_info.ch_idx'length);
					ch_in_info_valid <= (others => '0');

					if aa_bit_output.valid = '1' then

						ch_in_bit <= aa_bit_output.seq;
						ch_in_bit_valid(to_integer(aa_bit_output.timeslot)) <= '1';

						if aa_detect_results.valid = '1' then

							ch_in_aa_detect_results <= aa_detect_results;
							ch_in_aa_detect_valid(0) <= '1';
							
						end if;

						if aa_ch_output.valid = '1' then

							ch_in_info <= aa_ch_output;
							ch_in_info_valid(0) <= '1';

						end if;

					end if;

				end if;
			end
		process;

		single_output:
		process(clock, reset) is
			begin
				if reset = '1' then

					ch_in_cts <= (others => '1');
					out_real <= (others => '0');
					out_imag <= (others => '0');
					out_valid <= '0';

				elsif rising_edge(clock) then

					ch_in_cts <= (others => '1');
					
					out_real <= ch_out_real(0);
					out_imag <= ch_out_imag(0);
					out_valid <= ch_out_valid(0);
					
				end if;
			end
		process;

	end generate;

	ch_detector:
	process(clock, reset) is
		variable tmp : std_logic;
		begin
			
			if reset = '1' then

				out_detected <= '0';

			elsif rising_edge(clock) then

				out_detected <= aa_detect_results.valid;

			end if;
		end
	process;

end rtl;
