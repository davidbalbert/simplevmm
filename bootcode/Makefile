OBJCOPY := /opt/homebrew/opt/binutils/bin/objcopy

bootcode: bootcode.o
	$(OBJCOPY) --output-target binary bootcode.o bootcode

.PHONY: clean
clean:
	rm -f bootcode.o bootcode
