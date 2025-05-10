QT_ROOT_DIR ?= $(QT_ROOT_DIR)
VERSION_TAG ?= "0.0.0"
BUILD_DIR ?= build
INSTALL_DIR ?= install
ABS_INSTALL_DIR := $(abspath $(INSTALL_DIR))

desktop:
	cmake -S . -B $(BUILD_DIR) -DVERSION_TAG=$(VERSION_TAG) -DCMAKE_BUILD_TYPE=Release -DQT_ROOT_DIR=$(QT_ROOT_DIR)
	cmake --build $(BUILD_DIR)
	cmake --install $(BUILD_DIR) --prefix $(ABS_INSTALL_DIR)

clean:
	rm -rI $(BUILD_DIR) $(ABS_INSTALL_DIR)

wipe:
	rm -rf $(BUILD_DIR) $(ABS_INSTALL_DIR)

.PHONY: desktop clean wipe
