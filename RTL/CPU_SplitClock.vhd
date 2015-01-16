------------------------------------------------------------------------------
------------------------------------------------------------------------------
--                                                                          --
-- Copyright (c) 2009-2011 Tobias Gubener                                   -- 
-- Subdesign fAMpIGA by TobiFlex                                            --
-- Redesigned by Alastair M. Robinson to run the CPU at 28MHz instead       --
-- of ~113.5Mhz                                                             --
--                                                                          --
-- Fast RAM / AutoConfig still to be implemented
--
-- This is the TOP-Level for TG68KdotC_Kernel to generate 68K Bus signals   --
--                                                                          --
-- This source file is free software: you can redistribute it and/or modify --
-- it under the terms of the GNU General Public License as published        --
-- by the Free Software Foundation, either version 3 of the License, or     --
-- (at your option) any later version.                                      --
--                                                                          --
-- This source file is distributed in the hope that it will be useful,      --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of           --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            --
-- GNU General Public License for more details.                             --
--                                                                          --
-- You should have received a copy of the GNU General Public License        --
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.    --
--                                                                          --
------------------------------------------------------------------------------
------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity CPU_SplitClock is
   port(        
		clk           : in std_logic;
		clk28         : in std_logic;
		reset         : in std_logic;
        clkena_in     : in std_logic:='1';
        IPL           : in std_logic_vector(2 downto 0):="111";
        dtack         : in std_logic;
        addr          : buffer std_logic_vector(31 downto 0);
        data_read  	  : in std_logic_vector(15 downto 0);
        data_write 	  : buffer std_logic_vector(15 downto 0);
        as            : out std_logic;
        uds           : out std_logic;
        lds           : out std_logic;
        rw            : out std_logic;
        wrd           : out std_logic;
        ena7RDreg      : in std_logic:='1';
        ena7WRreg      : in std_logic:='1';
        enaWRreg      : in std_logic:='1';
        
        fromram    	  : in std_logic_vector(15 downto 0);
        toram    	  : out std_logic_vector(15 downto 0);
        ramready      : in std_logic:='0';
        cpu           : in std_logic_vector(1 downto 0);
		  fastramcfg	: in std_logic_vector(2 downto 0);
		  turbochipram : in std_logic;
        ramaddr    	  : out std_logic_vector(31 downto 0);
        cpustate      : out std_logic_vector(5 downto 0);
		nResetOut	  : out std_logic;
        skipFetch     : buffer std_logic;
        cpuDMA         : buffer std_logic;
        ramlds        : out std_logic;
        ramuds        : out std_logic
        );
end CPU_SplitClock;

ARCHITECTURE logic OF CPU_SplitClock IS

   SIGNAL cpuaddr     : std_logic_vector(31 downto 0);
   SIGNAL cpuaddr_r   : std_logic_vector(31 downto 0);
   SIGNAL cpuIPL      : std_logic_vector(2 downto 0);
   SIGNAL uds_in	  : std_logic;
   SIGNAL lds_in	  : std_logic;
   SIGNAL busstate       : std_logic_vector(1 downto 0);
   SIGNAL busstate_r     : std_logic_vector(1 downto 0);
	signal ramcs : std_logic;
	signal ramcs_r : std_logic;
	signal ramready28 : std_logic;
	signal ramready113 : std_logic;
   SIGNAL clkena	  : std_logic;
--   SIGNAL n_clk		  : std_logic;

	type  bridge_states is (idle, run, cpuread, cpuread2, cpuwrite, cpuwait, autoconfig, fastramwait);
	signal bridge_state : bridge_states:=idle;
	signal bridge_clkena : std_logic;
	
   SIGNAL datatg68_in      : std_logic_vector(15 downto 0);
   SIGNAL datatg68_out      : std_logic_vector(15 downto 0);

	signal sel_interrupt : std_logic;
	signal sel_32bit : std_logic;
	signal sel_chipram : std_logic;
	signal sel_autoconfig : std_logic;
	signal sel_zorroii : std_logic;
	signal sel_zorroiii : std_logic;
	signal cpu_rw : std_logic;
	signal ac_data1 : std_logic_vector(3 downto 0);
	signal ac_data2 : std_logic_vector(3 downto 0);
	signal autoconfig_data : std_logic_vector(3 downto 0);
	signal ac_req : std_logic;
	signal ac2_req : std_logic;

