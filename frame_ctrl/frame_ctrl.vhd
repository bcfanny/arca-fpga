-- frame controller
-- 
-- manages data flow between the various modules
-- puts output data in ASCII HEX into FIFO
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity frame_ctrl is
	port (
		clk	: in std_logic;
		rst	: in std_logic;
		sof	: in std_logic; -- start of frame
		inclk	: in std_logic; -- recovered clock
		d	: in std_logic; -- recovered data
		fifo_d	: out std_logic_vector(7 downto 0);
		fifo_we : out std_logic
	);
end frame_ctrl;

architecture behav of frame_ctrl is
	signal sr 	: std_logic_vector(7 downto 0) := (others => '0');
	signal lat 	: std_logic_vector(7 downto 0) := (others => '0');
	signal bitcnt	: unsigned(2 downto 0) := (others => '0');
	signal bytecnt	: unsigned(3 downto 0) := (others => '0');
	type state_type is (idle, frame, lf);
	signal state	: state_type := idle;
	signal restart	: std_logic := '0';
	signal first	: std_logic := '0';
	signal last 	: std_logic := '0';
	type wr_state_type is (high, low, none);
	signal wr_state : wr_state_type := none;
begin
	process
	begin
		wait until rising_edge(clk);
		if rst = '1' then
			sr <= (others => '0');
			lat <= (others => '0');
			bytecnt <= (others => '0');
			bitcnt <= (others => '0');
		else 
			case state is
				when idle =>
					first <= '1';
					last <= '0';
					fifo_we <= '0';
					bitcnt <= (others => '0');
					bytecnt <= (others => '0');
					if sof = '1' then
						state <= frame;
					end if;
				when frame =>
					restart <= '0';
					if inclk = '1' then
						first <= '0';
						sr(7 downto 0) <= sr(6 downto 0) & d; -- MSB first
						bitcnt <= bitcnt + to_unsigned(1, bitcnt'length);
						if bitcnt = 0 and first = '0' then
							lat <= sr;
							bytecnt <= bytecnt + to_unsigned(1, bytecnt'length);
							wr_state <= high; -- byte is ready
							if bytecnt = 0 then 
								-- check frame type
								-- set bytecnt correctly
							end if;
							if (bitcnt = 0) and (bytecnt = 14) then
								last <= '1';
							end if;
						end if;
					end if;
					case wr_state is
						when high =>
							fifo_we <= '1';
							-- TODO implement LUT
							fifo_d <= x"01";
							wr_state <= low;
						when low =>
							fifo_we <= '1';
							-- TODO implement LUT
							fifo_d <= x"02";
							wr_state <= none;
						when none =>
							fifo_we <= '0';
							state <= lf;
					end case;
					-- if sof = '1' then
						-- fifo_we <= '0';
						-- restart <= '1';
						-- state <= 'lf';
				when lf =>
					fifo_d <= x"0a";
					fifo_we <= '1';
					last <= '0';
					first <= '1';
					if restart = '1' then
						state <= frame;
					else
						state <= idle;
					end if;
			end case; -- state
		end if; -- reset
	end process;
end behav;
