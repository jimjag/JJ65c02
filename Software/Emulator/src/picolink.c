#include "picolink.h"

#include <errno.h>
#include <poll.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <time.h>
#include <unistd.h>

// Unix-domain stream socket to the sim. Blocking for writes (the sim drains the
// display stream quickly); reads are gated by poll() so the single-threaded CPU
// loop never blocks waiting for a keypress.
static int  link_fd = -1;
static bool link_up = false;

static void nap_ms(long ms) {
    struct timespec ts = { ms / 1000, (ms % 1000) * 1000000L };
    nanosleep(&ts, NULL);
}

bool picolink_init(const char *path) {
    if (path == NULL || path[0] == '\0') {
        link_up = false;
        return false;
    }

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof addr);
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, path, sizeof(addr.sun_path) - 1);

    // The sim listens; retry briefly so launch order is forgiving.
    for (int attempt = 0; attempt < 20; attempt++) {
        int fd = socket(AF_UNIX, SOCK_STREAM, 0);
        if (fd < 0)
            break;
        if (connect(fd, (struct sockaddr *)&addr, sizeof addr) == 0) {
            link_fd = fd;
            link_up = true;
            return true;
        }
        close(fd);
        nap_ms(100);
    }

    link_up = false;
    return false;
}

bool picolink_active(void) {
    return link_up;
}

void picolink_send_byte(uint8_t byte) {
    if (!link_up)
        return;
    for (;;) {
        ssize_t n = write(link_fd, &byte, 1);
        if (n == 1)
            return;
        if (n < 0 && (errno == EINTR))
            continue;
        // EPIPE / ECONNRESET / anything else: the sim went away.
        link_up = false;
        return;
    }
}

bool picolink_poll_byte(uint8_t *out) {
    if (!link_up)
        return false;

    struct pollfd pfd = { .fd = link_fd, .events = POLLIN, .revents = 0 };
    int r = poll(&pfd, 1, 0);   // zero timeout: never block the CPU loop
    if (r <= 0)
        return false;

    if (pfd.revents & (POLLERR | POLLHUP | POLLNVAL)) {
        link_up = false;
        return false;
    }
    if (!(pfd.revents & POLLIN))
        return false;

    uint8_t b;
    ssize_t n = read(link_fd, &b, 1);
    if (n == 1) {
        *out = b;
        return true;
    }
    if (n == 0) {              // peer closed
        link_up = false;
    }
    return false;
}

void picolink_close(void) {
    if (link_fd >= 0)
        close(link_fd);
    link_fd = -1;
    link_up = false;
}
