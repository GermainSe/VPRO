--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_datawidths.all;

ENTITY idma_fifo IS
	GENERIC(
		DWIDTH_WR         : integer := 32; -- data width at write port
		DWIDTH_RD         : integer := 32; -- data width at read port
		DEPTH_WR          : integer := 2; -- fifo depth (number of words with write data width), must be a power of 2
		AWIDTH_WR         : integer := 1; -- address width of memory write port, set to log2(DEPTH_WR)
		AWIDTH_RD         : integer := 1; -- address width of memory read port,  set to log2(DEPTH_WR*DWIDTH_WR/DWIDTH_RD)
		ASYNC             : integer := 0; -- 0: sync fifo, 1: async fifo
		ADD_READ_SYNC_REG : integer := 0; -- 0: 2 sync regs for async fifo on read side, 1: 1 cycle additional delay for rd_count+rd_empty
		SYNC_OUTREG       : integer := 1; -- 0: no read data output register if sync fifo, 1: always generate output register
		BIG_ENDIAN        : integer := 1 -- 0: big endian conversion if DWIDTH_WR /= DWIDTH_RD
	-- 1: little endian conversion if DWIDTH_WR /= DWIDTH_RD
	);

	PORT(
		-- *** write port ***
		clk_wr     : IN  std_ulogic;
		reset_n_wr : IN  std_ulogic;
		clken_wr   : IN  std_ulogic;
		flush_wr   : IN  std_ulogic;
		wr_free    : OUT std_ulogic_vector(AWIDTH_WR DOWNTO 0); -- number of free fifo entries
		wr_full    : OUT std_ulogic;
		wr_en      : IN  std_ulogic;
		wdata      : IN  std_ulogic_vector(DWIDTH_WR - 1 DOWNTO 0);
		-- *** read port ***
		clk_rd     : IN  std_ulogic;
		reset_n_rd : IN  std_ulogic;
		clken_rd   : IN  std_ulogic;
		flush_rd   : IN  std_ulogic;
		rd_count   : OUT std_ulogic_vector(AWIDTH_RD DOWNTO 0); -- number of valid fifo entries
		rd_empty   : OUT std_ulogic;
		rd_en      : IN  std_ulogic;
		rdata      : OUT std_ulogic_vector(DWIDTH_RD - 1 DOWNTO 0)
	);
END idma_fifo;

