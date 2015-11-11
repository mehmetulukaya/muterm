PP=fpc
RM=rm -f
PATHS=-Fu../../lib -Fi../../lib/sys
ARGS=$(PATHS) -O2 -XX -Xs
SRC=httptest.lpr

all:
	$(PP) $(ARGS) $(SRC)

clean:
	$(MAKE) clean -C ../..
	$(RM) *~ *.o *.ppu