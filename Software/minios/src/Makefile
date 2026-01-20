LDCFG = jj65c02.cfg
SIMCFG=jj65c02-sim.cfg
LDMAP = minios.map
SIMMAP=sim-minios.map
LBL = minios.lbl
SIMLBL=sim-minios.lbl
TARGET = minios

SRCS =  minios.s \
	sysram.s \
	via.s \
	lib.s \
	acia.s \
	tty.s \
	console.s \
	xmodem.s \
	ehbasic.s \
	wozmon.s

OBJS=$(SRCS:%.s=objs/%.o)
SOBJS=$(SRCS:%.s=sobjs/%.o)
all: $(TARGET)

$(OBJS): $(SRCS)
	ca65 -t none --cpu 65c02 -U -I ./include -o $@ $(@:objs/%.o=%.s)

$(SOBJS): $(SRCS)
	ca65 -t none -D SIM=1 --cpu 65c02 -U -I ./include -o $@ $(@:sobjs/%.o=%.s)

$(TARGET): $(OBJS)
	ld65 -C ../$(LDCFG) -v -Ln $(LBL) -vm -m $(LDMAP) -o $(TARGET) $(OBJS)
	#rm -f $(TARGET).bin

sim: $(SOBJS)
	ld65 -C ../$(SIMCFG) -v -Ln $(SIMLBL) -vm -m $(SIMMAP) -o sim $(SOBJS)
	#rm -f sim.bin

.PHONY: clean
clean:
	rm -f $(TARGET) $(LDMAP) $(OBJS)  $(SOBJS) $(TARGET).rom
