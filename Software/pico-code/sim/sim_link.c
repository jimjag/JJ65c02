// Unix-domain socket link between the JJ65c02 VGA/Sound simulation and the
// x65c02 emulator (../../Emulator), standing in for the physical bus between
// the RP2350 support chip and the 6502 SBC.
//
//   - The sim LISTENS; the emulator connects (see Emulator's -p option).
//   - Bytes the emulated 6502 writes to the Pico ($A800) arrive on the socket
//     and are pushed into the firmware's input ring via sim_feed_6502_byte();
//     conInTask()/handleByte() render them exactly as on hardware.
//   - PS/2 key bytes decoded by the SDL viewer are shipped back to the emulator
//     with sim_link_send_key(), which injects them into the emulated VIA.
//
// The link is optional: if nothing ever connects, the sim just runs whatever
// content source is selected (demo or console) with no 6502 input. Build with
// -DHOST_SIM alongside the rest of the sim.

#include <errno.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#include "pico_shim.h"

#define SIM_SOCKET_DEFAULT "/tmp/jj65c02.sock"

static int             listen_fd = -1;
static volatile int    conn_fd   = -1;   // current emulator connection, or -1
static pthread_mutex_t conn_mx   = PTHREAD_MUTEX_INITIALIZER;
static volatile int    link_stop = 0;

// Accept loop: (re)accept an emulator connection and pump its bytes into the
// firmware input ring until it disconnects, then wait for the next one.
static void *link_thread(void *arg) {
    (void)arg;
    while (!link_stop) {
        int fd = accept(listen_fd, NULL, NULL);
        if (fd < 0) {
            if (errno == EINTR) continue;
            break;
        }
        pthread_mutex_lock(&conn_mx);
        conn_fd = fd;
        pthread_mutex_unlock(&conn_mx);

        unsigned char buf[512];
        for (;;) {
            ssize_t n = read(fd, buf, sizeof buf);
            if (n > 0) {
                for (ssize_t i = 0; i < n; i++)
                    sim_feed_6502_byte(buf[i]);
            } else if (n == 0) {
                break;                       // emulator closed
            } else if (errno == EINTR) {
                continue;
            } else {
                break;
            }
        }

        pthread_mutex_lock(&conn_mx);
        conn_fd = -1;
        pthread_mutex_unlock(&conn_mx);
        close(fd);
    }
    return NULL;
}

void sim_link_start(const char *path) {
    if (path == NULL || path[0] == '\0')
        path = getenv("SIM_SOCKET");
    if (path == NULL || path[0] == '\0')
        path = SIM_SOCKET_DEFAULT;

    listen_fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (listen_fd < 0) {
        fprintf(stderr, "sim_link: socket: %s\n", strerror(errno));
        return;
    }

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof addr);
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, path, sizeof(addr.sun_path) - 1);

    unlink(path);                            // clear a stale socket file
    if (bind(listen_fd, (struct sockaddr *)&addr, sizeof addr) < 0) {
        fprintf(stderr, "sim_link: bind %s: %s\n", path, strerror(errno));
        close(listen_fd);
        listen_fd = -1;
        return;
    }
    if (listen(listen_fd, 1) < 0) {
        fprintf(stderr, "sim_link: listen: %s\n", strerror(errno));
        close(listen_fd);
        listen_fd = -1;
        return;
    }

    fprintf(stderr, "sim_link: listening on %s (waiting for x65c02 -p %s)\n",
            path, path);

    pthread_t th;
    if (pthread_create(&th, NULL, link_thread, NULL) == 0)
        pthread_detach(th);
}

// Ship one PS/2 byte back to the emulator. Plain single byte == one keyboard
// character on the VIA (the STX-prefixed form is the separate PICO_DATA
// channel, not used here). Best-effort: silently dropped if nothing connected.
void sim_link_send_key(unsigned char c) {
    pthread_mutex_lock(&conn_mx);
    int fd = conn_fd;
    if (fd >= 0) {
        ssize_t n = write(fd, &c, 1);
        (void)n;                             // reader thread handles disconnect
    }
    pthread_mutex_unlock(&conn_mx);
}

// Host stand-in for ps2_keyboard.c's ps2Task(): on hardware core1 drains the
// PS/2 buffer and pushes each byte to the 6502 over the VIA (put_via_byte).
// Here we drain the same ps2GetChar() ring the SDL viewer feeds and ship the
// byte down the socket to the emulator, which injects it into the emulated VIA.
// pico_6502.c's core1_main calls this once per loop under HOST_SIM.
void ps2Task(bool auto_print) {
    unsigned char c = ps2GetChar(auto_print);
    if (c)
        sim_link_send_key(c);
}

void sim_link_stop(void) {
    link_stop = 1;
    pthread_mutex_lock(&conn_mx);
    if (conn_fd >= 0) { close(conn_fd); conn_fd = -1; }
    pthread_mutex_unlock(&conn_mx);
    if (listen_fd >= 0) { close(listen_fd); listen_fd = -1; }
}
