library IEEE;
use IEEE. std_logic_1164.all;
use IEEE.numeric_std.all;

entity AXI is
	port(
		signal clk			   : in std_logic;
		signal rst			   : in std_logic;
	--Slave
		signal S_AXIS_TDATA  	: in std_logic_vector (7 downto 0);
		signal S_AXIS_TVALID 	: in std_logic;
		signal M_AXIS_TREADY		: in std_logic;
		
		signal sync	: in std_logic; 

	--header
		signal Destination_Address : out std_logic_vector(15 downto 0);
		signal Source_Address  		: out std_logic_vector(15 downto 0);
		signal Dummy				   : out std_logic_vector(15 downto 0);	--sera sempre 0x0000
		signal Protocol 				: out std_logic_vector(7 downto 0);  --sera sempre 0x18
		signal Flags    				: out std_logic_vector(7 downto 0); --MSB -> Sync, LSB -> Close
		signal Sequence_number  	: out std_logic_vector(31 downto 0);	--comeca com um valor e sempre incrementa, se for uma seq diferente eh porque hoyve erro
		signal Checksum				: out std_logic_vector(15 downto 0);
		signal Packet_length			: out std_logic_vector(15 downto 0)
	);
end entity AXI;

architecture ckt of AXI is

	signal estado 	: unsigned(3 downto 0) := "0000";
	signal data		: std_logic_vector (7 downto 0);
	signal valid, ready: std_logic;
	
	
	begin
	
		valid <= S_AXIS_TVALID;
		data <= S_AXIS_TDATA;
		ready <= M_AXIS_TREADY;
		
		AXI4_Stream : Process(clk)
				
			begin
			
			if rising_edge(clk) then
			--tvalid indica que o byte enviado eh valido e pode ser armazenado
			--tready e o sinal que o slave retorna dizendo que o dado foi recebido e pode ser enviado um novo byte
				if rst = '1' then
					Destination_Address <= (others => '0');
					Source_Address <= (others => '0');
					Protocol <= (others => '0');
					Flags <= (others => '0');
					Sequence_number <= (others => '0');
					Checksum <= (others => '0');
					Packet_length <= (others => '0');
				
				else
					if valid = '1' and ready = '1' then	--o dado eh valido	
						if sync = '1' then	--signal de sincronismo entre o componente validacao e o header
						--Caso a validacao esteja ainda sendo feita esta maquina de estado nao pode ocorrer para nao receber dados novos
							case estado is
								when "0000" =>
									Packet_length(15 downto 8) <= data;
									estado <= estado + 1;
								
								when "0001" =>
									Packet_length(7 downto 0) <= data;
									estado <= estado + 1;
								
								when "0010" =>
									Checksum(15 downto 8) <= data;	--validacao dos dados
									estado <= estado + 1;
									
								when "0011" =>
									Checksum(7 downto 0) <= data;	--validacao dos dados
									estado <= estado + 1;
									
								when "0100" =>
									Sequence_number(31 downto 24) <= data;
									estado <= estado + 1;
									
								when "0101" =>
									Sequence_number(23 downto 16) <= data;
									estado <= estado + 1;
									
								when "0110" =>
									Sequence_number(15 downto 8) <= data;
									estado <= estado + 1;
								
								when "0111" =>
									Sequence_number(7 downto 0) <= data;
									estado <= estado + 1;

								when "1000" =>
									Flags <= data;
									estado <= estado + 1;
							
								when "1001" =>
									Protocol <= data;
									estado <= estado + 1;
									
								when "1010" =>
									Dummy(15 downto 8) <= data;
									estado <= estado + 1;
									
								when "1011" =>
									Dummy(7 downto 0) <= data;
									estado <= estado + 1;
									
								when "1100" =>
									Source_Address(15 downto 8) <= data;
									estado <= estado + 1;
									
								when "1101" =>
									Source_Address(7 downto 0) <= data;
									estado <= estado + 1;
									
								when "1110" =>
									Destination_Address(15 downto 8) <= data;
									estado <= estado + 1;
									
								when "1111" =>
										Destination_Address(7 downto 0) <= data;
										estado <= "0000";
								when others =>
									estado <= "0000";
							end case;
						end if;
					end if;
				end if;
			end if;
		end Process AXI4_Stream;
end architecture;