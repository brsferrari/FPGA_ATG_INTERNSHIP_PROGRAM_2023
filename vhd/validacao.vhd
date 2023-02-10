library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.numeric_std.all;

entity validacao is
	port(
		signal clk			   			: in std_logic;
		signal rst			   			: in std_logic;
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
		signal error					: out std_logic_vector(4 downto 0) 		--comporta erro de checksum, pckt_len, dummy e protocol
	);
end entity validacao;

architecture ckt of validacao is
	
	signal estado 						: unsigned(3 downto 0) := "0000";
	signal estado2 						: unsigned (2 downto 0) := "000";
	signal transmit_data				: std_logic_vector (7 downto 0);
	signal payload						: std_logic_vector(7 downto 0);
	signal data							: unsigned (15 downto 0);
	signal soma							: unsigned (16 downto 0);
	signal increment_pckt_len			: unsigned (15 downto 0) := (others => '0');
	signal valid, last, ready			: std_logic;
	signal checksum				  	 	: unsigned (15 downto 0);	--checksum calculado pelo componente
	signal ideal_dummy				    : unsigned (15 downto 0) := X"0000"; --dummy ideal
	signal ideal_protocol				: unsigned (7 downto 0)  := X"18";	--protocol ideal
	signal ideal_seq_num				: unsigned (31 downto 0);
	signal first_receive				: std_logic := '0';

	--signals para receber do header a informcao
	signal checksum_rx					: std_logic_vector(15 downto 0);
	signal packet_len_rx				: std_logic_vector(15 downto 0);
	signal prot_rx 						: std_logic_vector(7 downto 0);
	signal dummy_rx				   		: std_logic_vector(15 downto 0);
	signal sequence_number_rx  			: std_logic_vector(31 downto 0);	--comeca com um valor e sempre incrementa, se for uma seq diferente eh porque hoyve erro
	
	--signals para trabalhar com operacao de comparacao para verificar a integridade da informacao
	signal checksum_rx_unsign			: unsigned(15 downto 0);
	signal packet_len_rx_unsign			: unsigned(15 downto 0);
	signal prot_rx_unsign				: unsigned(7 downto 0);
	signal dummy_rx_unsign			   	: unsigned(15 downto 0);
	signal sequence_number_rx_usign		: unsigned(31 downto 0);

	signal synchronize					: std_logic;	--signal de sincronismo
	signal transmission 					: std_logic := '1';
	
	signal contador_len_payload : unsigned (7 downto 0) := (others => '0');

	begin
		--signals do AXI
		valid <= S_AXIS_TVALID;
		transmit_data <= S_AXIS_TDATA;
		S_AXIS_TREADY <= ready;
		last <= S_AXIS_TLAST;
