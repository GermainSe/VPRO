//
// Created by renke on 08.05.20.
//

#ifndef UNIT_TEST_PROJECT_chaining_ls_tester_H
#define UNIT_TEST_PROJECT_chaining_ls_tester_H


class chaining_ls_tester {
public:
    static bool SKIP_DATA;
    static int TEST_VECTOR_LENGTH;

    static bool perform_tests();

private:
    static void init_RF_for_chaining(int length);

    static void test_U0LS_to_U1LS_to_U1L0();

    static void test_U0L1_to_U0L0_to_U0LS_to_U1LS_to_U1L0_and_U1L1();

    static void test_U0LS_to_U1LS_to_U1L0_and_U1L1();
};


#endif //UNIT_TEST_PROJECT_chaining_ls_tester_H
