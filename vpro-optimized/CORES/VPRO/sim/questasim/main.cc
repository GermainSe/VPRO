
#define SC_INCLUDE_DYNAMIC_PROCESSES //for sc_spawn
#include <systemc.h>
#include <fstream>
#include <iomanip> // Required for std::setw and std::setfill

//QuestaSim compile active, create module "main"
//#include "uart_interface.hh"
//#include "spi_interface.hh"
#include "sim_wrapper.hh" // Interface to verilog wrapper

#define IMEM_SIZE_C 8192
#define DMEM_SIZE_C 32768

#define IMEM_ADDR_W_C 13
#define IMEM_DATA_W_C 64
#define DMEM_ADDR_W_C 15
#define DMEM_DATA_W_C 64

SC_MODULE(main)
{
    sim_wrapper dut;
    sc_clock clk;

    //interface signals to verilog wrapper
    sc_signal<bool> rst_n;
    sc_signal<bool> core_en;
    sc_signal<bool> i2c_i2s_flag;

    // Memory Interface Ports
    sc_signal<sc_bv<IMEM_DATA_W_C> > imem_rd_data;
    sc_signal<sc_bv<IMEM_ADDR_W_C> > imem_rd_addr;

    sc_signal<sc_bv<DMEM_ADDR_W_C> > ex_bus_rd_0_addr;
    sc_signal<bool> ex_bus_rd_0_en;
    sc_signal<bool> ex_bus_rd_0_x2_en;
    sc_signal<sc_bv<DMEM_ADDR_W_C> > ex_bus_rd_1_addr;
    sc_signal<bool> ex_bus_rd_1_en;
    sc_signal<bool> ex_bus_rd_1_x2_en;
    sc_signal<sc_bv<DMEM_ADDR_W_C> > ex_bus_wr_0_addr;
    sc_signal<bool> ex_bus_wr_0_en;
    sc_signal<bool> ex_bus_wr_0_x2_en;
    sc_signal<sc_bv<DMEM_ADDR_W_C> > ex_bus_wr_1_addr;
    sc_signal<bool> ex_bus_wr_1_en;
    sc_signal<bool> ex_bus_wr_1_x2_en;
    sc_signal<sc_bv<DMEM_DATA_W_C> > ex_bus_rd_0_data;
    sc_signal<sc_bv<DMEM_DATA_W_C> > ex_bus_rd_0_data_x2;
    sc_signal<sc_bv<DMEM_DATA_W_C> > ex_bus_rd_1_data;
    sc_signal<sc_bv<DMEM_DATA_W_C> > ex_bus_rd_1_data_x2;
    sc_signal<sc_bv<DMEM_DATA_W_C> > ex_bus_wr_0_data;
    sc_signal<sc_bv<DMEM_DATA_W_C> > ex_bus_wr_0_data_x2;
    sc_signal<sc_bv<DMEM_DATA_W_C> > ex_bus_wr_1_data;
    sc_signal<sc_bv<DMEM_DATA_W_C> > ex_bus_wr_1_data_x2;

    //internal signals
    sc_signal<sc_bv<IMEM_DATA_W_C> > IMEM[IMEM_SIZE_C];  // Instruction Memory
    sc_signal<sc_bv<DMEM_DATA_W_C> > DMEM[DMEM_SIZE_C];  // Data Memory

    sc_bv<IMEM_DATA_W_C> imem_data_little_endian;
    sc_bv<IMEM_DATA_W_C> imem_data_big_endian;
    
    sc_bv<IMEM_ADDR_W_C> imem_addr_bv;
    uint imem_addr_int;

    sc_bv<DMEM_ADDR_W_C> dmem_addr_bv;
    uint dmem_addr_int;

    uint stop_criterium;
    
    SC_CTOR(main) :

    dut("dut", "sim_wrapper"),
    clk("clk", 10, SC_NS)
    {
        //connect to verilog wrapper
        dut.i_clk(clk);
        dut.i_rst_n(rst_n);
        dut.i_core_en(core_en);
        dut.i_i2c_i2s_flag(i2c_i2s_flag);

        // Memory Interface Ports
        dut.i_imem_rd_data(imem_rd_data);
        dut.o_imem_rd_addr(imem_rd_addr);

        dut.o_ex_bus_rd_0_addr(ex_bus_rd_0_addr);
        dut.o_ex_bus_rd_0_en(ex_bus_rd_0_en);
        dut.o_ex_bus_rd_0_x2_en(ex_bus_rd_0_x2_en);
        dut.o_ex_bus_rd_1_addr(ex_bus_rd_1_addr);
        dut.o_ex_bus_rd_1_en(ex_bus_rd_1_en);
        dut.o_ex_bus_rd_1_x2_en(ex_bus_rd_1_x2_en);
        dut.o_ex_bus_wr_0_addr(ex_bus_wr_0_addr);
        dut.o_ex_bus_wr_0_en(ex_bus_wr_0_en);
        dut.o_ex_bus_wr_0_x2_en(ex_bus_wr_0_x2_en);
        dut.o_ex_bus_wr_1_addr(ex_bus_wr_1_addr);
        dut.o_ex_bus_wr_1_en(ex_bus_wr_1_en);
        dut.o_ex_bus_wr_1_x2_en(ex_bus_wr_1_x2_en);
        dut.i_ex_bus_rd_0_data(ex_bus_rd_0_data);
        dut.i_ex_bus_rd_0_data_x2(ex_bus_rd_0_data_x2);
        dut.i_ex_bus_rd_1_data(ex_bus_rd_1_data);
        dut.i_ex_bus_rd_1_data_x2(ex_bus_rd_1_data_x2);
        dut.o_ex_bus_wr_0_data(ex_bus_wr_0_data);
        dut.o_ex_bus_wr_0_data_x2(ex_bus_wr_0_data_x2);
        dut.o_ex_bus_wr_1_data(ex_bus_wr_1_data);
        dut.o_ex_bus_wr_1_data_x2(ex_bus_wr_1_data_x2);

	// ---------------------
	// Start testbench (TB)
	// ---------------------
	
	// Memory Initialization (IMEM)
	std::ifstream ifile("app/imem.bin", std::ios::binary);
	if (ifile.is_open()) {
	  cout << "[TB] Initializing IMEM with 'app/imem.bin' file" << endl;
	  imem_addr_int = 0;
	  while (!ifile.eof() && imem_addr_int < IMEM_SIZE_C) {
	    uint64_t value;
	    ifile.read(reinterpret_cast<char*>(&value), sizeof(value));
	    imem_data_little_endian = value;
	    // Transform imem_data_little_endian to big-endian
	    for (int i = 0; i < IMEM_DATA_W_C / 8; ++i) {
	      for (int j = 0; j < 8; ++j) {
		imem_data_big_endian[i * 8 + j] = imem_data_little_endian[(IMEM_DATA_W_C - 8 - i * 8) + j];
	      }
	    }
	    IMEM[imem_addr_int++] = imem_data_big_endian;
	  }
	  ifile.close();
	} else {
	  cout << "[TB] Initializing IMEM with ZEROS" << endl;
        }

	std::ifstream dfile("app/dmem.bin", std::ios::binary);
	if (dfile.is_open()) {
	  cout << "[TB] Initializing DMEM with 'app/dmem.bin' file" << endl;
	  dmem_addr_int = 0;
	  while (!dfile.eof() && dmem_addr_int < DMEM_SIZE_C) {
	    uint64_t value;
	    dfile.read(reinterpret_cast<char*>(&value), sizeof(value));
	    DMEM[dmem_addr_int++] = value;
	  }
	  dfile.close();
	} else {
	  cout << "[TB] Initializing IMEM with ZEROS" << endl;
        }

        // Default signals
        core_en.write(true);
        i2c_i2s_flag.write(false);

	    // Reset on
        rst_n.write(false); //held in reset
	cout << "[TB] Reset on" << endl;

	    // Reset off
        sc_spawn([&]{ //spwan process to disable reset after 20ns
	  wait(20, SC_NS);
	  rst_n.write(true); //disable reset
        });
	cout << "[TB] Reset off" << endl;
        
	// Spawn process to periodically read/write in memory
	sc_spawn([&]{ 
	  wait(20, SC_NS); // wait until reset is off
	  stop_criterium = 0;
	  while(stop_criterium == 0) {
	    // Reading IMEM
	    imem_addr_bv = imem_rd_addr.read();
	    imem_addr_int = imem_addr_bv.to_uint();
	    imem_rd_data.write(IMEM[imem_addr_int]);
	    cout << "[TB] Reading IMEM[" << std::setw(4) << std::setfill('0') << imem_addr_int*4 << "] => " << std::hex << IMEM[imem_addr_int] << endl;  
	    
	    // Port 0: Reading DMEM
	    if (ex_bus_rd_0_en.read() == true) {
	      dmem_addr_bv = ex_bus_rd_0_addr.read();
	      dmem_addr_int = dmem_addr_bv.to_uint();
	      ex_bus_rd_0_data.write(DMEM[dmem_addr_int]);
	      cout << "[TB] Port 0: Reading DMEM[" << std::setw(4) << std::setfill('0') << dmem_addr_int << "] => " << std::setw(16) << DMEM[dmem_addr_int] << endl;
	      if (ex_bus_rd_0_x2_en.read() == true) {
		dmem_addr_bv = ex_bus_rd_0_addr.read();
		dmem_addr_int = dmem_addr_bv.to_uint()+1;
		ex_bus_rd_0_data_x2.write(DMEM[dmem_addr_int]);
		cout << "[TB] Port 0: Reading DMEM_X2[" << std::setw(4) << std::setfill('0') << dmem_addr_int << "] => " << std::setw(16) << DMEM[dmem_addr_int] << endl;
	      }
	    }
	    
	    // Port 1: Reading DMEM
	    if (ex_bus_rd_1_en.read() == true) {
	      dmem_addr_bv = ex_bus_rd_1_addr.read();
	      dmem_addr_int = dmem_addr_bv.to_uint();
	      ex_bus_rd_1_data.write(DMEM[dmem_addr_int]);
	      cout << "[TB] Port 1: Reading DMEM[" << std::setw(4) << std::setfill('0') << dmem_addr_int << "] => " << std::setw(16) << DMEM[dmem_addr_int] << endl;  
	      if (ex_bus_rd_1_x2_en.read() == true) {
		dmem_addr_bv = ex_bus_rd_1_addr.read();
		dmem_addr_int = dmem_addr_bv.to_uint()+1;
		ex_bus_rd_1_data_x2.write(DMEM[dmem_addr_int]);
		cout << "[TB] Port 1: Reading DMEM_X2[" << std::setw(4) << std::setfill('0') << dmem_addr_int << "] => " << std::setw(16) << DMEM[dmem_addr_int] << endl;
	      }
	    }
	    
	    // Port 0: Writting DMEM
	    if (ex_bus_wr_0_en.read() == true) {
	      dmem_addr_bv = ex_bus_wr_0_addr.read();
	      dmem_addr_int = dmem_addr_bv.to_uint();
	      DMEM[dmem_addr_int] = ex_bus_wr_0_data.read();
	      cout << "[TB] Port 0: Writing DMEM[" << std::setw(4) << std::setfill('0') << dmem_addr_int << "] <= " << std::setw(16) << std::setfill('0') << ex_bus_wr_0_data.read() << endl;
	      if (ex_bus_wr_0_x2_en.read() == true) {
		dmem_addr_bv = ex_bus_wr_0_addr.read();
		dmem_addr_int = dmem_addr_bv.to_uint()+1;
		DMEM[dmem_addr_int] = ex_bus_wr_0_data_x2.read();
		cout << "[TB] Port 0: Writing DMEM_X2[" << std::setw(4) << std::setfill('0') << dmem_addr_int << "] <= " << std::setw(16) << std::setfill('0') << ex_bus_wr_0_data_x2.read() << endl;
	      }
	      if (dmem_addr_bv == 0x7fff) {
		cout << "[TB] Program finished" << endl;
		stop_criterium = 1;
	      }
	    }
	    
	    // Port 1: Writting DMEM
	    if (ex_bus_wr_1_en.read() == true) {
	      dmem_addr_bv = ex_bus_wr_1_addr.read();
	      dmem_addr_int = dmem_addr_bv.to_uint();
	      DMEM[dmem_addr_int] = ex_bus_wr_1_data.read();
	      cout << "[TB] Port 1: Writing DMEM[" << std::setw(4) << std::setfill('0') << dmem_addr_int << "] <= " << std::setw(16) << std::setfill('0') << ex_bus_wr_1_data.read() << endl;  
	      if (ex_bus_wr_1_x2_en.read() == true) {
		dmem_addr_bv = ex_bus_wr_1_addr.read();
		dmem_addr_int = dmem_addr_bv.to_uint()+1;
		DMEM[dmem_addr_int] = ex_bus_wr_1_data_x2.read();
		cout << "[TB] Port 1: Writing DMEM_X2[" << std::setw(4) << std::setfill('0') << dmem_addr_int << "] <= " << std::setw(16) << std::setfill('0') << ex_bus_wr_1_data_x2.read() << endl;
	      }
	      if (dmem_addr_bv == 0x7fff) {
		cout << "[TB] Program finished" << endl;
		stop_criterium = 1;
	      }
	    }    
	    wait(10, SC_NS); // Wait till end of period
	  }

	  // +++++++++++++++++++++++++++++++++++++++++++++++++++++++
	  // Dump results V0RX 
	  // +++++++++++++++++++++++++++++++++++++++++++++++++++++++
	  std::ofstream outFile_v0rx("app/dump_v0rx.log");
	  if (!outFile_v0rx.is_open()) {
            std::cerr << "Error: Unable to open file dump_v0rx.log for writing." << std::endl;
            return;
	  }
	  // Set output stream formatting for hexadecimal address
	  outFile_v0rx << std::hex << std::setfill('0');
	  // Iterate over each memory element and write its content to the file
	  for (int i = 0; i < 32; ++i) {
	    // Read memory element
	    sc_bv<DMEM_DATA_W_C> data = DMEM[i];
	    
	    // Split data into upper and lower 32-bit parts
	    sc_bv<32> upper = data.range(63, 32);
	    sc_bv<32> lower = data.range(31, 0);

	    // Convert upper and lower parts to formatted hexadecimal strings
	    std::stringstream upperStream, lowerStream;
	    upperStream << std::hex << std::setfill('0') << std::setw(8) << upper.to_uint();
	    lowerStream << std::hex << std::setfill('0') << std::setw(8) << lower.to_uint();

	    // Output formatting to ensure exactly 16 characters for data
	    outFile_v0rx << "(0x" << std::setw(4) << std::setfill('0') << std::hex << i << ")\t";
	    outFile_v0rx << "0x" << upperStream.str() << lowerStream.str() << std::endl;
	  }
	  // Close the file
	  outFile_v0rx.close();


	  // +++++++++++++++++++++++++++++++++++++++++++++++++++++++
	  // Dump results V1RX 
	  // +++++++++++++++++++++++++++++++++++++++++++++++++++++++
	  std::ofstream outFile_v1rx("app/dump_v1rx.log");
	  if (!outFile_v1rx.is_open()) {
            std::cerr << "Error: Unable to open file dump_v1rx.log for writing." << std::endl;
            return;
	  }
	  // Set output stream formatting for hexadecimal address
	  outFile_v1rx << std::hex << std::setfill('0');
	  // Iterate over each memory element and write its content to the file
	  for (int i = 32; i < 64; ++i) {
	    // Read memory element
	    sc_bv<DMEM_DATA_W_C> data = DMEM[i];
	    
	    // Split data into upper and lower 32-bit parts
	    sc_bv<32> upper = data.range(63, 32);
	    sc_bv<32> lower = data.range(31, 0); 

	    // Convert upper and lower parts to formatted hexadecimal strings
	    std::stringstream upperStream, lowerStream;
	    upperStream << std::hex << std::setfill('0') << std::setw(8) << upper.to_uint();
	    lowerStream << std::hex << std::setfill('0') << std::setw(8) << lower.to_uint();

	    // Output formatting to ensure exactly 16 characters for data
	    outFile_v1rx << "(0x" << std::setw(4) << std::setfill('0') << std::hex << i-32 << ")\t";
	    outFile_v1rx << "0x" << upperStream.str() << lowerStream.str() << std::endl;
	  }
	  // Close the file
	  outFile_v1rx.close();


	  // +++++++++++++++++++++++++++++++++++++++++++++++++++++++
	  // Interrupt simulaiton
	  // +++++++++++++++++++++++++++++++++++++++++++++++++++++++
	  sc_stop();
        }); 
    }
};

SC_MODULE_EXPORT(main)

