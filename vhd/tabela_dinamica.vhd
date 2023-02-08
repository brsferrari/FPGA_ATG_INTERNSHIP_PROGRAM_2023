library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.numeric_std.all;

entity tabela_dinamica is
	port(
		signal clk			   			: in std_logic;
		signal rst			   			: in std_logic;
		signal DATA							: in std_logic_vector(7 downto 0);
		signal SRC_ADDR					: in std_logic_vector(7 downto 0);
		signal DEST_ADDR					: out std_logic_vector(7 downto 0);
		signal FLAGS						: in std_logic_vector(7 downto 0)
		);
end entity tabela_dinamica;

architecture hardware of tabela_dinamica is
type dynamic_table is array(4 downto 0) of std_logic_vector(7 downto 0);

signal table 	: dynamic_table;
signal addr 	: std_logic_vector(7 downto 0);
signal position : integer;

begin

	TICK : process(clk, rst) is
	begin
		if rising_edge(clk) then
			if rst = '1' then
				addr <= (others => '0');
			else
				addr <= SRC_ADDR;
				
				--sync e close analisar o endereco de origem e verificar onde o endereco de destino foi gravado para entao apagar
				if FLAGS(7) = '1' then --houve sync
					sync1 : for i in 0 to 4 loop
						if(table(i) = X"00") then
							table(i) <= addr;
						end if;
					
					end loop sync1;
	
				elsif FLAGS(0) = '1' then --houve close
					sync2 : for i in 0 to 4 loop
						if(table(i) /= X"00") then
							table(i) <= (others => '0');
						end if;
					end loop sync2;					
				else  --varredura para verificar se o endereco existe em uma das portas.
					sending : for i in 0 to 4 loop
						if(table(i) = SRC_ADDR) then
							DEST_ADDR <= DATA;
						end if;
					end loop sending;	
				end if;
			end if;
		end if;
	end process;

end architecture hardware;