HEADERS = $(shell find . -name '*.h')

fpga: controller.cpp $(HEADERS)
	g++ -std=c++17 -o fpga controller.cpp -lserial
