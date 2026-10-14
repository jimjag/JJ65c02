#include "acia.h"

#include <errno.h>
#include <poll.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <time.h>
#include <unistd.h>

#define ACIA_DATA    0xA010
#define ACIA_STATUS  0xA011
#define ACIA_COMMAND 0xA012

#define ST_IRQ         0x80
#define ST_TX_EMPTY    0x10
#define ST_RX_FULL     0x08
#define CMD_RX_IRQ_OFF 0x02

const char *acia_path = NULL;

static int  link_fd = -1;
static bool rx_full = false;
static bool irq_flag = false;
static uint8_t rx_byte = 0;

static void drop_link(cpu *m) {
    if (link_fd >= 0)
        close(link_fd);
    link_fd = -1;
    rx_full = false;
    irq_flag = false;
    if (m != NULL)
        m->mem[ACIA_STATUS] = ST_TX_EMPTY;
}

bool acia_init(const char *path) {
    if (path == NULL || path[0] == '\0')
        return false;

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof addr);
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, path, sizeof(addr.sun_path) - 1);

    // The harness listens; retry briefly so launch order is forgiving.
    for (int attempt = 0; attempt < 20; attempt++) {
        int fd = socket(AF_UNIX, SOCK_STREAM, 0);
        if (fd < 0)
            break;
        if (connect(fd, (struct sockaddr *)&addr, sizeof addr) == 0) {
#ifdef SO_NOSIGPIPE
            int on = 1;
            setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, sizeof on);
#endif
            link_fd = fd;
            return true;
        }
        close(fd);
        struct timespec ts = { 0, 100 * 1000000L };
        nanosleep(&ts, NULL);
    }
    return false;
}

bool acia_active(void) {
    return link_fd >= 0;
}

void acia_close(void) {
    drop_link(NULL);
}

void acia_note_read(uint16_t addr) {
    if (addr == ACIA_DATA) {
        rx_full = false;
        irq_flag = false;
    } else if (addr == ACIA_STATUS) {
        irq_flag = false;
    }
}

void acia_write(cpu *m, uint16_t addr) {
    if (link_fd < 0 || addr != ACIA_DATA)
        return;
    uint8_t byte = m->mem[addr];
#ifdef MSG_NOSIGNAL
    int flags = MSG_NOSIGNAL;
#else
    int flags = 0;
#endif
    for (;;) {
        ssize_t n = send(link_fd, &byte, 1, flags);
        if (n == 1)
            break;
        if (n < 0 && errno == EINTR)
            continue;
        drop_link(m);
        return;
    }
    if (rx_full)
        m->mem[ACIA_DATA] = rx_byte;
}

void acia_service(cpu *m) {
    if (link_fd < 0)
        return;

    if (!rx_full && !m->interrupt_waiting) {
        struct pollfd pfd = { .fd = link_fd, .events = POLLIN, .revents = 0 };
        if (poll(&pfd, 1, 0) > 0) {
            uint8_t byte;
            ssize_t n = (pfd.revents & POLLIN) ? read(link_fd, &byte, 1) : 0;
            if (n == 1) {
                rx_byte = byte;
                m->mem[ACIA_DATA] = byte;
                rx_full = true;
                if (!(m->mem[ACIA_COMMAND] & CMD_RX_IRQ_OFF)) {
                    irq_flag = true;
                    m->interrupt_waiting = 0x01;
                }
            } else if (!(n < 0 && (errno == EINTR || errno == EAGAIN))) {
                drop_link(m);
                return;
            }
        }
    }

    m->mem[ACIA_STATUS] = ST_TX_EMPTY | (rx_full ? ST_RX_FULL : 0) |
                          (irq_flag ? ST_IRQ : 0);
}
