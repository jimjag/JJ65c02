CL = cl65
LDCFG = jj65c02.cfg
LDMAP = minios.map
TARGET = minios

SRCS =  minios.s \
	via.s \
	lcd.s \
	lib.s

all: $(TARGET)

$(TARGET):
	$(CL) -t none --cpu 65c02 -C ../$(LDCFG) -v -vm -m $(LDMAP) -o $(TARGET) $(SRCS)