ARCHITECTURE behavioral OF idma_fifo IS

	-- conditional operator ( ? : )
	FUNCTION conditional(sel : boolean; x : integer; y : integer) RETURN integer IS
	BEGIN
		IF sel THEN
			RETURN x;
		ELSE
			RETURN y;
		END IF;
	END FUNCTION conditional;

	-- maximum
	FUNCTION max(x : integer; y : integer) RETURN integer IS
	BEGIN
		RETURN conditional(x > y, x, y);
	END FUNCTION max;

	-- minimum
	FUNCTION min(x : integer; y : integer) RETURN integer IS
	BEGIN
		RETURN conditional(x < y, x, y);
	END FUNCTION min;

	-- bin <-> gray conversion functions
	FUNCTION bin2gray(
		SIGNAL bin : std_ulogic_vector) -- binary input data
		RETURN std_ulogic_vector IS
	BEGIN                               -- bin2gray
		RETURN to_stdulogicvector(to_bitvector(bin) SRL 1) XOR bin;
	END bin2gray;

	FUNCTION gray2bin(
		SIGNAL gray : std_ulogic_vector) -- gray code input
		RETURN std_ulogic_vector IS
		VARIABLE bin : std_ulogic_vector(gray'range);
	BEGIN                               -- gray2bin
		FOR bit_bin IN bin'range LOOP
			bin(bit_bin) := '0';
			FOR bit_gray IN bit_bin TO gray'high LOOP
				bin(bit_bin) := bin(bit_bin) XOR gray(bit_gray);
			END LOOP;
		END LOOP;
		RETURN bin;
	END gray2bin;

	-- 1 additional address bit for counters to distinguish empty/full fifo
	SIGNAL fifo_addr_wr_bin       : std_ulogic_vector(AWIDTH_WR DOWNTO 0);
	SIGNAL fifo_addr_wr_bin_ff    : std_ulogic_vector(fifo_addr_wr_bin'range);
	SIGNAL fifo_addr_wr_bin_inc   : std_ulogic_vector(fifo_addr_wr_bin'range);
	SIGNAL fifo_addr_wr_gray      : std_ulogic_vector(fifo_addr_wr_bin'range);
	SIGNAL fifo_addr_wr_gray_meta : std_ulogic_vector(fifo_addr_wr_bin'range);
	SIGNAL fifo_addr_wr_gray_sync : std_ulogic_vector(fifo_addr_wr_bin'range);
	SIGNAL fifo_addr_wr_bin_sync  : std_ulogic_vector(fifo_addr_wr_bin'range);
	SIGNAL fifo_addr_rd_bin_ext   : std_ulogic_vector(fifo_addr_wr_bin'range);
	SIGNAL fifo_addr_rd_bin       : std_ulogic_vector(AWIDTH_RD DOWNTO 0);
	SIGNAL fifo_addr_rd_bin_ff    : std_ulogic_vector(fifo_addr_rd_bin'range);
	SIGNAL fifo_addr_rd_bin_inc   : std_ulogic_vector(fifo_addr_rd_bin'range);
	SIGNAL fifo_addr_rd_gray      : std_ulogic_vector(fifo_addr_rd_bin'range);
	SIGNAL fifo_addr_rd_gray_meta : std_ulogic_vector(fifo_addr_rd_bin'range);
	SIGNAL fifo_addr_rd_gray_sync : std_ulogic_vector(fifo_addr_rd_bin'range);
	SIGNAL fifo_addr_rd_bin_sync  : std_ulogic_vector(fifo_addr_rd_bin'range);
	SIGNAL fifo_addr_wr_bin_ff_d1 : std_ulogic_vector(fifo_addr_wr_bin'range);
	SIGNAL fifo_addr_wr_bin_ext   : std_ulogic_vector(fifo_addr_rd_bin'range);

	CONSTANT AWIDTH_RAM : integer := min(AWIDTH_WR, AWIDTH_RD);
	CONSTANT DWIDTH_RAM : integer := max(DWIDTH_WR, DWIDTH_RD);

	TYPE ram_type IS ARRAY (0 TO 2 ** AWIDTH_RAM - 1) OF std_ulogic_vector(DWIDTH_RAM - 1 DOWNTO 0);
	SIGNAL ram          : ram_type;
	SIGNAL ram_waddr    : unsigned(max(AWIDTH_RAM - 1, 0) DOWNTO 0);
	SIGNAL ram_wwe      : unsigned(DWIDTH_RAM / DWIDTH_WR - 1 DOWNTO 0);
	SIGNAL ram_raddr    : unsigned(max(AWIDTH_RAM - 1, 0) DOWNTO 0);
	SIGNAL ram_rsubword : integer RANGE 0 TO DWIDTH_RAM / DWIDTH_RD - 1;
	SIGNAL ram_rdata    : std_ulogic_vector(DWIDTH_RAM - 1 DOWNTO 0);
	SIGNAL ram_wdata    : std_ulogic_vector(DWIDTH_RAM - 1 DOWNTO 0);

	SIGNAL fifo_empty, fifo_empty_ff, fifo_empty_next          : boolean;
	SIGNAL fifo_rd_count, fifo_rd_count_ff, fifo_rd_count_next : std_ulogic_vector(rd_count'range);

	SIGNAL fifo_rdata    : std_ulogic_vector(rdata'range);
	SIGNAL fifo_rdata_ff : std_ulogic_vector(rdata'range);

BEGIN

	-----------------------------------------------------------------------------
	-- clock domain write port
	-----------------------------------------------------------------------------

	-- fifo address counter is gray coded for async fifo
	fifo_addr_wr_bin     <= gray2bin(fifo_addr_wr_gray) WHEN ASYNC /= 0 ELSE fifo_addr_wr_bin_ff;
	fifo_addr_wr_bin_inc <= std_ulogic_vector(unsigned(fifo_addr_wr_bin) + 1);

	fifo_addr_wr_reg : PROCESS(clk_wr, reset_n_wr)
	BEGIN
		IF reset_n_wr = active_reset_c THEN
			fifo_addr_wr_gray   <= (OTHERS => '0');
			fifo_addr_wr_bin_ff <= (OTHERS => '0');
		ELSIF clk_wr'event AND clk_wr = '1' THEN
			IF clken_wr = '1' THEN
				IF flush_wr = '1' THEN
					fifo_addr_wr_gray   <= (OTHERS => '0');
					fifo_addr_wr_bin_ff <= (OTHERS => '0');
				ELSIF wr_en = '1' THEN
					fifo_addr_wr_gray   <= bin2gray(fifo_addr_wr_bin_inc);
					fifo_addr_wr_bin_ff <= fifo_addr_wr_bin_inc;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	-- address synchronizer, synchronized address must be gray coded
	r2w_sync_reg : PROCESS(clk_wr, reset_n_wr)
	BEGIN
		IF reset_n_wr = active_reset_c THEN
			fifo_addr_rd_gray_meta <= (OTHERS => '0');
			fifo_addr_rd_gray_sync <= (OTHERS => '0');
		ELSIF clk_wr'event AND clk_wr = '1' THEN
			IF clken_wr = '1' THEN
				fifo_addr_rd_gray_meta <= fifo_addr_rd_gray;
				fifo_addr_rd_gray_sync <= fifo_addr_rd_gray_meta;
			END IF;
		END IF;
	END PROCESS;

	fifo_addr_rd_bin_sync <= gray2bin(fifo_addr_rd_gray_sync) WHEN ASYNC /= 0 ELSE fifo_addr_rd_bin_ff;

	-- extend / truncate sync'ed address
	extend_addr_rd : PROCESS(fifo_addr_rd_bin_sync)
		VARIABLE addr_words : std_ulogic_vector(max(AWIDTH_WR, AWIDTH_RD) DOWNTO 0);
	BEGIN
		addr_words                                                     := (OTHERS => '0');
		addr_words(addr_words'high DOWNTO addr_words'high - AWIDTH_RD) := fifo_addr_rd_bin_sync;

		fifo_addr_rd_bin_ext <= addr_words(addr_words'high DOWNTO addr_words'high - AWIDTH_WR);
	END PROCESS;

	-- number of free entries in fifo
	free : PROCESS(fifo_addr_rd_bin_ext, fifo_addr_wr_bin, flush_wr)
		VARIABLE wr_free_temp : unsigned(fifo_addr_wr_bin'range);
	BEGIN
		wr_free_temp := to_unsigned(DEPTH_WR, wr_free_temp'length);
		IF flush_wr = '0' THEN
			wr_free_temp := wr_free_temp - unsigned(fifo_addr_wr_bin) + unsigned(fifo_addr_rd_bin_ext);
		END IF;
		wr_free <= std_ulogic_vector(wr_free_temp);

		wr_full <= '1';
		IF flush_wr = '1' THEN
			wr_full <= '0';
		END IF;
		IF fifo_addr_wr_bin(AWIDTH_WR) = fifo_addr_rd_bin_ext(AWIDTH_WR) THEN
			wr_full <= '0';
		END IF;
		FOR i IN AWIDTH_WR - 1 DOWNTO 0 LOOP
			IF fifo_addr_wr_bin(i) /= fifo_addr_rd_bin_ext(i) THEN
				wr_full <= '0';
			END IF;
		END LOOP;
	END PROCESS;

	-----------------------------------------------------------------------------
	-- clock domain read port
	-----------------------------------------------------------------------------

	-- fifo address counter is gray coded for async fifo
	fifo_addr_rd_bin     <= gray2bin(fifo_addr_rd_gray) WHEN ASYNC /= 0 ELSE fifo_addr_rd_bin_ff;
	fifo_addr_rd_bin_inc <= std_ulogic_vector(unsigned(fifo_addr_rd_bin) + 1);

	fifo_addr_rd_reg : PROCESS(clk_rd, reset_n_rd)
	BEGIN
		IF reset_n_rd = active_reset_c THEN
			fifo_addr_rd_gray   <= (OTHERS => '0');
			fifo_addr_rd_bin_ff <= (OTHERS => '0');
		ELSIF clk_rd'event AND clk_rd = '1' THEN
			IF clken_rd = '1' AND (flush_rd = '1' OR rd_en = '1') THEN
				IF flush_rd = '1' THEN
					fifo_addr_rd_gray   <= (OTHERS => '0');
					fifo_addr_rd_bin_ff <= (OTHERS => '0');
				ELSE
					fifo_addr_rd_gray   <= bin2gray(fifo_addr_rd_bin_inc);
					fifo_addr_rd_bin_ff <= fifo_addr_rd_bin_inc;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	-- address synchronizer, synchronized address must be gray coded
	w2r_sync_reg : PROCESS(clk_rd, reset_n_rd)
	BEGIN
		IF reset_n_rd = active_reset_c THEN
			fifo_addr_wr_gray_meta <= (OTHERS => '0');
			fifo_addr_wr_gray_sync <= (OTHERS => '0');
		ELSIF clk_rd'event AND clk_rd = '1' THEN
			IF clken_rd = '1' THEN
				fifo_addr_wr_gray_meta <= fifo_addr_wr_gray;
				fifo_addr_wr_gray_sync <= fifo_addr_wr_gray_meta;
			END IF;
		END IF;
	END PROCESS;

	-- delayed write address for sync mode with output registers (read data also delayed!),
	-- registered rd_count and rd_empty
	waddr_delay_reg : PROCESS(clk_rd, reset_n_rd)
	BEGIN
		IF reset_n_rd = active_reset_c THEN
			fifo_addr_wr_bin_ff_d1 <= (OTHERS => '0');
			fifo_empty_ff          <= true;
			fifo_rd_count_ff       <= (OTHERS => '0');
		ELSIF clk_rd'event AND clk_rd = '1' THEN
			IF clken_rd = '1' THEN
				fifo_addr_wr_bin_ff_d1 <= fifo_addr_wr_bin_ff;
				fifo_empty_ff          <= fifo_empty_next;
				fifo_rd_count_ff       <= fifo_rd_count_next;
			END IF;
		END IF;
	END PROCESS;

	fifo_addr_wr_bin_sync <= gray2bin(fifo_addr_wr_gray_sync) WHEN ASYNC /= 0 ELSE fifo_addr_wr_bin_ff_d1 WHEN SYNC_OUTREG /= 0 ELSE fifo_addr_wr_bin_ff;

	-- extend / truncate sync'ed address
	extend_addr_wr : PROCESS(fifo_addr_wr_bin_sync)
		VARIABLE addr_words : std_ulogic_vector(max(AWIDTH_WR, AWIDTH_RD) DOWNTO 0);
	BEGIN
		addr_words                                                     := (OTHERS => '0');
		addr_words(addr_words'high DOWNTO addr_words'high - AWIDTH_WR) := fifo_addr_wr_bin_sync;

		fifo_addr_wr_bin_ext <= addr_words(addr_words'high DOWNTO addr_words'high - AWIDTH_RD);
	END PROCESS;

	-- number of valid entries in fifo
	PROCESS(fifo_addr_rd_bin, fifo_addr_rd_bin_inc, fifo_addr_wr_bin_ext, fifo_empty_ff, fifo_rd_count_ff, rd_en)
		VARIABLE fifo_addr_rd_bin_next : std_ulogic_vector(fifo_addr_rd_bin'range);
	BEGIN
		IF ASYNC /= 0 AND ADD_READ_SYNC_REG /= 0 THEN
			-- additional delay from fifo_addr_wr_gray_sync to rd_count and rd_empty
			fifo_empty    <= fifo_empty_ff;
			fifo_rd_count <= fifo_rd_count_ff;

			fifo_addr_rd_bin_next := fifo_addr_rd_bin;
			IF rd_en = '1' THEN
				fifo_addr_rd_bin_next := fifo_addr_rd_bin_inc;
			END IF;
			fifo_empty_next    <= fifo_addr_wr_bin_ext = fifo_addr_rd_bin_next;
			fifo_rd_count_next <= std_ulogic_vector(unsigned(fifo_addr_wr_bin_ext) - unsigned(fifo_addr_rd_bin_next));
		ELSE
			-- generate rd_count and rd_empty as fast as possible
			fifo_empty_next    <= true; -- unused
			fifo_rd_count_next <= (OTHERS => '0'); -- unused
			fifo_empty         <= fifo_addr_wr_bin_ext = fifo_addr_rd_bin;
			fifo_rd_count      <= std_ulogic_vector(unsigned(fifo_addr_wr_bin_ext) - unsigned(fifo_addr_rd_bin));
		END IF;
	END PROCESS;

	rd_count <= (OTHERS => '0') WHEN flush_rd = '1' ELSE fifo_rd_count;
	rd_empty <= '1' WHEN flush_rd = '1' OR fifo_empty ELSE '0';

	-----------------------------------------------------------------------------
	-- fifo ram
	-----------------------------------------------------------------------------

	-- write port
	PROCESS(fifo_addr_wr_bin, ram, wdata, wr_en)
		VARIABLE waddr   : unsigned(max(AWIDTH_WR - 1, 0) DOWNTO AWIDTH_WR - AWIDTH_RAM);
		VARIABLE saddr   : std_ulogic_vector(fifo_addr_wr_bin'range);
		VARIABLE subword : integer RANGE 0 TO DWIDTH_RAM / DWIDTH_WR - 1;
		variable nram    : std_ulogic_vector(DWIDTH_RAM - 1 DOWNTO 0);
	BEGIN
		-- write address
		waddr := (OTHERS => '0');
		FOR i IN AWIDTH_WR - 1 DOWNTO AWIDTH_WR - AWIDTH_RAM LOOP
			waddr(i) := fifo_addr_wr_bin(i);
		END LOOP;
		ram_waddr <= waddr;
		-- calculate subword
		saddr     := fifo_addr_wr_bin;
		FOR i IN AWIDTH_WR DOWNTO AWIDTH_WR - AWIDTH_RAM LOOP
			-- clear write address bits
			saddr(i) := '0';
		END LOOP;
		subword          := to_integer(unsigned(saddr));
		subword          := conditional(BIG_ENDIAN = 0, subword, DWIDTH_RAM / DWIDTH_WR - 1 - subword);
		-- word write enable
		ram_wwe          <= (OTHERS => '0');
		ram_wwe(subword) <= '1';

		nram := ram(to_integer(unsigned(waddr)));
		if wr_en = '1' then
			nram((subword + 1) * DWIDTH_WR - 1 DOWNTO subword * DWIDTH_WR) := wdata;
		end if;
		ram_wdata <= nram;
	END PROCESS;

	process(clk_wr)
	begin
		if clk_wr'event and clk_wr = '1' then
			if clken_wr = '1' and wr_en = '1' then
				ram(to_integer(unsigned(ram_waddr))) <= ram_wdata;
			end if;
		end if;
	end process;

	--PROCESS (clk_wr)
	--BEGIN
	--  IF clk_wr'event AND clk_wr = '1' THEN
	--    -- ram write
	--    FOR addr IN ram'range LOOP
	--      FOR subword IN ram_wwe'range LOOP
	--        IF clken_wr = '1' AND wr_en = '1' AND addr = ram_waddr AND ram_wwe(subword) = '1' THEN
	--          ram(addr)((subword+1)*DWIDTH_WR-1 DOWNTO subword*DWIDTH_WR) <= wdata;
	--        END IF;
	--      END LOOP;
	--    END LOOP;
	--  END IF;
	--END PROCESS;

	-- read port
	PROCESS(fifo_addr_rd_bin, fifo_addr_rd_bin_inc, fifo_empty)
		VARIABLE fifo_addr_rd : std_ulogic_vector(fifo_addr_rd_bin'range);
		VARIABLE raddr        : unsigned(max(AWIDTH_RD - 1, 0) DOWNTO AWIDTH_RD - AWIDTH_RAM);
		VARIABLE saddr        : std_ulogic_vector(fifo_addr_rd_bin'range);
		VARIABLE subword      : integer RANGE 0 TO DWIDTH_RAM / DWIDTH_RD - 1;
	BEGIN
		-- fifo read address
		fifo_addr_rd := fifo_addr_rd_bin;
		IF (ASYNC = 1 OR SYNC_OUTREG = 1) AND NOT fifo_empty THEN
			--  read data output register needs update from incremented address on rd_en = '1'
			fifo_addr_rd := fifo_addr_rd_bin_inc;
		END IF;
		-- memory read address
		raddr := (OTHERS => '0');
		FOR i IN AWIDTH_RD - 1 DOWNTO AWIDTH_RD - AWIDTH_RAM LOOP
			raddr(i) := fifo_addr_rd(i);
		END LOOP;
		ram_raddr <= raddr;

		-- calculate read subword
		saddr := fifo_addr_rd;
		FOR i IN AWIDTH_RD DOWNTO AWIDTH_RD - AWIDTH_RAM LOOP
			-- clear read address bits in subword address
			saddr(i) := '0';
		END LOOP;
		subword      := to_integer(unsigned(saddr));
		subword      := conditional(BIG_ENDIAN = 0, subword, DWIDTH_RAM / DWIDTH_RD - 1 - subword);
		ram_rsubword <= subword;
	END PROCESS;

	PROCESS(ram, ram_raddr, ram_rsubword)
		VARIABLE oram  : std_ulogic_vector(DWIDTH_RAM - 1 downto 0);
		VARIABLE oword : std_ulogic_vector(DWIDTH_RD - 1 downto 0);
	BEGIN
		oram       := ram(to_integer(ram_raddr));
		oword      := oram((ram_rsubword + 1) * DWIDTH_RD - 1 DOWNTO ram_rsubword * DWIDTH_RD);
		fifo_rdata <= oword;
	END PROCESS;

	--PROCESS (ram_rdata, ram_rsubword)
	--BEGIN
	--  fifo_rdata <= (OTHERS => '-');
	--  FOR i IN 0 TO DWIDTH_RAM/DWIDTH_RD-1 LOOP
	--    IF i = ram_rsubword THEN
	--      fifo_rdata <= ram_rdata((i+1)*DWIDTH_RD-1 DOWNTO i*DWIDTH_RD);
	--    END IF;
	--  END LOOP;
	--END PROCESS;

	PROCESS(clk_rd)
	BEGIN
		IF clk_rd'event AND clk_rd = '1' THEN
			IF clken_rd = '1' AND (fifo_empty OR rd_en = '1') THEN
				--        fifo_rdata_ff <= fifo_rdata;
				fifo_rdata_ff <= ram(to_integer(ram_raddr))((ram_rsubword + 1) * DWIDTH_RD - 1 DOWNTO ram_rsubword * DWIDTH_RD);
			END IF;
		END IF;
	END PROCESS;

	rdata <= fifo_rdata WHEN ASYNC = 0 AND SYNC_OUTREG = 0 ELSE fifo_rdata_ff;

END behavioral;
