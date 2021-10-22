LDCFG = jj65c02.cfg
LDMAP = hello_world_scroll.map
TARGET = hello_world_scroll

ROM =  ../minios/minios.o \
	../minios/sysram.o \
	../minios/via.o \
	../minios/lcd.o \
	../minios/lib.o \
	../minios/acia.o \
	../minios/tty.o \
	../minios/xmodem.o

SRCS =  hello_world_scroll.s
OBJS=$(SRCS:%.s=%.o)

all: $(TARGET)

$(OBJS): $(SRCS)
	ca65 -U -t none --cpu 65c02 -U -o $@ $(@:.o=.s)

$(TARGET): $(OBJS)
	ld65 -C ../$(LDCFG) -v -vm -m $(LDMAP) -o $(TARGET) $(OBJS) $(ROM)
	rm -f $(TARGET).rom

.PHONY: clean
clean:
	rm -f $(TARGET) $(LDMAP) $(OBJS)
