--************************************************************************
-- @author:         Andreas Kaeberlein
-- @copyright:      Copyright 2021
-- @credits:        AKAE
--
-- @license:        BSDv3
-- @maintainer:     Andreas Kaeberlein
-- @email:          andreas.kaeberlein@web.de
--
-- @note:           VHDL'93
-- @file:           generic_spi_master_tb.vhd
-- @date:           2021-01-27
--
-- @see:            https://github.com/akaeba/generic_spi_master
-- @brief:          testbench
--
--************************************************************************



--------------------------------------------------------------------------
library IEEE;
    use IEEE.std_logic_1164.all;
    use IEEE.numeric_std.all;
    use ieee.math_real.all; --! for UNIFORM, TRUNC
library work;
--------------------------------------------------------------------------



--------------------------------------------------------------------------
-- testbench
entity generic_spi_master_tb is
generic (
            DO_ALL_TEST : boolean := false  --! switch for enabling all tests
        );
end entity generic_spi_master_tb;
--------------------------------------------------------------------------



--------------------------------------------------------------------------
architecture sim of generic_spi_master_tb is

    -----------------------------
    -- Constant
        -- DUT
        constant SPI_MODE       : integer range 0 to 3  := 0;
        constant NUM_CS         : integer               := 2;
        constant DW_SFR         : integer               := 8;
        constant CLK_HZ         : positive              := 50_000_000;
        constant SCK_HZ         : positive              := 1_000_000;
        constant RST_ACTIVE     : bit                   := '1';
        constant MISO_SYNC_STG  : natural               := 0;
        constant MISO_FILT_STG  : natural               := 0;

        -- Clock
        constant tclk   : time  := 1 sec / CLK_HZ;  --! 50MHz clock
        constant tskew  : time  := tclk / 50;       --! data skew

        -- Test
        constant loop_iter  : integer := 20;    --! number of test loop iteration
        constant do_test_0  : boolean := true;  --! test0:
    -----------------------------


    -----------------------------
    -- Signal
        -- DUT
        signal RST      : std_logic;
        signal CLK      : std_logic;
        signal SCK      : std_logic;
        signal CSN      : std_logic_vector(NUM_CS-1 downto 0);
        signal MOSI     : std_logic;
        signal MISO     : std_logic;
        signal DI       : std_logic_vector(DW_SFR-1 downto 0);
        signal DO       : std_logic_vector(DW_SFR-1 downto 0);
        signal EN       : std_logic;
        signal BSY      : std_logic;
        signal DO_WR    : std_logic_vector(NUM_CS-1 downto 0);
        signal DI_RD    : std_logic_vector(NUM_CS-1 downto 0);
        -- Test
        signal DI_CS0   : std_logic_vector(DI'range);
        signal DI_CS1   : std_logic_vector(DI'range);
        signal DO_CS0   : std_logic_vector(DI'range);
        signal DO_CS1   : std_logic_vector(DI'range);
        signal miso_reg : std_logic_vector(DI'range);
        signal mosi_reg : std_logic_vector(DI'range);
    -----------------------------

begin

    ----------------------------------------------
    -- DUT
    DUT : entity work.generic_spi_master
        generic map (
                        SPI_MODE        => SPI_MODE,
                        NUM_CS          => NUM_CS,
                        DW_SFR          => DW_SFR,
                        CLK_HZ          => CLK_HZ,
                        SCK_HZ          => SCK_HZ,
                        RST_ACTIVE      => RST_ACTIVE,
                        MISO_SYNC_STG   => MISO_SYNC_STG,
                        MISO_FILT_STG   => MISO_FILT_STG
                    )
        port map    (
                        RST   => RST,
                        CLK   => CLK,
                        CSN   => CSN,
                        SCK   => SCK,
                        MOSI  => MOSI,
                        MISO  => MISO,
                        DI    => DI,
                        DO    => DO,
                        EN    => EN,
                        BSY   => BSY,
                        DO_WR => DO_WR,
                        DI_RD => DI_RD
                    );
    ----------------------------------------------


    ----------------------------------------------
    -- Performs tests
    p_stimuli_process : process
    begin

        -------------------------
        -- Init
        -------------------------
            Report "Init...";
            RST     <=  '1';
            EN      <=  '0';
            wait for 5*tclk;
            wait until rising_edge(CLK); wait for tskew;
            RST     <=  '0';
            wait until rising_edge(CLK); wait for tskew;
            wait until rising_edge(CLK); wait for tskew;
        -------------------------


        -------------------------
        -- Test0: Transmit
        -------------------------
        if ( DO_ALL_TEST or do_test_0 ) then
            Report "Test0: Send/receive data byte";
            wait until rising_edge(CLK); wait for tskew;
            EN      <=  '1';
            DI_CS0  <= x"AA";
            DI_CS1  <= x"55";
            DO_CS0  <= x"47";
            DO_CS1  <= x"12";
            wait until rising_edge(CLK); wait for tskew;
            EN      <=  '0';
            while ( '1' = BSY ) loop
                wait until rising_edge(CLK); wait for tskew;
            end loop;
            wait for 10*tclk;
        end if;
        -------------------------


        -------------------------
        -- Report TB
        -------------------------
            Report "End TB...";     -- sim finished
            wait;                   -- stop process continuous run
        -------------------------

    end process p_stimuli_process;
    ----------------------------------------------


    ----------------------------------------------
    -- Selects DI
    DI  <=  DI_CS0              when ( "01" = DI_RD ) else
            DI_CS1              when ( "10" = DI_RD ) else
            (others => 'X');
    ----------------------------------------------


    ----------------------------------------------
    -- MISO SFR
    p_miso_sfr : process ( SCK, CSN )
    begin
        if ( falling_edge(CSN(0)) ) then
            miso_reg <= DO_CS0;
        elsif( falling_edge(CSN(1)) ) then
            miso_reg <= DO_CS1;
        elsif ( falling_edge(SCK) ) then
            miso_reg <= miso_reg(miso_reg'left-1 downto miso_reg'right) & '0';
        end if;
    end process p_miso_sfr;
    -- output
    MISO <= miso_reg(miso_reg'left) when ( '0' = CSN(0) or '0' = CSN(1) ) else 'Z'; --! gate output
    MISO <= 'L';                                                                    --! pull down
    ----------------------------------------------


    ----------------------------------------------
    -- MOSI SFR
    p_mosi_sfr : process ( SCK, CSN )
    begin
        if ( '0' = CSN(0) or '0' = CSN(1) ) then
            if ( rising_edge(SCK) ) then
                mosi_reg <= mosi_reg(mosi_reg'left-1 downto mosi_reg'right) & MOSI;
            end if;
        end if;
    end process p_mosi_sfr;
    ----------------------------------------------


    ----------------------------------------------
    -- clock
    p_clk : process
        variable v_clk : std_logic := '0';
    begin
        while true loop
            CLK     <= v_clk;
            v_clk   := not v_clk;
            wait for tclk/2;
            end loop;
    end process p_clk;
    ----------------------------------------------

end architecture sim;
--------------------------------------------------------------------------
