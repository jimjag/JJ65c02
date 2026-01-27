LDCFG = jj65c02.cfg
LDMAP = hello_world_scroll.map
LBL = hello_world_scroll.lbl
TARGET = hello_world_scroll

SRCS =  hello_world_scroll.s
OBJS=$(SRCS:%.s=%.o)

all: $(TARGET)

$(OBJS): $(SRCS)
	ca65 -U -t none --cpu w65c02 -U -I ../src/include -o $@ $(@:.o=.s)

$(TARGET): $(OBJS)
	ld65 -C ../$(LDCFG) -v -Ln $(LBL) -vm -m $(LDMAP) -o $(TARGET) $(OBJS) ../src/minios.lib
	rm -f $(TARGET).rom

.PHONY: clean
clean:
	rm -f $(TARGET) $(LDMAP) $(OBJS) $(TARGET).bin
