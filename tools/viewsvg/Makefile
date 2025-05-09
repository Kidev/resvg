QT_ROOT ?= ""

all: clean
	cmake -S . -B build -DVERSION_TAG='0.79.3' -DCMAKE_BUILD_TYPE="Release" -DQT_ROOT_DIR="$(QT_ROOT)"
	cmake --build build

.PHONY: clean
clean:
	rm -rf build CMakeLists.txt.user bin 