BEGIN
	
--
pf68K_Kernel_inst: entity work.TG68KdotC_Kernel 
--		pf68K_Kernel_inst: entity work.DummyCPU
--		pf68K_Kernel_inst: entity work.ZPU_Bridge
	generic map(
		SR_Read => 2,         	--0=>user,   1=>privileged,      2=>switchable with CPU(0)
		VBR_Stackframe => 2,  	--0=>no,     1=>yes/extended,    2=>switchable with CPU(0)
		extAddr_Mode => 2,    	--0=>no,     1=>yes,    2=>switchable with CPU(1)
		MUL_Mode => 2,	   		--0=>16Bit,  1=>32Bit,  2=>switchable with CPU(1),  3=>no MUL,  
		DIV_Mode => 2		  	 --0=>16Bit,  1=>32Bit,  2=>switchable with CPU(1),  3=>no DIV,  
		)
  PORT MAP(
        clk => clk28,               	-- : in std_logic;
        nReset => reset,            -- : in std_logic:='1';			--low active
        clkena_in => clkena,	        -- : in std_logic:='1';
        data_in => datatg68_in,       -- : in std_logic_vector(15 downto 0);
		IPL => cpuIPL,				  	-- : in std_logic_vector(2 downto 0):="111";
		IPL_autovector => '1',   	-- : in std_logic:='0';
        addr => cpuaddr,           	-- : buffer std_logic_vector(31 downto 0);
        data_write => datatg68_out,     -- : out std_logic_vector(15 downto 0);
		busstate => busstate,	  	  	-- : buffer std_logic_vector(1 downto 0);	
        regin => open,          	-- : out std_logic_vector(31 downto 0);
		nWr => open,			  	-- : out std_logic;
		nUDS => uds_in,
		nLDS => lds_in,	  			-- : out std_logic;
		nResetOut => nResetOut,
		CPU => cpu,
		skipFetch => skipFetch 		-- : out std_logic
        );

cpuIPL <= IPL;
clkena<='1' when bridge_clkena='1' or busstate="01" else '0';
		  
PROCESS (clk28)
	BEGIN
		IF rising_edge(clk28) THEN
			IF reset='0' THEN
				as<='1';
				uds<='1';
				lds<='1';
				rw<='1';
				addr<=(others => '0');
				bridge_state<=idle;
				ramcs<='1';
			else
				bridge_clkena<='0';
				case bridge_state is
					when idle =>
						as<='1';
						uds<='1';
						lds<='1';
						rw<='1';
						if ena7WRreg='1' then
							addr<=cpuaddr;
							uds<=uds_in;
							lds<=lds_in;
							ac_req<='0';
							case busstate is
								when "00" => -- Fetch instruction
									if sel_zorroii='1' or sel_zorroiii='1' then
										ramcs<='0';
										bridge_state<=fastramwait;
									else
										as<='0';
										bridge_state<=cpuread;
									end if;
								when "01" => -- Decode
									null;
								when "10" => -- Read data
									if sel_autoconfig='1' then
										bridge_state<=autoconfig;
									elsif sel_zorroii='1' or sel_zorroiii='1' then
										ramcs<='0';
										bridge_state<=fastramwait;
									else
										as<='0';
										bridge_state<=cpuread;
									end if;
								when "11" => -- Write data
									if sel_autoconfig='1' then
										ac_req<='1';
										bridge_state<=autoconfig;
									elsif sel_zorroii='1' or sel_zorroiii='1' then
										ramcs<='0';
										bridge_state<=fastramwait;
									else
										as<='0';
										rw<='0';
										data_write<=datatg68_out;
										bridge_clkena<='1';
										bridge_state<=cpuwrite;
									end if;
							end case;
						end if;
					when cpuread =>
						if dtack='0' and ena7RDreg='1' then
							bridge_state<=cpuread2;
						end if;
					when cpuread2 =>
						datatg68_in<=data_read;
						bridge_clkena<='1';
						bridge_state<=cpuwait;
					when cpuwrite =>
						if dtack='0' and ena7RDreg='1' then
							bridge_state<=cpuwait;
							rw<='1';
						end if;					
					when cpuwait =>
						as<='1';
						uds<='1';
						lds<='1';
						if ena7WRreg='1' then
							bridge_state<=idle;
						end if;
					when fastramwait =>
						null;
					when autoconfig =>
						datatg68_in<=autoconfig_data&X"FFF";
						bridge_clkena<='1';
						bridge_state<=run;
					when run =>
						bridge_state<=idle;
				end case;

				-- When Fast RAM access finishes, force the state machine back to the "idle" state
				if ramready28='1' then
					datatg68_in<=fromram;
					bridge_clkena<='1';
					bridge_state<=run;
					ramcs<='1';
				end if;
			
			END IF;
		END IF;	
	END PROCESS;

