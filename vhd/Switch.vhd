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
		signal PORTA							: in std_logic_vector(4 downto 0);	--qual porta esta enviando o dado
		signal PORTA_dest						: out std_logic_vector(4 downto 0);	--qual porta esta enviando o dado
		signal Source_addres_valid  		: out std_logic_vector(15 downto 0);
		signal valid_error_out 				:  out std_logic_vector(5 downto 0);
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

	signal data						:  std_logic_vector (7 downto 0); --signal para envio do dado e retorno do dado
	signal valid, ready 	:  std_logic;
	signal sync								:  std_logic;
	signal Dest_Addr_reg 					:  std_logic_vector(15 downto 0);
	signal Src_Addr_reg  					:  std_logic_vector(15 downto 0);
	signal Dummy_reg				   		:  std_logic_vector(15 downto 0);	--sera sempre 0x0000
	signal Protocol_reg 					:  std_logic_vector(7 downto 0);  --sera sempre 0x18
	signal Flags_reg    					:  std_logic_vector(7 downto 0) := (others => '0'); --MSB -> Sync, LSB -> Close
	signal Seq_num_reg  					:  std_logic_vector(31 downto 0);	--comeca com um valor e sempre incrementa, se for uma seq diferente eh porque hoyve erro
	signal Checksum_reg						: std_logic_vector(15 downto 0);
	signal Packet_len_reg					: std_logic_vector(15 downto 0);
	signal Seq_num_out					: unsigned (31 downto 0);
	signal Spayload_i						:  std_logic_vector(7 downto 0);
		
	signal valid_error 						: std_logic_vector(5 downto 0);
	signal valid_error_i						: std_logic_vector(5 downto 0);
	
	signal validate_finish : std_logic;
	signal ADDRESS_TABLE_i				: std_logic_vector(79 downto 0);

	signal PORTA_dest_i : std_logic_vector (4 downto 0);

	signal contador	: unsigned (29 downto 0) := (others => '0');
	signal clk_1s		: std_logic;
	
	signal estado_pckt_len, estado_checksum: unsigned(3 downto 0) := (others => '0');
	signal estado_seq_num : unsigned(7 downto 0)  := (others => '0');
	signal estado_nt_found_addr : std_logic := '0';
	signal pckt_len_i : unsigned (15 downto 0);
	signal checksum_esperado : unsigned(15 downto 0);
	signal master_T_LAST : std_logic := '0';
	signal FLAG_de_seqnum				: std_logic_vector(5 downto 0);
	
	component AXI is
		port(
		signal clk			   				: in std_logic;
		signal rst			   				: in std_logic;
	--Slave
		signal S_AXIS_TDATA  				: in std_logic_vector (7 downto 0);
		signal S_AXIS_TVALID 				: in std_logic;
		--signal M_AXIS_TREADY		: in std_logic;

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
		signal sync							: out std_logic;
		signal M_AXIS_TREADY				: in std_logic;

	--Slave
		signal S_AXIS_TDATA  			: in std_logic_vector (7 downto 0);
		signal S_AXIS_TVALID 			: in std_logic;
		signal S_AXIS_TREADY 			: out std_logic;
		signal S_AXIS_TLAST  			: in std_logic;
		signal Spayload						:  out std_logic_vector(7 downto 0);
		signal Flags    					: in std_logic_vector(7 downto 0); 	--MSB -> Sync, LSB -> Close
		signal Schecksum				: in std_logic_vector (15 downto 0); 
		signal Schecksum_out			: out unsigned (15 downto 0);	--para simulacao
		signal pckt_len					: in std_logic_vector (15 downto 0);
		signal error					: out std_logic_vector(5 downto 0) 		--comporta erro de checksum, pckt_len, dummy e protocol
	);
	end component validacao;
	

	
	component tabela_dinamica is
	port(
		signal clk			   				: in std_logic;
		signal rst			   				: in std_logic;
		signal validate_finish				: in std_logic;
		signal tlast							: in std_logic;
		signal seqnum							: in unsigned (31 downto 0); --header
		signal seqnum_component				: out unsigned (31 downto 0); 
		signal FLAG_de_seqnum				: out std_logic_vector(5 downto 0);
		signal SRC_ADDR						: in std_logic_vector(15 downto 0);
		signal SRC_ADDR_out					: out std_logic_vector(15 downto 0);
		signal PORTA							: in std_logic_vector(4 downto 0);	--qual porta esta enviando o dado
		signal ERRO_da_validacao 			: in std_logic_vector(5 downto 0);
		signal ADDRESS_TABLE 				: out std_logic_vector(79 downto 0);
		signal FLAGS							: in std_logic_vector(7 downto 0)
		);
	end component tabela_dinamica;
	
	
	
	component identificador_de_porta is
		port(
			signal clk			   				: in std_logic;
			signal rst			   				: in std_logic;
			signal validate_finish				: in std_logic;
			signal entrada_de_erro				: in std_logic_vector(5 downto 0);
			signal ERRO  							: out std_logic_vector(5 downto 0);
			signal ADDRESS_TABLE 				: in std_logic_vector(79 downto 0);
			signal DEST_ADDR						: in std_logic_vector(15 downto 0);
			signal FLAGS							: in std_logic_vector(7 downto 0);
			signal DEST_PORT                 : out std_logic_vector(4 downto 0)
		);
	end component identificador_de_porta;
	
	begin
		
		S_AXIS_TREADY <= ready;
		
		valid <= S_AXIS_TVALID;
		
		valid_error_out <= valid_error_i;
		Flags_reg_out <= flags_reg;
		DEST_ADDR_out <= dest_Addr_reg;
		PORTA_dest <= PORTA_dest_i;
		
		M_AXIS_TLAST <= master_T_LAST;
		
		AXI4_Stream_master : Process(clk)
				
			begin
			if rising_edge(clk) then
				if rst = '1' then
					
				else
					data <= S_AXIS_TDATA;
					
					if valid_error_i(3 downto 0) /= "0000" then --houve erro
						M_AXIS_TVALID <= '1'; 
					else 
						M_AXIS_TVALID <= '0';
					end if;					  
					
					if contador < 49999999 then	--contador de 1s
						contador <= contador + 1;
					
					else
						contador <= (others => '0');
						case clk_1s is		--clk_1s <= not clk_1s
							when '0' =>
								clk_1s <= '1';
							
							when '1' => 
								clk_1s <= '0';
						end case;
					end if;
				end if;
			end if;
		end process;
		
		MASTER_TDATA_SEND: Process(clk)
			begin
			if rising_edge(clk) then
				if rst = '1' then
					
				else
					if valid_error_i(3 downto 0) /= "0000" and M_AXIS_TREADY = '1' then --houve erro
						if valid_error_i(0) = '1' then --erro de pckt_len
							if master_T_LAST = '0' then
								case estado_pckt_len is
									when X"0" =>
										M_AXIS_TDATA <= Packet_len_reg(15 downto 8);
										estado_pckt_len <= estado_pckt_len + 1;
										
									when X"1" =>
										M_AXIS_TDATA <= Packet_len_reg(7 downto 0);
										estado_pckt_len <= estado_pckt_len + 1;
									
									when X"2" =>
										M_AXIS_TDATA <= std_logic_vector(pckt_len_i(15 downto 8));
										estado_pckt_len <= estado_pckt_len + 1;
										
									when X"3" =>
										M_AXIS_TDATA <= std_logic_vector(pckt_len_i(7 downto 0));
										master_T_LAST <= '1';
										estado_pckt_len <= X"0";
									
									when others =>
										estado_pckt_len <= X"0";
								end case;								
							end if;
							
							
						elsif valid_error_i(1) = '1' then --erro de checksum
							if master_T_LAST = '0' then
								case estado_checksum is
									when X"0" =>
										M_AXIS_TDATA <= checksum_reg(15 downto 8);
										estado_checksum <= estado_checksum + 1;
										
									when X"1" =>
										M_AXIS_TDATA <= checksum_reg(7 downto 0);
										estado_checksum <= estado_checksum + 1;
									
									when X"2" =>
										M_AXIS_TDATA <= std_logic_vector(checksum_esperado(15 downto 8));
										estado_checksum <= estado_checksum + 1;
										
									when X"3" =>
										M_AXIS_TDATA <= std_logic_vector(checksum_esperado(7 downto 0));
										master_T_LAST <= '1';
										estado_checksum <= X"0";
										
									when others =>
										estado_checksum <= X"0";
								end case;
							end if;
							
								
						elsif valid_error_i(2) = '1' then --erro de seq_num_reg
							if master_T_LAST = '0' then
								case estado_seq_num is
									when X"00" =>
										M_AXIS_TDATA <= Seq_num_reg(31 downto 24);
										estado_seq_num <= estado_seq_num + 1;
										
									when X"01" =>
										M_AXIS_TDATA <= Seq_num_reg(23 downto 16);
										estado_seq_num <= estado_seq_num + 1;
									
									when X"02" =>
										M_AXIS_TDATA <= Seq_num_reg(15 downto 8);
										estado_seq_num <= estado_seq_num + 1;
										
									when X"03" =>
										M_AXIS_TDATA <= Seq_num_reg(7 downto 0);
										estado_seq_num <= estado_seq_num + 1;
										
									when X"04" =>
										M_AXIS_TDATA <= std_logic_vector(Seq_num_out(31 downto 24));
										estado_seq_num <= estado_seq_num + 1;
										
									when X"05" =>
										M_AXIS_TDATA <= std_logic_vector(Seq_num_out(23 downto 16));
										estado_seq_num <= estado_seq_num + 1;
									
									when X"06" =>
										M_AXIS_TDATA <= std_logic_vector(Seq_num_out(15 downto 8));
										estado_seq_num <= estado_seq_num + 1;
										
									when X"07" =>
										M_AXIS_TDATA <= std_logic_vector(Seq_num_out(7 downto 0));
										master_T_LAST <= '1';
										estado_seq_num <= X"00";
									
									when others =>
										estado_seq_num <= X"00";
								end case;
							end if;
							
						elsif	valid_error_i(3) = '1' then	--erro de endereco nao encontrado
							if master_T_LAST = '0' then
								case estado_nt_found_addr is
									when '0' =>
										M_AXIS_TDATA <= Dest_Addr_reg(15 downto 8);
										estado_nt_found_addr <= '1';
										
									when '1' =>
										M_AXIS_TDATA <= Dest_Addr_reg(7 downto 0);
										estado_nt_found_addr <= '0';	
										master_T_LAST <= '1';		
								end case;
							end if;									
						end if;
					else	--nao houve erro
						master_T_LAST <= '0';	
						M_AXIS_TDATA <= (others => '0');
					end if;					  
				end if;
			end if;
		end process;	
		
	header_reader :  AXI port map(clk, rst, data, valid, sync,
	Dest_Addr_reg, Src_Addr_reg, Dummy_reg, Protocol_reg, Flags_reg, Seq_num_reg, checksum_reg, Packet_len_reg);
	
	montagem_tabela : tabela_dinamica port map(clk, rst, validate_finish, S_AXIS_TLAST, unsigned(seq_num_reg), 
	Seq_num_out, FLAG_de_seqnum, Src_Addr_reg, Source_addres_valid, PORTA, valid_error , ADDRESS_TABLE_i, Flags_reg);

	check_data_integrety : validacao port map (clk, rst, validate_finish, sync, M_AXIS_TREADY, data, valid, ready, S_AXIS_TLAST, Spayload_i,
	Flags_reg, checksum_reg, checksum_esperado, Packet_len_reg, valid_error);
	
	enviando_para_porta_de_destino : identificador_de_porta port map(clk, rst, validate_finish, FLAG_de_seqnum, valid_error_i, ADDRESS_TABLE_i, Dest_Addr_reg, Flags_reg, PORTA_dest_i);

end architecture;