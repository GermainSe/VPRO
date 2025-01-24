//
// Created by AK on 2021/10/06, based on chaining tester
//

#ifndef UNIT_TEST_PROJECT_BLOCKING_TESTER_H
#define UNIT_TEST_PROJECT_BLOCKING_TESTER_H

namespace blockingTest{

    class tester {
    public:
        static bool perform_tests();
        static bool SKIP_DATA;
        static int TEST_VECTOR_LENGTH;

    private:
        static void init_RF(int length);
    };

}


#endif //UNIT_TEST_PROJECT_BLOCKING_TESTER_H
