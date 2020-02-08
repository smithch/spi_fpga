---------------------
-- Christopher Smith 
-- Feburary 20, 2013 
-- ECE 520 
-- Homework 2 
----------------------
-- SPI Master 
-- Waits for a write signal then shifts out the data input 
-- cpol and cpha are used to configure the spi clock 
-- The clock can be divided with the generic value CLK_DIV 
-- this module runs 2x slower then the system clock. So 
-- to divide by 50Mhz on the DE2 board to get 1Mhz use the 
-- value of 25.   


library IEEE; 
use IEEE.std_logic_1164.all; 
use IEEE.numeric_std.all; 

-- Entity and Architecture Definitions 
entity spi_master is 
  generic ( 
    REG_SIZE : integer := 8;
    CLK_DIV : integer := 25); -- This runs 2x slower then sys clock 
                              -- so to divide 50 Mhz to 1Mhz div by 25 not 50
  port (
   clk:       in  std_logic;   -- 1 Mhz provided by system  
	 data:      in  std_logic_vector(REG_SIZE-1 downto 0); 
	 write:     in  std_logic;  -- begin sending out register contents 
	 cpol:      in  std_logic; 
	 cpha:      in  std_logic; 
	 rst:       in  std_logic;
	 spi_clock: out std_logic;  
	 mosi:      out std_logic;
	 ss:        out std_logic); 
end entity spi_master; 

architecture spi_master of spi_master is
signal spi_clk : std_logic;  -- temp spi clock (twice as slow as clk)
signal tx_reg : std_logic_vector(REG_SIZE-1 downto 0);  -- temp transmit register
signal count  : integer;  -- count 
signal toggle_count : integer; 
type machine is (ready, low_cpha, high_cpha);
signal state : machine;
signal spi_en : std_logic; 
signal write_strobe : std_logic; 
signal write_strobe_sync0 : std_logic; 
signal write_strobe_sync1 : std_logic; 
begin

spi_clock <= spi_clk; 


process(clk,write_strobe_sync1, rst)
begin 
  if(rst = '0') then 
    mosi <= 'X'; 
    state <= ready; 
    count <= REG_SIZE; 
    ss <= '1'; 
  
  elsif rising_edge(clk) then 
    case state is 
      when ready => 
        tx_reg <= data;  -- load temp register with data
        mosi <= 'X';      
        count <= (REG_SIZE*2);  -- running 2x slower then clock
        toggle_count <= CLK_DIV; 
        spi_clk <= cpol;
        ss <= '1'; 
        if (write_strobe_sync1 = '1' and cpha = '0') then 
          spi_en <= '0';  -- delay the enable half an spi_clk period
          ss <= '0'; 
          state <= low_cpha;  
        elsif(write_strobe_sync1 = '1' and cpha = '1') then
          spi_en <= '1'; 
          ss <= '0'; 
          state <= high_cpha;
        else   
          state <= ready;
        end if;
    
       when low_cpha =>   
            if(toggle_count = 0) then   -- toggle spi_clk  CLK_DIV
              toggle_count <= CLK_DIV;  -- count for 1Mhz
              
             if(spi_en = '1') then      
              count <= count - 1;
              
                if(count /= 16) then    
                  spi_clk <= not spi_clk; -- makes this 2x slower then clk
                end if;
                
              else  -- send out mosi even if spi_clk isnt enabled for low cpha
                 mosi <= tx_reg(REG_SIZE-1);  -- shift out mosi 
                 tx_reg <= tx_reg(REG_SIZE-2 downto 0) & '0';
                spi_en <= '1'; 
              end if; 
              
               if(cpol /= spi_clk ) then 
                  mosi <= tx_reg(REG_SIZE-1); 
                  tx_reg <= tx_reg(REG_SIZE-2 downto 0) & '0';
              end if;  
              
              if(count = 0) then 
                state <= ready; 
              else 
                state <= low_cpha;
              end if;  
              
            else 
              toggle_count <= toggle_count - 1; 
            end if; 
        
         
            
        when high_cpha => 
          if(spi_en = '1') then 
            -- run spi at CLK_DIV 
            if(toggle_count = 0) then 
              count <= count - 1; 
              toggle_count <= CLK_DIV; 
              
              if(count /= 0) then 
                spi_clk <= not spi_clk; -- makes this 2x slower then clk
                -- shift out data to mosi 
                if(cpol = spi_clk ) then 
                  mosi <= tx_reg(REG_SIZE-1); 
                  tx_reg <= tx_reg(REG_SIZE-2 downto 0) & '0';
                end if; 
                
              end if; 
              -- Change to the next state 
              if(count = 0) then 
                state <= ready; 
              else 
                state <= high_cpha;
              end if;  
              
            else 
              toggle_count <= toggle_count - 1; 
            end if; 
            
         else 
           spi_en <= '1'; 
        end if;        
        
      end case;  
  end if; 
end process; 


-- Syncronize asyncrounous input 
latch_write: process(write, write_strobe_sync1, rst)
begin
  if(write_strobe_sync1 = '1' or rst = '0') then
    write_strobe <= '0'; 
  elsif rising_edge(write) then 
    write_strobe <= '1';  
  end if; 
end process; 

sync_write: process(clk, rst, write_strobe)
begin 
  if(rst = '0') then 
    write_strobe_sync0 <= '0'; 
    write_strobe_sync1 <= '0'; 
  elsif rising_edge(clk) then 
    write_strobe_sync0 <= write_strobe; 
    write_strobe_sync1 <= write_strobe_sync0;
  end if;  
end process; 

end architecture spi_master;  