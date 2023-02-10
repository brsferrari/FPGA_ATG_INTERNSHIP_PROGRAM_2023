library IEEE;
use IEEE. std_logic_1164.all;
use IEEE.numeric_std.all;

entity SWITCH is
	port(
		signal clk			   				: in  std_logic;
		signal rst			   				: in  std_logic;

	--Master	
		signal M_AXIS_TDATA  				: out std_logic_vector (7 downto 0); --somente quando houver erro
		signal M_AXIS_TVALID 				: out std_logic;
		signal M_AXIS_TREADY 				: in  std_logic;
		signal M_AXIS_TLAST  				: out std_logic;
		signal Ssoma							: out unsigned (16 downto 0);
		signal Sdata	: out unsigned (15 downto 0);
		signal pckt_len						: out unsigned (15 downto 0);	--dado para simulacao
		signal Schecksum_out				: out unsigned (15 downto 0);	--dado para simulacao
		signal Sestado	: out unsigned (3 downto 0);
		signal Checksum_reg_out						: out std_logic_vector(15 downto 0);
		signal Packet_length				: out std_logic_vector(15 downto 0);
		
		signal PORTA							: in std_logic_vector(4 downto 0);	--qual porta esta enviando o dado
		signal PORTA_dest						: out std_logic_vector(4 downto 0);	--qual porta esta enviando o dado
		signal Source_Address  				: out std_logic_vector(15 downto 0);
		signal valid_error_out 				:  out std_logic_vector(5 downto 0);
		signal ADDRESS_TABLE_out				: out std_logic_vector(79 downto 0);
		signal Flags_reg_out    			:  out std_logic_vector(7 downto 0) := (others => '0'); --MSB -> Sync, LSB -> Close
	
		signal DEST_ADDR_out						: out std_logic_vector(15 downto 0);

	--Slave
		signal S_AXIS_TDATA  				: in  std_logic_vector (7 downto 0); --envio de dados
		signal S_AXIS_TVALID 				: in  std_logic;					--envio se o sinal eh valido
		signal S_AXIS_TREADY 				: out std_logic;					--retorno do componente
		signal S_AXIS_TLAST  				: in  std_logic						--envio no final da transmissao
		
	);
end entity SWITCH;

