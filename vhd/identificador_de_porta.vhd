library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.numeric_std.all;

entity identificador_de_porta is
	port(
		signal clk			   				: in std_logic;
		signal rst			   				: in std_logic;
		signal validate_finish				: in std_logic;
		signal ERRO  						: out std_logic_vector(5 downto 0);
		signal ADDRESS_TABLE 				: in std_logic_vector(79 downto 0);
		signal DEST_ADDR					: in std_logic_vector(15 downto 0);
		signal FLAGS						: in std_logic_vector(7 downto 0);
		signal DEST_PORT                 	: out std_logic_vector(4 downto 0)
	);
end entity identificador_de_porta;

architecture hardware of identificador_de_porta is

signal ADDRESS_TABLE_i : std_logic_vector(79 downto 0) := (others => '0');


begin
	ADDRESS_TABLE_i <= ADDRESS_TABLE;
	
	TICK : process(clk, rst) is
	begin
		if rising_edge(clk) then
			if rst = '1' then
				
			else
				if validate_finish = '1' then
                if FLAGS = X"00" then
                    if ADDRESS_TABLE(15 downto 0) 		= DEST_ADDR then
                        DEST_PORT <= "00001";
                    
                    elsif ADDRESS_TABLE(31 downto 16) = DEST_ADDR then
                        DEST_PORT <= "00010";
                    
                    elsif ADDRESS_TABLE(47 downto 32) = DEST_ADDR then
                        DEST_PORT <= "00100";
                    
                    elsif ADDRESS_TABLE(63 downto 48) = DEST_ADDR then
                        DEST_PORT <= "01000";

                    elsif ADDRESS_TABLE(79 downto 64) = DEST_ADDR then
                        DEST_PORT <= "10000";
					
					else --endereco nao reconhecido
						ERRO <= "001000";
                    end if;
                end if;
				end if;
			end if;				
		end if;
	end process;
end architecture hardware;