-- Register the CPU signals within the fast clock domain, to reduce timing pressure
-- on the CPU, cache and SDRAM controller.
	process(clk)
	begin
		if rising_edge(clk) then
			if reset='0' then
				ramready113<='0';
			else 
				toram <= datatg68_out;
				cpuaddr_r <= cpuaddr;
				ramuds <= uds_in;
				ramlds <= lds_in;
				busstate_r <= busstate;
				ramcs_r <= ramcs;
				
				-- Fast RAM handshaking
				if ramcs='1' then
					ramready113<='0';
				end if;
				if ramready='1' then
					ramready113<='1';
				end if;
			end if;
		end if;
	end process;
	
	ramready28<=ramready or ramready113;
	cpustate <= "000" & (ramcs_r or ramready28) & busstate_r;

-- Address decoding

sel_interrupt <= '1' when cpuaddr(31 downto 28)=X"F" else '0';
sel_32bit <= '0' when cpuaddr(31 downto 24)=X"00" else '1';
sel_chipram <= '1' when cpuaddr(31 downto 21)=X"00"&"111" else '0';
sel_autoconfig <= '1' when cpuaddr(23 downto 19)="11101" ELSE '0'; --$E80000 - $EFFFFF

cpu_rw <= '0' when busstate="11" else '1';


-- Fast RAM address mangling
ramaddr(22 downto 0) <= cpuaddr_r(22 downto 0);
ramaddr(31 downto 25) <= "0000000";


-- Register the high bits.
process(clk)
begin
	if rising_edge(clk) then
		ramaddr(24) <= sel_zorroiii;	-- Remap the Zorro III RAM to 0x1000000
		ramaddr(23) <= sel_zorroii; -- Remap the Zorro II RAM to 0x0800000
	end if;
end process;


-- Autoconfig

autoconfig_zii : entity work.AutoconfigRAM(ZorroII)
port map(
	clk => clk28,
	reset_n => reset,
	addr_in => cpuaddr,
	data_in => datatg68_out,
	data_out => ac_data1,
	config => fastramcfg(1 downto 0),
	rw => cpu_rw,
	req => ac_req,
	req_out => ac2_req,
	sel => sel_zorroii
);


autoconfig_ziii : entity work.AutoconfigRAM(ZorroIII)
port map(
	clk => clk28,
	reset_n => reset,
	addr_in => cpuaddr,
	data_in => datatg68_out,
	data_out => ac_data2,
	config => '0'&fastramcfg(2),
	rw => cpu_rw,
	req => ac2_req,
	req_out => open,
	sel => sel_zorroiii
);

autoconfig_data<=ac_data1 and ac_data2;

END;	
