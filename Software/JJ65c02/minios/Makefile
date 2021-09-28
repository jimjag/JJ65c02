CL = cl65
LDCFG = jj65c02.cfg
LDMAP = minios.map
TARGET = minios

SRCS =  minios.s \
	sysram.s \
	via.s \
	lcd.s \
	lib.s \
	acia.s

all: $(TARGET)

$(TARGET): $(SRCS)
	$(CL) -t none --cpu 65c02 -C ../$(LDCFG) -v -vm -m $(LDMAP) -o $(TARGET) $(SRCS)

.PHONY: clean
clean:
	rm -f $(TARGET) $(LDMAP)
