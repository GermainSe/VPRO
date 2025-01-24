//
// Created by renke on 08.05.20.
//

#ifndef UNIT_TEST_PROJECT_CHAINING_TESTER_H
#define UNIT_TEST_PROJECT_CHAINING_TESTER_H


class chaining_tester {
public:
    static bool perform_tests();

    static bool SKIP_DATA;
    static int TEST_VECTOR_LENGTH;

private:
    static void init_RF_for_chaining(int length);
	static void init_RF_for_chaining_incr(int length);
};


#endif //UNIT_TEST_PROJECT_CHAINING_TESTER_H
