


CXX      := -c++

BITWIDTH_REDUCE_TO_16_BIT ?= 0
CXXFLAGS := -fPIC -DBITWIDTH_REDUCE_TO_16_BIT=${BITWIDTH_REDUCE_TO_16_BIT}
CXXFLAGS += -O2

LDFLAGS  := -L/usr/lib/x86_64-linux-gnu -lQt5Core

TARGET   := generator

INCLUDE  := 			\
	-I/usr/include/x86_64-linux-gnu/qt5 \
	-I/usr/include/x86_64-linux-gnu/qt5/QtWidgets \
	-I/usr/include/x86_64-linux-gnu/qt5/QtCore \
	-I/usr/include/x86_64-linux-gnu/qt5/QtGui \

SRC      :=                      \
	$(wildcard *.cpp)         \

OBJECTS  := $(SRC:%.cpp=%.o)

all: clean $(TARGET)
	./$(TARGET)
	rm -rf $(OBJECTS)

%.o: %.cpp
	@mkdir -p $(@D)
	$(CXX) $(CXXFLAGS) $(INCLUDE) -o $@ -c $<
	
$(TARGET): $(OBJECTS)
	@mkdir -p $(@D)
	$(CXX) $(CXXFLAGS) $(INCLUDE) $^ -o $@ $(LDFLAGS)
	
clean:
	rm -rf $(OBJECTS)
	rm -rf *.reference_output