architecture ckt of SWITCH is

	signal data, m_data						:  std_logic_vector (7 downto 0); --signal para envio do dado e retorno do dado
	signal valid, m_valid, ready, m_last 	:  std_logic;
	signal sync								:  std_logic;
	signal Dest_Addr_reg 					:  std_logic_vector(15 downto 0);
	signal Src_Addr_reg  					:  std_logic_vector(15 downto 0);
	signal Dummy_reg				   		:  std_logic_vector(15 downto 0);	--sera sempre 0x0000
	signal Protocol_reg 					:  std_logic_vector(7 downto 0);  --sera sempre 0x18
	signal Flags_reg    					:  std_logic_vector(7 downto 0) := (others => '0'); --MSB -> Sync, LSB -> Close
	signal Seq_num_reg  					:  std_logic_vector(31 downto 0);	--comeca com um valor e sempre incrementa, se for uma seq diferente eh porque hoyve erro
	signal Checksum_reg						: std_logic_vector(15 downto 0);
	signal Packet_len_reg					: std_logic_vector(15 downto 0);
	signal Seq_num_reg_out  					:  unsigned(31 downto 0);	--comeca com um valor e sempre incrementa, se for uma seq diferente eh porque hoyve erro
	signal Spayload_i						:  std_logic_vector(7 downto 0);
		
	signal valid_error 						: std_logic_vector(5 downto 0);
	signal valid_error_i						: std_logic_vector(5 downto 0);
	
	signal validate_finish : std_logic;
	signal ADDRESS_TABLE_i				: std_logic_vector(79 downto 0);

	signal PORTA_dest_i : std_logic_vector (4 downto 0);

	component AXI is
		port(
		signal clk			   				: in std_logic;
		signal rst			   				: in std_logic;
	--Slave
		signal S_AXIS_TDATA  				: in std_logic_vector (7 downto 0);
		signal S_AXIS_TVALID 				: in std_logic;
		
		signal sync							: in std_logic; 

	--header
		signal Destination_Address 			: out std_logic_vector(15 downto 0);
		signal Source_Address  				: out std_logic_vector(15 downto 0);
		signal Dummy				   		: out std_logic_vector(15 downto 0);	--deve sempre ser 0x0000
		signal Protocol 					: out std_logic_vector(7 downto 0);  	--deve sempre ser 0x18
		signal Flags    					: out std_logic_vector(7 downto 0); 	--MSB -> Sync, LSB -> Close
		signal Sequence_number  			: out std_logic_vector(31 downto 0);	--comeca com um valor e sempre incrementa, se for uma seq diferente eh porque houve erro
		signal Checksum						: out std_logic_vector(15 downto 0);
		signal Packet_length				: out std_logic_vector(15 downto 0)
	);
	end component AXI;
	
	
	component validacao is
		port(
		signal clk			   			: in std_logic;
		signal rst			   			: in std_logic;
		signal validate_finish				: out std_logic;

		signal sync						: out std_logic;
	--Slave
		signal S_AXIS_TDATA  			: in std_logic_vector (7 downto 0);
		signal S_AXIS_TVALID 			: in std_logic;
		signal S_AXIS_TREADY 			: out std_logic;
		signal S_AXIS_TLAST  			: in std_logic;
		signal Spayload						:  out std_logic_vector(7 downto 0);
		signal Ssoma							:  out unsigned (16 downto 0);
		signal ideal_seq_num_out				: out unsigned (31 downto 0);
		signal Sdata	: out unsigned (15 downto 0);
		signal Sestado	: out unsigned (3 downto 0);
		signal Flags    					: in std_logic_vector(7 downto 0); 	--MSB -> Sync, LSB -> Close
		signal Schecksum				: in std_logic_vector (15 downto 0); 
		signal Schecksum_out			: out unsigned (15 downto 0);	--para simulacao
		signal pckt_len					: in std_logic_vector (15 downto 0);
		signal pckt_len_out     		: out unsigned (15 downto 0);		--para simulacao
		signal sequence_num  			: in std_logic_vector(31 downto 0);
		signal dummy		    		: in std_logic_vector(15 downto 0);
		signal prot    					: in std_logic_vector(7 downto 0);
		signal error					: out std_logic_vector(5 downto 0) 		--comporta erro de checksum, pckt_len, dummy e protocol
	);
	end component validacao;
	
	component tabela_dinamica is
	port(
		signal clk			   				: in std_logic;
		signal rst			   				: in std_logic;
		signal validate_finish				: in std_logic;
		signal SRC_ADDR						: in std_logic_vector(15 downto 0);
		signal PORTA							: in std_logic_vector(4 downto 0);	--qual porta esta enviando o dado
		signal ERRO							  	: in std_logic_vector(5 downto 0);
		signal ADDRESS_TABLE 				: out std_logic_vector(79 downto 0);
		signal FLAGS							: in std_logic_vector(7 downto 0)
		);
	end component tabela_dinamica;
	
	component identificador_de_porta is
		port(
			signal clk			   				: in std_logic;
			signal rst			   				: in std_logic;
			signal validate_finish				: in std_logic;
			signal ERRO  							: out std_logic_vector(5 downto 0);
			signal ADDRESS_TABLE 				: in std_logic_vector(79 downto 0);
			signal DEST_ADDR						: in std_logic_vector(15 downto 0);
			signal FLAGS							: in std_logic_vector(7 downto 0);
			signal DEST_PORT                 : out std_logic_vector(4 downto 0)
		);
	end component identificador_de_porta;
	
	begin
		
		S_AXIS_TREADY <= ready;
		M_AXIS_TDATA  <= m_data;
		M_AXIS_TVALID <= valid;
		M_AXIS_TLAST  <= m_last;
		
		data <= S_AXIS_TDATA;
		valid <= '1';
		Checksum_reg_out <= checksum_reg;
		Packet_length <= Packet_len_reg;
		Source_Address <= Src_Addr_reg;
		valid_error_out <= valid_error_i when valid_error = "00000" else
								 valid_error;
		valid_error_i <= valid_error;
		Flags_reg_out <= flags_reg;
		DEST_ADDR_out <= dest_Addr_reg;
		PORTA_dest <= PORTA_dest_i;
		ADDRESS_TABLE_out <= ADDRESS_TABLE_i;
		
--		AXI4_Stream_master : Process(clk)
--				
--			begin
--			if rising_edge(clk) then
--				if rst = '1' then
--					--data <= (others => '0');
--				else
--					if ready = '1' then
--						
--						valid <= '1';
--					end if;
--				end if;
--			end if;
--		end process;
	
	header_reader :  AXI port map(clk, rst, data, valid, sync,
	Dest_Addr_reg, Src_Addr_reg, Dummy_reg, Protocol_reg, Flags_reg, Seq_num_reg, checksum_reg, Packet_len_reg);
	
	check_data_integrety : validacao port map (clk, rst, validate_finish, sync, data, valid, ready, S_AXIS_TLAST, Spayload_i,
	Ssoma, Seq_num_reg_out, Sdata, Sestado, Flags_reg, checksum_reg, Schecksum_out, Packet_len_reg, pckt_len,
	Seq_num_reg, Dummy_reg, Protocol_reg, valid_error);
	
	montagem_tabela : tabela_dinamica port map(clk, rst, validate_finish, Src_Addr_reg, PORTA, valid_error , ADDRESS_TABLE_i, Flags_reg);
	enviando_para_porta_de_destino : identificador_de_porta port map(clk, rst, validate_finish, valid_error_i, ADDRESS_TABLE_i, Dest_Addr_reg, Flags_reg, PORTA_dest_i);
end architecture;