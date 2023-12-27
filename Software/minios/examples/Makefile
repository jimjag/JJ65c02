LDCFG = jj65c02.cfg
LDMAP = hello_world_scroll.map
LBL = hello_world_scroll.lbl
TARGET = hello_world_scroll

# Point to location of where the ROM object files are
ROMOBJs = ../src/objs
# These must be included in this order
ROM =  $(ROMOBJs)/minios.o \
	$(ROMOBJs)/sysram.o \
	$(ROMOBJs)/via.o \
	$(ROMOBJs)/lib.o \
	$(ROMOBJs)/acia.o \
	$(ROMOBJs)/tty.o \
	$(ROMOBJs)/console.o \
	$(ROMOBJs)/xmodem.o \
	$(ROMOBJs)/ehbasic.o

SRCS =  hello_world_scroll.s
OBJS=$(SRCS:%.s=%.o)

all: $(TARGET)

$(OBJS): $(SRCS)
	ca65 -U -t none --cpu 65c02 -U -I ../src/include -o $@ $(@:.o=.s)

$(TARGET): $(OBJS)
	ld65 -C ../$(LDCFG) -v -Ln $(LBL) -vm -m $(LDMAP) -o $(TARGET) $(ROM) $(OBJS)
	rm -f $(TARGET).rom

.PHONY: clean
clean:
	rm -f $(TARGET) $(LDMAP) $(OBJS) $(TARGET).bin
