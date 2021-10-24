LDCFG = jj65c02.cfg
LDMAP = minios.map
LBL = minios.lbl
TARGET = minios

SRCS =  minios.s \
	sysram.s \
	via.s \
	lcd.s \
	lib.s \
	acia.s \
	tty.s \
	ymodem.s

OBJS=$(SRCS:%.s=objs/%.o)
all: $(TARGET)

$(OBJS): $(SRCS)
	ca65 -t none --cpu 65c02 -U -I ./include -o $@ $(@:objs/%.o=%.s)

$(TARGET): $(OBJS)
	ld65 -C ../$(LDCFG) -v -Ln $(LBL) -vm -m $(LDMAP) -o $(TARGET) $(OBJS)
	rm -f $(TARGET).bin

.PHONY: clean
clean:
	rm -f $(TARGET) $(LDMAP) $(OBJS) $(TARGET).rom
