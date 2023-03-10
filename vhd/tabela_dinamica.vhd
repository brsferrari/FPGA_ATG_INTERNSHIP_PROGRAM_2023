library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--atribui um endereco a uma porta

--indicar se o endereco esta em alguma porta -> out -> porta e seu respectivo endereco
entity tabela_dinamica is
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
end entity tabela_dinamica;

architecture hardware of tabela_dinamica is
type dynamic_table is array(4 downto 0) of std_logic_vector(15 downto 0);
type seq_table is array(4 downto 0) of unsigned(31 downto 0);


signal table 				: dynamic_table;
signal table_seq_num 	: seq_table;
signal addr 	: std_logic_vector(15 downto 0);
signal port_i 	: std_logic_vector(4 downto 0);
signal ADDRESS_TABLE_i : std_logic_vector(79 downto 0) := (others => '0');
signal flag_i : std_logic_vector (7 downto 0) := (others => '0');
signal seqnum_out						:  unsigned(31 downto 0);
signal estado : std_logic := '0';
signal FLAG_de_seqnum_i : std_logic_vector(5 downto 0);

begin

	addr <= SRC_ADDR;
	port_i <= PORTA;
	ADDRESS_TABLE <= ADDRESS_TABLE_i;
	flag_i <= FLAGS;
		
	seqnum_component <= seqnum_out;
		
	FLAG_de_seqnum <= FLAG_de_seqnum_i;
	
	TICK : process(clk, rst) is
	begin
		if rising_edge(clk) then
			if rst = '1' then
				addr <= (others => '0');
			else
				FLAG_de_seqnum_i <= ERRO_da_validacao;
				--ADDRESS_TABLE <=
				read_table : for i in 0 to 4 loop
					case i is
						when 0 =>
							ADDRESS_TABLE_i(15 downto 0) <= table(0);
						
						when 1 =>
							ADDRESS_TABLE_i(31 downto 16) <= table(1);
					
						when 2 =>
							ADDRESS_TABLE_i(47 downto 32) <= table(2);
					
						when 3 =>
							ADDRESS_TABLE_i(63 downto 48) <= table(3);
				
						when 4 =>
							ADDRESS_TABLE_i(79 downto 64) <= table(4);
					end case;
				end loop read_table;

				if  validate_finish = '1' then	--terminou a validacao
					if  ERRO_da_validacao(5) = '1' or ERRO_da_validacao(4) = '1' then		--nao houve erro
							--sync e close analisar o endereco de origem e verificar onde o endereco de destino foi gravado para entao apagar
						if flag_i(7) = '1' then --houve sync
							sync1 : for i in 0 to 4 loop
								if(port_i(i) = '1') then --eh a porta selecionada
									table_seq_num(i) <= seqnum;	--do header
									table(i) <= SRC_ADDR;  --linha onde ira o endereco
								end if;
							end loop sync1;
			
						elsif flag_i(0) = '1' then --houve close
							sync2 : for i in 0 to 4 loop
								if(port_i(i) = '1') then --eh a porta selecionada
									table_seq_num(i) <= (others => '0');
									table(i) <= (others => '0');
								end if;
							end loop sync2;		
						end if;
					end if;	
					if ERRO_da_validacao(5 downto 4) = "00" then	--sem erro
						if tlast = '1' then
							case estado is
								when '0' =>
									found_port : for i in 0 to 4 loop
										if(table(i) = SRC_ADDR) then --eh a porta selecionada
											table_seq_num(i) <= table_seq_num(i) + 1; --da validacao
											seqnum_out <= table_seq_num(i) + 1; 	--atribuindo valor novo
										end if;
									end loop found_port;
									estado <= '0';
									
								when '1' =>
									if seqnum_out /= seqnum then
										FLAG_de_seqnum_i(2) <= '1';
									else 
										FLAG_de_seqnum_i(2) <= '0';
										estado <= '0';
									end if;	
								end case;
						end if;
					end if;
					SRC_ADDR_out <= SRC_ADDR;
				end if;
			end if;				
		end if;
	end process;
end architecture hardware;