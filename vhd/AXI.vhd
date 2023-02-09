library IEEE;
use IEEE. std_logic_1164.all;
use IEEE.numeric_std.all;


-- Componente responsável pela leitura do Header

entity AXI is
	port(
	-- Clock e Reset	
		signal clk			  		 	: in std_logic;
		signal rst			   		: in std_logic;
	
	-- Entradas do Componente respectivas ao AXI Slave e Master
		signal S_AXIS_TDATA  		: in std_logic_vector ( 7 downto 0);
		signal S_AXIS_TVALID 		: in std_logic;
		signal M_AXIS_TREADY			: in std_logic;
		
	-- Verificar sincronizacao entre componentes
		signal sync	: in std_logic; 

	-- Saidas do Componente respectivas ao Header
		-- Endereços de destino e origem
		signal Destination_Address : out std_logic_vector(15 downto 0);
		signal Source_Address  		: out std_logic_vector(15 downto 0);
		-- Lixo
			-- signal Dummy			: out std_logic_vector(15 downto 0);	-- Sempre 0x0000
			-- signal Protocol 		: out std_logic_vector( 7 downto 0);  	-- Sempre 0x18
		-- Flags
		signal Flags    				: out std_logic_vector( 7 downto 0); 	-- MSB -> Sync, LSB -> Close
		-- Tamanho do pacote e verificacao de integridade
		signal Sequence_number  	: out std_logic_vector(31 downto 0);	-- Comeca com um valor e sempre incrementa, se for uma seq diferente eh porque houve erro
		signal Checksum				: out std_logic_vector(15 downto 0);
		signal Packet_length			: out std_logic_vector(15 downto 0)
	);
	
	
end entity AXI;

architecture ckt of AXI is
	-- Variables
		-- Determina o estado
		signal estado 					: unsigned(3 downto 0) := "0000";
		
		-- Sinal recebido da entrada TDATA
		signal data						: std_logic_vector (7 downto 0);
		
		-- Sinais de validacao do pacote e de leitura 
		signal valid, ready			: std_logic;
		
	-- Code
		begin
			-- Atribuicao de variavel
			valid <= S_AXIS_TVALID;
			data <= S_AXIS_TDATA;
			ready <= M_AXIS_TREADY;
			
			--Process
			AXI4_Stream : Process(clk)					
				begin				
					if rising_edge(clk) then
					-- tvalid indica que o byte enviado eh valido e pode ser armazenado
					-- tready indica que o byte enviado foi lido e pode mandar o proximo
						if rst = '1' then
							Destination_Address <= (others => '0');
							Source_Address <= (others => '0');
							-- Protocol <= (others => '0');
							Flags <= (others => '0');
							Sequence_number <= (others => '0');
							Checksum <= (others => '0');
							Packet_length <= (others => '0');
						
						else
							if valid = '1' and ready = '1' then	-- O dado eh valido e esta pronto para leitura
								if sync = '1' then					-- Signal de sincronismo entre os componentes validacao e AXI
								-- Caso a validacao esteja ainda sendo feita esta maquina de estado nao pode ocorrer para nao receber dados novos
									case estado is
										-- Leitura do Packet_length
										when "0000" =>
											Packet_length(15 downto 8) <= data;
											estado <= estado + 1;
										
										when "0001" =>
											Packet_length(7 downto 0) <= data;
											estado <= estado + 1;
										
										-- Leitura do Checksum
										when "0010" =>
											Checksum(15 downto 8) <= data;	--validacao dos dados
											estado <= estado + 1;
											
										when "0011" =>
											Checksum(7 downto 0) <= data;	--validacao dos dados
											estado <= estado + 1;
											
										-- Leitura do Sequence_number
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

										-- Leitura de Flags
										when "1000" =>
											Flags <= data;
											estado <= estado + 1;
									
										-- Leitura de Lixo
										when "1001" =>
											-- Protocol <= data;
											estado <= estado + 1;
											
										when "1010" =>
											-- Dummy(15 downto 8) <= data;
											estado <= estado + 1;
											
										when "1011" =>
											-- Dummy(7 downto 0) <= data;
											estado <= estado + 1;
										
										-- Leitura do Source_Address
										when "1100" =>
											Source_Address(15 downto 8) <= data;
											estado <= estado + 1;
											
										when "1101" =>
											Source_Address(7 downto 0) <= data;
											estado <= estado + 1;
										
										-- Leitura do Destination_Address
										when "1110" =>
											Destination_Address(15 downto 8) <= data;
											estado <= estado + 1;
											
										when "1111" =>
											Destination_Address(7 downto 0) <= data;
											estado <= "0000";
										
										-- Quando terminar a leitura volta para o estado inicial
										when others =>
											estado <= "0000";
									end case;
								end if;
							end if;
						end if;
					end if;
			end Process AXI4_Stream;
end architecture;