---------------------------------------		
		sync <= synchronize;	--signal de sincronismo entre o header e a validacao
		--dados recebidos do header
		checksum_rx <= Schecksum;	--checksum do header
		packet_len_rx <= pckt_len;	--pckt_len do header
		prot_rx <= prot;			--protocol do header
		dummy_rx <= dummy;			--dummy do header
		sequence_number_rx <= sequence_num;
		Sdata <= data;
		--Conversao para sinais unsigned
		checksum_rx_unsign <= unsigned(checksum_rx);
		packet_len_rx_unsign <= unsigned(packet_len_rx);
		prot_rx_unsign <= unsigned(prot_rx);
		dummy_rx_unsign <= unsigned(dummy_rx);
		sequence_number_rx_usign <=  unsigned(sequence_number_rx);
		Sestado <= estado;
		------------------------------------------

		--recebendo sinais de saida
		--sinais de saida apenas para simulacao
		pckt_len_out <= increment_pckt_len;
		Schecksum_out <= checksum;
		Spayload <= payload;
		Ssoma <= soma;
		ideal_seq_num_out <= ideal_seq_num;
		
		Validacao : Process(clk, rst)
			
			begin
			
			if rising_edge(clk) then
				if rst = '1' then
					synchronize 			<= '0';
					data 						<= (others => '0');
					estado 					<= (others => '0');
					estado2 					<= (others => '0');
					increment_pckt_len 	<= (others => '0');
					checksum 				<= (others => '0');
					payload 					<= (others => '0');
					soma 						<= (others => '0');
					ideal_seq_num 			<= (others => '0');
				else
					if valid = '1' then --vai ser alterado pelo master
						if transmission = '1' then	--vai ser alterado pelo master
							synchronize <= '1';
							case estado is
						
								when "0000" =>
									increment_pckt_len <= (others => '0');
									data(15 downto 8) <= unsigned(transmit_data);
									soma <= soma + data;
									ready <= '1';
									transmission <= '1';
									estado <= estado + 1;
								
								when "0001" =>
									data(7 downto 0) <= unsigned(transmit_data);
									--soma <= soma + data;
									if soma(16) = '1' then
										soma <= soma + 1;
										soma(16) <= '0';
									end if;
									ready <= '1';
									estado <= estado + 1;
								
								when "0010" =>
									soma <= soma + data;
									data <= (others => '0');	--validacao dos dados
									ready <= '1';
									estado <= estado + 1;
									
								when "0011" =>
									data <= (others => '0');	--validacao dos dados
									--soma <= soma + data;
									if soma(16) = '1' then
										soma <= soma + 1;
										soma(16) <= '0';
									end if;
									ready <= '1';
									estado <= estado + 1;
									
								when "0100" =>
									data(15 downto 8) <= unsigned(transmit_data);
									increment_pckt_len <= increment_pckt_len + 1;
									soma <= soma + data;
									ready <= '1';
									estado <= estado + 1;
									
								when "0101" =>
									data(7 downto 0) <= unsigned(transmit_data);
									--soma <= soma + data;
									if soma(16) = '1' then
										soma <= soma + 1;
										soma(16) <= '0';
									end if;
									ready <= '1';
									estado <= estado + 1;
									
								when "0110" =>
									data(15 downto 8) <= unsigned(transmit_data);
									soma <= soma + data;
									ready <= '1';
									estado <= estado + 1;
								
								when "0111" =>
									data(7 downto 0) <= unsigned(transmit_data);
									--soma <= soma + data;
									if soma(16) = '1' then
										soma <= soma + 1;
										soma(16) <= '0';
									end if;
									ready <= '1';
									estado <= estado + 1;

								when "1000" =>
									data(15 downto 8) <= unsigned(transmit_data);
									increment_pckt_len <= increment_pckt_len + 1;
									soma <= soma + data;
									ready <= '1';
									if first_receive = '0' then
										ideal_seq_num <= sequence_number_rx_usign;
									else
										ideal_seq_num <= ideal_seq_num + 1;	
									end if;
									estado <= estado + 1;
							
								when "1001" =>
									data(7 downto 0) <= unsigned(transmit_data);
									first_receive <= '1';
									if soma(16) = '1' then
										soma <= soma + 1;
										soma(16) <= '0';
									end if;
									ready <= '1';
									estado <= estado + 1;
									
								when "1010" =>
									data(15 downto 8) <= unsigned(transmit_data);
									soma <= soma + data;
									ready <= '1';
									estado <= estado + 1;
									
								when "1011" =>
									data(7 downto 0) <= unsigned(transmit_data);
									--soma <= soma + data;
									if soma(16) = '1' then
										soma <= soma + 1;
										soma(16) <= '0';
									end if;
									ready <= '1';
									estado <= estado + 1;
									
								when "1100" =>
									data(15 downto 8) <= unsigned(transmit_data);
									increment_pckt_len <= increment_pckt_len + 1;
									soma <= soma + data;
									ready <= '1';
									estado <= estado + 1;
									
								when "1101" =>
									data(7 downto 0) <= unsigned(transmit_data);
									--soma <= soma + data;
									if soma(16) = '1' then
										soma <= soma + 1;
										soma(16) <= '0';
									end if;
									ready <= '1';
									estado <= estado + 1;
									
								when "1110" =>
									data(15 downto 8) <= unsigned(transmit_data);
									soma <= soma + data;
									ready <= '1';
									estado <= estado + 1;
									
								when "1111" =>
									data(7 downto 0) <= unsigned(transmit_data);
									--soma <= soma + data;
									if soma(16) = '1' then
										soma <= soma + 1;
										soma(16) <= '0';
									end if;
									ready <= '0';	--comecar o processo de validacao do checksum e o pckt len
									synchronize <= '0';	--nao permito a troca de estados no header
									transmission <= '0';
									estado <= "0000";

								when others =>
									estado <= "0000";
							end case;
						else
							synchronize <= '0';
							case estado2 is
								when "000" =>
									ready <= '0';
									soma <= soma + data;
									increment_pckt_len <= increment_pckt_len + 1;
									estado2 <= estado2 + 1;
								
								when "001" =>
									ready <= '0';
									if soma(16) = '1' then
										soma <= soma + 1;
										soma(16) <= '0';
									end if;
									estado2 <= estado2 + 1;
								
								when "010" =>	--faco o checksum
									checksum <= not soma(15 downto 0);
									soma <= (others => '0');	--reseto a soma
									ready <= '0';
									estado2 <= estado2 + 1;
								
								when "011" =>	--faco o checksum
									if increment_pckt_len /= packet_len_rx_unsign then
										error <= "00001"; 
									elsif checksum /= checksum_rx_unsign then
										error <= "00010";
									elsif ideal_seq_num /= sequence_number_rx_usign then
										error <= "00100";
									end if;
									
									if Flags(0) = '1' then
									--close ativado zera o enereco atribuido a porta
									elsif Flags(7) = '1' then
									end if;
									--sync ativado atribui o endereco de origem a porta
									ready <= '1';
									synchronize <= '0';	--nao habilito o header para receber o payload
									soma <= (others => '0');
									data <= (others => '0');
									estado2 <= estado2 + 1;
								
								when "100" =>
									if last = '1' then --ultimo byte
										ready <= '1';
										synchronize <= '1'; --volto a ler o header
										payload <= transmit_data;
										transmission <= '1'; --volto a validar os dados
										estado2 <= "000";
									else
										contador_len_payload <= contador_len_payload + 1;
										if(contador_len_payload = X"04") then
											contador_len_payload <= (others => '0');
											increment_pckt_len <= increment_pckt_len + 1;
										end if;
										ready <= '1';
										synchronize <= '0';
										payload <= transmit_data;
										estado2 <= "100";
									end if;
								when others =>
									estado2 <= "000";
							end case;
						end if;
					end if;
				end if;
			end if;
		end process Validacao;
	
end architecture;