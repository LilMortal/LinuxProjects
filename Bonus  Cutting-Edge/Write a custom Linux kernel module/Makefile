# Makefile for SimpleChar kernel module
#
# This Makefile builds the SimpleChar kernel module for the current running kernel.
# It supports both in-tree and out-of-tree builds.

# Module name
MODULE_NAME := simplechar

# Source files
obj-m += $(MODULE_NAME).o

# Kernel build directory
KERNEL_DIR := /lib/modules/$(shell uname -r)/build

# Current directory
PWD := $(shell pwd)

# Compiler flags for debugging
ccflags-y := -DDEBUG

# Default target
all: modules

# Build the module
modules:
	@echo "Building $(MODULE_NAME) kernel module..."
	$(MAKE) -C $(KERNEL_DIR) M=$(PWD) modules
	@echo "Build complete. Module: $(MODULE_NAME).ko"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	$(MAKE) -C $(KERNEL_DIR) M=$(PWD) clean
	rm -f *.symvers *.order *.mod.c
	@echo "Clean complete."

# Install the module (optional)
install: modules
	@echo "Installing $(MODULE_NAME) module..."
	sudo cp $(MODULE_NAME).ko /lib/modules/$(shell uname -r)/extra/
	sudo depmod -a
	@echo "Module installed to /lib/modules/$(shell uname -r)/extra/"

# Uninstall the module
uninstall:
	@echo "Uninstalling $(MODULE_NAME) module..."
	sudo rm -f /lib/modules/$(shell uname -r)/extra/$(MODULE_NAME).ko
	sudo depmod -a
	@echo "Module uninstalled."

# Load the module
load: modules
	@echo "Loading $(MODULE_NAME) module..."
	sudo insmod $(MODULE_NAME).ko || true
	@echo "Module loaded. Check 'lsmod | grep $(MODULE_NAME)'"

# Unload the module
unload:
	@echo "Unloading $(MODULE_NAME) module..."
	sudo rmmod $(MODULE_NAME) || true
	@echo "Module unloaded."

# Reload the module (unload + load)
reload: unload load

# Show module information
info:
	@echo "Module Information:"
	@echo "  Name: $(MODULE_NAME)"
	@echo "  Kernel: $(shell uname -r)"
	@echo "  Architecture: $(shell uname -m)"
	@if [ -f $(MODULE_NAME).ko ]; then \
		echo "  Module file: $(MODULE_NAME).ko (exists)"; \
		echo "  File size: $$(stat -c%s $(MODULE_NAME).ko) bytes"; \
		modinfo $(MODULE_NAME).ko 2>/dev/null | head -10; \
	else \
		echo "  Module file: $(MODULE_NAME).ko (not built)"; \
	fi

# Check if module is loaded
status:
	@echo "Module Status:"
	@if lsmod | grep -q $(MODULE_NAME); then \
		echo "  Status: Loaded"; \
		lsmod | grep $(MODULE_NAME); \
	else \
		echo "  Status: Not loaded"; \
	fi
	@if [ -c /dev/$(MODULE_NAME) ]; then \
		echo "  Device: /dev/$(MODULE_NAME) (exists)"; \
		ls -l /dev/$(MODULE_NAME); \
	else \
		echo "  Device: /dev/$(MODULE_NAME) (not found)"; \
	fi

# Show kernel messages related to the module
dmesg:
	@echo "Recent kernel messages for $(MODULE_NAME):"
	@dmesg | grep $(MODULE_NAME) | tail -20 || echo "No messages found"

# Test the module (basic functionality)
test: load
	@echo "Testing $(MODULE_NAME) module..."
	@if [ -c /dev/$(MODULE_NAME) ]; then \
		echo "Writing test data..."; \
		echo "Hello from $(MODULE_NAME)!" | sudo tee /dev/$(MODULE_NAME) > /dev/null; \
		echo "Reading test data:"; \
		sudo cat /dev/$(MODULE_NAME); \
		echo "Test completed successfully."; \
	else \
		echo "Error: Device file /dev/$(MODULE_NAME) not found"; \
		exit 1; \
	fi

# Help target
help:
	@echo "Available targets:"
	@echo "  all       - Build the kernel module (default)"
	@echo "  modules   - Build the kernel module"
	@echo "  clean     - Clean build artifacts"
	@echo "  install   - Install module to system"
	@echo "  uninstall - Remove module from system"
	@echo "  load      - Load the module into kernel"
	@echo "  unload    - Unload the module from kernel"
	@echo "  reload    - Unload and reload the module"
	@echo "  info      - Show module information"
	@echo "  status    - Check if module is loaded"
	@echo "  dmesg     - Show kernel messages for module"
	@echo "  test      - Basic functionality test"
	@echo "  help      - Show this help message"

# Declare phony targets
.PHONY: all modules clean install uninstall load unload reload info status dmesg test help