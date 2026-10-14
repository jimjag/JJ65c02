LDCFG   = jj6502.cfg
SIMCFG  = jj6502-sim.cfg
LDMAP   = minios.map
SIMMAP  = sim-minios.map
LBL     = minios.lbl
SIMLBL  = sim-minios.lbl
TARGET  = minios
TARGET2 = sim
TARGET3 = simacia

SRCS =  minios.s \
	sysram.s \
	via.s \
	lib.s \
	acia.s \
	tty.s \
	console.s \
	xmodem.s \
	ehbasic.s \
	wozmon.s \
	intel-hex.s \
	milliforth.s \
	supermon.s

OBJS=$(SRCS:%.s=objs/%.o)
SOBJS=$(SRCS:%.s=sobjs/%.o)
AOBJS=$(SRCS:%.s=aobjs/%.o)
all: $(TARGET)

$(OBJS): $(SRCS)
	ca65 -t none --cpu w65c02 -U -I ./include -o $@ $(@:objs/%.o=%.s)

$(SOBJS): $(SRCS)
	ca65 -t none -D SIM=1 --cpu w65c02 -U -I ./include -o $@ $(@:sobjs/%.o=%.s)

$(AOBJS): $(SRCS)
	@mkdir -p aobjs
	ca65 -t none -D SIM=1 -D SIM_ACIA=1 --cpu w65c02 -U -I ./include -o $@ $(@:aobjs/%.o=%.s)

$(TARGET): $(OBJS)
	ld65 -C ./$(LDCFG) -v -Ln $(LBL) -vm -m $(LDMAP) -o $(TARGET) $(OBJS)
	touch $(TARGET)
	ar65 r $(TARGET).lib $(OBJS)
	#rm -f $(TARGET).bin

$(TARGET2): $(SOBJS)
	ld65 -C ./$(SIMCFG) -v -Ln $(SIMLBL) -vm -m $(SIMMAP) -o $(TARGET2) $(SOBJS)
	#rm -f sim.bin

$(TARGET3): $(AOBJS)
	ld65 -C ./$(SIMCFG) -v -Ln simacia-minios.lbl -vm -m simacia-minios.map -o $(TARGET3) $(AOBJS)

.PHONY: clean
clean:
	rm -f $(TARGET) $(TARGET2) $(LDMAP) $(OBJS) $(SOBJS) $(TARGET).rom $(TARGET2).rom $(TARGET3) $(AOBJS) $(TARGET3)-minios.rom simacia-minios.lbl simacia-minios.map *.lbl *.map $(TARGET).lib
