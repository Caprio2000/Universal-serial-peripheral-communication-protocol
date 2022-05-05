-----------------------------------------------------------------------------------------------
-- Create Date: 05.05.2022 12:27:16
-- Designer Name: CAPRIO MISTRY
-----------------------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;
USE ieee.std_logic_unsigned.all;

ENTITY spi_master IS
  GENERIC(
    data_length : INTEGER := 32);     --data length in bits
  PORT(
    clock                   : IN     STD_LOGIC;                      --system clock
    reset                   : IN     STD_LOGIC;                      --asynchronous active low reset
    enable                  : IN     STD_LOGIC;                      --initiate communication
	 clock_polarity         : IN     STD_LOGIC;  					             --clock polarity mode
    clock_phase             : IN     STD_LOGIC;  				          	 --clock phase mode
    master_in_slave_out     : IN     STD_LOGIC;                      --master in slave out(MISO)
    transmit_data		    : IN     STD_LOGIC_VECTOR(data_length-1 DOWNTO 0); --data to transmit
    system_clock            : OUT    STD_LOGIC;                      --spi clock
    chip_selector           : OUT    STD_LOGIC;                      --slave select
    master_out_slave_in     : OUT    STD_LOGIC;                      --master out slave in (MOSI)
    last_bit_flag           : OUT    STD_LOGIC;                      --master busy signal
  	en_pin_ctrl				: out 	 std_logic                             -- not in use
    );
END spi_master;

ARCHITECTURE behavioural OF spi_master IS

  TYPE FSM IS(initial, execute);                           		--state machine
  SIGNAL state   : FSM;                             
  
  SIGNAL receive_transmit       : STD_LOGIC;                               --'1' for tx, '0' for rx 
  SIGNAL clock_toggles          : INTEGER RANGE 0 TO data_length*2 + 1;    --clock toggle counter
  SIGNAL last_bit		            : INTEGER RANGE 0 TO data_length*2;        --last bit indicator
  SIGNAL receive_data_buffer    : STD_LOGIC_VECTOR(data_length-1 DOWNTO 0) := (OTHERS => '0'); --receive data buffer
  SIGNAL transmit_data_buffer   : STD_LOGIC_VECTOR(data_length-1 DOWNTO 0) := (OTHERS => '0'); --transmit data buffer
  SIGNAL Internal_chip_selector : STD_LOGIC;                            --Internal register for ss_n 
  SIGNAL Internal_system_clock  : STD_LOGIC;                            --Internal register for sclk 
  SIGNAL busy                   : STD_LOGIC;                            --Internal busy 
  SIGNAL received_data	        : STD_LOGIC_VECTOR(data_length-1 DOWNTO 0);
 -- signal pmod_en					  : std_logic:='0';
BEGIN
	last_bit_flag <= not busy;
  -- wire internal registers to outside	
  chip_selector <= Internal_chip_selector;
  system_clock <= Internal_system_clock;
  
  PROCESS(clock, reset)
  BEGIN
	 
    IF(reset = '0') THEN        --reset everything
      busy <= '1';                
      Internal_chip_selector <= '0';            
      master_out_slave_in <= '0';                
--      master_out_slave_in <= 'Z';                
      received_data <= (OTHERS => '0');      
      state <= initial;              

    ELSIF(falling_edge(clock)) THEN
	
		en_pin_ctrl<='1';
      CASE state IS               

        WHEN initial =>					 -- bus is idle
          busy <= '0';             
          Internal_chip_selector <= '0'; 		  
          master_out_slave_in <= '0';             
--          master_out_slave_in <= 'Z';             
   
          IF(enable = '1') THEN       		--initiate communication
            busy <= '1';             
            Internal_system_clock <= clock_polarity;        		--set spi clock polarity
            receive_transmit <= NOT clock_phase; --set spi clock phase
            transmit_data_buffer <= transmit_data;    				--put data to buffer to transmit
            clock_toggles <= 0;        		--initiate clock toggle counter
            last_bit <= data_length*2 + conv_integer(clock_phase) - 1; --set last rx data bit
            state <= execute;        
          ELSE
            state <= initial;          
          END IF;


        WHEN execute =>
          busy <= '1';               
          Internal_chip_selector <= '0';           	--pull the slave select signal down
			 receive_transmit <= NOT receive_transmit;   --change receive transmit mode
          
			 -- counter
			 IF(clock_toggles = data_length*2 + 1) THEN
				clock_toggles <= 0;               				--reset counter
          ELSE
				clock_toggles <= clock_toggles + 1; 			--increment counter
          END IF;
            
          -- toggle sclk
          IF(clock_toggles <= data_length*2 AND Internal_chip_selector = '0') THEN 
            Internal_system_clock <= NOT Internal_system_clock; --toggle spi clock
          END IF;
            
          --receive miso bit
          IF(receive_transmit = '0' AND clock_toggles < last_bit + 1 AND Internal_chip_selector = '0') THEN 
            receive_data_buffer <= receive_data_buffer(data_length-2 DOWNTO 0) & master_in_slave_out; 
          END IF;
            
          --transmit mosi bit
          IF(receive_transmit = '1' AND clock_toggles < last_bit) THEN 
            master_out_slave_in <= transmit_data_buffer(data_length-1);                    
            transmit_data_buffer <= transmit_data_buffer(data_length-2 DOWNTO 0) & '0'; 
          END IF;
            
          -- Finish/ resume the communication
          IF(clock_toggles = data_length*2 + 1) THEN   
            busy <= '0';             
            Internal_chip_selector <= '1';         
            master_out_slave_in <= '0';             
--            master_out_slave_in <= 'Z';             
            received_data <= receive_data_buffer;    
            state <= initial;          
          ELSE                       
            state <= execute;        
          END IF;
      END CASE;
    END IF;
  END PROCESS; 
END behavioural;