LDCFG = jj65c02.cfg
LDMAP = minios.map
TARGET = minios

SRCS =  minios.s \
	sysram.s \
	via.s \
	lcd.s \
	lib.s \
	acia.s \
	tty.s \
	xmodem.s

OBJS=$(SRCS:%.s=%.o)
all: $(TARGET)

$(OBJS): $(SRCS)
	ca65 -t none --cpu 65c02 -U -I ./include -o $@ $(@:.o=.s)

$(TARGET): $(OBJS)
	ld65 -C ../$(LDCFG) -v -Ln $(LDMAP) -o $(TARGET) $(OBJS)
	rm -f $(TARGET).bin $(TARGET)

.PHONY: clean
clean:
	rm -f $(TARGET) $(LDMAP) $(OBJS)
