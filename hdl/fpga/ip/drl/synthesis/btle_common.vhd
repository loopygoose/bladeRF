--
-- (c) Distributed Radio Limited 2016
--     steve@distributedradio.com
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all ;

package btle_common is

	constant BTLE_NUM_SUBBANDS : integer := 3;
	constant BTLE_FFT_SIZE : integer := 16;
	constant BTLE_SAMPLES_PER_SYMBOL : integer := 2;
	constant BTLE_MAXIMUM_AA_MEMORY : integer := 5;

    constant BTLE_MAX_IQ : integer := 2047;
    constant BTLE_MIN_IQ : integer := -2048;    

	constant BTLE_ADV_PDU_ADV_IND: integer := 0;
	constant BTLE_ADV_PDU_DIRECT_IND: integer := 1;
	constant BTLE_ADV_PDU_NONCONN_IND: integer := 2;
	constant BTLE_ADV_PDU_SCAN_REQ: integer := 3;
	constant BTLE_ADV_PDU_SCAN_RSP: integer := 4;
	constant BTLE_ADV_PDU_CONNECT_REQ: integer := 5;
	constant BTLE_ADV_PDU_ADV_SCAN_IND: integer:= 6;

	constant BTLE_LLID_RESERVED: integer := 0;
	constant BTLE_LLID_DATA_CONT: integer := 1;
	constant BTLE_LLID_DATA_START: integer := 2;
	constant BTLE_LLID_CONTROL: integer := 3;

	-- Bits
	constant BTLE_TRIGGER_LEN: integer := 25;
	constant BTLE_PREAMBLE_LEN: integer := 8;
	constant BTLE_AA_LEN : integer := 32;
	constant BTLE_HEADER_LEN : integer := 16;
	constant BTLE_MIN_PAYLOAD_LEN: integer := (6 * 8);
	constant BTLE_MAX_PAYLOAD_LEN: integer := (37 * 8);
	constant BTLE_CRC_LEN: integer := 24;

	subtype aa_t is std_logic_vector (BTLE_AA_LEN - 1 downto 0);
	subtype preamble_aa_t is std_logic_vector (BTLE_PREAMBLE_LEN + BTLE_AA_LEN - 1 downto 0);
	subtype crc_t is std_logic_vector(BTLE_CRC_LEN - 1 downto 0);

	constant BTLE_ADV_CRC_INIT : crc_t := x"AAAAAA";
	constant BTLE_BED6 : preamble_aa_t := "0101010101101011011111011001000101110001";

	--Samples
	constant BTLE_MEMORY_LEN: integer := BTLE_SAMPLES_PER_SYMBOL * (BTLE_TRIGGER_LEN + BTLE_PREAMBLE_LEN + BTLE_AA_LEN + BTLE_HEADER_LEN + BTLE_MAX_PAYLOAD_LEN + BTLE_CRC_LEN + BTLE_TRIGGER_LEN);	
	constant BTLE_DEMOD_TAP_POSITION: integer := BTLE_SAMPLES_PER_SYMBOL * (BTLE_TRIGGER_LEN + BTLE_PREAMBLE_LEN + BTLE_AA_LEN);

	function reverse_any_vector (a: in std_logic_vector) return std_logic_vector;

	-- Basic types

    type real_array_t is array(natural range <>) of real ;
	
	subtype sample_t is signed (15 downto 0);
	subtype timeslot_t is unsigned (4 downto 0);			-- 0..15 TDM
	subtype channel_idx_t is unsigned (5 downto 0);			-- 0..36, 37, 38, 39	& 63 (invalid)
	subtype rssi_t is unsigned (31 downto 0);

	type rssi_results_t is record
		valid:      std_logic;
		timeslot:   timeslot_t;
		rssi:       rssi_t;
		clipped:    std_logic;
		detections: unsigned(5 downto 0);
	end record;

	subtype header_bits_t is std_logic_vector (BTLE_HEADER_LEN - 1 downto 0);
	subtype payload_len_t is unsigned (5 downto 0);
	subtype pdu_llid_type_t is unsigned (3 downto 0);


	type btle_ch_info_t is record
		ch_idx:		channel_idx_t;
		adv:		std_logic;
		valid:		std_logic;
	end record;
	
	type iq_bus_t is record
		real: 		sample_t;
		imag: 		sample_t;
		valid: 		std_logic;
	end record;

	type tdm_iq_bus_t is record
		real: 		sample_t;
		imag: 		sample_t;
		valid: 		std_logic;
		timeslot: 	timeslot_t;
	end record;

	type bit_bus_t is record
		seq:		std_logic;
		valid:		std_logic;
	end record;

	type tdm_bit_bus_t is record
		seq:		std_logic;
		valid:		std_logic;
		timeslot:	timeslot_t;
	end record;

	type aa_crc_config_t is record
		valid:				std_logic;
		preamble_aa:		preamble_aa_t;
		crc_init:			crc_t;
	end record;

	type common_header_t is record
		decoded:			std_logic;
		valid:				std_logic;
		length:				payload_len_t;
		pdu_llid:			pdu_llid_type_t;
		bits:				header_bits_t;
	end record;

	type adv_header_t is record
		tx_addr:			std_logic;
		rx_addr:			std_logic;
	end record;

	type data_header_t is record
		md:					std_logic;
		sn:					std_logic;
		nesn:				std_logic;	
	end record;
end;


package body btle_common is

	function reverse_any_vector (a: in std_logic_vector)
		return std_logic_vector is
 		variable result: std_logic_vector(a'RANGE);

  		alias aa: std_logic_vector(a'REVERSE_RANGE) is a;

		begin
  			for i in aa'RANGE loop
    			result(i) := aa(i);
  			end loop;

  			return result;
		end; -- function reverse_any_vector


end btle_common;

