SHELL=/bin/bash
.SUFFIXES: .oz .ozf
OZC=ozc

SRC= distBase.oz distExtra.oz # $(wildcard *.oz)
OBJ= $(SRC:.oz=.ozf)

all: $(OBJ)
	@echo -e "Compiled.\nTO RUN, run oz TESTFILE from the current directory."

#$(EXEC): $(OBJ)
#	@$(OZC) -x $@.oz  

%.ozf: %.oz
	@$(OZC) -o $@ -c $< $(CFLAGS)

# automatically rebuild dependances of .PHONY targets
.PHONY: clean all

clean:
	@rm -rf *.ozf $(EXEC)

