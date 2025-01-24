#ifndef TEST_GUARD
#define TEST_GUARD

#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <algorithm>


class Test{
	bool fail;
	std::string _class;
	std::string name;
	std::string msg;
public:
	Test(std::string category, std::string testname) :
	fail(false), _class(category), name(testname), msg(""){}

	Test(std::string category, std::string testname, std::string errormsg) :
	fail(true), _class(category), name(testname), msg(errormsg){}

	std::string write() const{
		std::string val = "";
		if(fail){
			val = "<testcase classname=\""+ _class +"\" name=\""+name+"\"><failure>"+msg+"</failure></testcase>";
		}else{
			val = "<testcase classname=\""+ _class +"\" name=\""+name+"\" />";
		}
		return val;
		
	}
};

class TestManager{
	std::vector<Test> tests;
public:
	void addTest(Test t){
		tests.push_back(t);
	}

	void save(){
		/*if(tests.size() == 0){
			return;
		}*/
		std::string val = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>";
		val += "<testsuites name=\"Tests\"><testsuite name=\"CNN Suite\">";
		std::for_each(std::begin(tests), std::end(tests), [&](const Test& t){
			val += t.write();
		});
		val += "</testsuite></testsuites>";
		std::cout << "Writing report ..." << std::endl;
		std::ofstream f;
		f.open ("report.xml" );		
		f << val << std::endl;		
		f.close();

	}
};

#endif