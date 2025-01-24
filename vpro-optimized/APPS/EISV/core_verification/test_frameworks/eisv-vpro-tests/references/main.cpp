// ########################################################
// # VPRO instruction/operation verification              #
// # Verifies the broadcasted core operations of several  #
// # vector units/lanes!                                  #
// #                                                      #
// # Stephan Nolting, IMS, Uni Hannover, 2017 - 2018      #
// ########################################################

#include "test_framework.h"
#include <QFile>
#include <QDataStream>
#include <QTextStream>
#include <fstream>

// copy in binary mode
bool copyFile(const char *SRC, const char* DEST)
{
    std::ifstream src(SRC, std::ios::binary);
    std::ofstream dest(DEST, std::ios::binary);
    dest << src.rdbuf();
    return src && dest;
}

/**
 * Test Data Variables
 */
constexpr int NUM_TEST_ENTRIES = 64;
int16_t test_array_1[1024];
int16_t test_array_2[1024];

int main(int argc, char *argv[]) {

    setbuf(stdout, 0);
    for (int i = 0; i < static_cast<int>(TESTS::TEST_END); ++i) {
        TESTS t = static_cast<TESTS>(i);
        std::string name = testName(t);
        int test_size = NUM_TEST_ENTRIES;

        printf("Creating Reference Data for: %s ", name.c_str());
        printf("...");

        // input data generation
        int count = 0;
        for (volatile int16_t &i : test_array_1){
            i = count;
            count = -(abs(count)+1);
        }
        count = test_size - 1;
        for (volatile int16_t &i : test_array_2){
            i = count;
            count--;
        }
        
		if (t == TESTS::INDIRECT_LOAD){
			test_size = 8;
		}
		if (t == TESTS::DMA_FIFO || t == TESTS::DMA_FIFO2){
			test_size = 1024;
			for (int i = 0; i < test_size; ++i){
				test_array_1[i] = i;
				test_array_2[i] = i;
		    }
		}

        printf("...");
        int32_t * result = execute(t, (uint16_t *)test_array_1, (uint16_t *)test_array_2, test_size);

        printf("...");

        QFile file(QString(name.c_str())+QString(".reference_output"));
        file.open(QIODevice::WriteOnly);
//        QDataStream out(&file);   // would be binary output file
        QTextStream out(&file);
        for (unsigned long int x = 0; x < test_size; x++) {
            auto yourNumber = int32_t(int16_t(result[x]));
            auto str = QStringLiteral("%1").arg(yourNumber, 8, 16, QLatin1Char('0'));
            if (str.length() > 8)
                str = str.mid(8);
            str = str.toUpper();
            out << str;
            out << "\n";
        }
        file.close();

        printf("... [done] \n");
    }

    { // add DMA_OVERLOAD
        std::string name = "DMA_OVERLOAD";
        printf("Creating Reference Data for: %s ", name.c_str());
        printf("...");
        printf("...");
        QFile file(QString(name.c_str()) + QString(".reference_output"));
        file.open(QIODevice::WriteOnly);
//        QDataStream out(&file);   // would be binary output file
        QTextStream out(&file);
        for (int i = 0; i < 4*8*2; ++i) { // loop all cluster/units/lanes
            for (unsigned long int x = 0; x < 144; x++) {
                auto str = QStringLiteral("%1").arg(x, 8, 16, QLatin1Char('0'));
                if (str.length() > 8)
                    str = str.mid(8);
                str = str.toUpper();
                out << str;
                out << "\n";
            }
        }
        file.close();
        printf("... [done] \n");
    }
    
    
    if (! copyFile("../FFT.reference_output", "./FFT.reference_output")){
    	printf("\e[1;31m[FAIL] Copy of FFT reference_output failed!\e[0m\n");
    }
    if (! copyFile("../SIGMOID.reference_output", "./SIGMOID.reference_output")){
    	printf("\e[1;31m[FAIL] Copy of SIGMOID reference_output failed!\e[0m\n");
    }
    
    
}

