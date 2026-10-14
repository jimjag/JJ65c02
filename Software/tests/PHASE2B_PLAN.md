# Phase 2b Loader Tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Regression tests for miniOS menu options 1 (XMODEM load) and 2 (Intel-HEX load) through a real ACIA receive path.

**Architecture:** The emulator gets a 6551 model at `$A010-$A013` that talks to the harness over a Unix socket (`-a PATH`, same pattern as `picolink.c`). A second sim ROM, `simacia-minios.rom`, enables the ACIA code the plain sim ROM compiles out and makes `LIB_delay1ms` return immediately. A Python `SerialPeer` plays the other end of the serial line; `XmodemSession` and `IhexSession` drive the loaders from the menu.

**Tech Stack:** C (emulator, built by `Emulator/build`), ca65/ld65 (ROM), Python 3.14 + pytest via `uv`.

**Spec:** `tests/PHASE2B_DESIGN.md` (read it first; this plan implements it).

## Global Constraints

- Run from `Software/`. `uv run --no-env-file pytest ...` (never bare `uv run`: the shell exports `UV_ENV_FILE=./.env`; do not create a `.env`). `export CA65_INC=/Users/jim/src/6502/cc65/asminc` first.
- Test sim ROMs only (`sim-minios.rom`, `simacia-minios.rom`), never `minios.rom`. Do not lower `LINES` below 60. ESC cannot be sent on the console (the emulator swallows it); ESC on the *serial* line is fine.
- The emulator runs about 15K cycles/s. Anything cycle-counted in the ROM is slow; measure before assuming a test is affordable.
- `sim-minios.rom` must stay byte-identical: Task 3 proves it with `cmp`. The existing 199 tests must still pass unchanged.
- Commits: draft the message to a file, `bbedit --wait --resume <file>`, then `git commit -F <file>`. Subject line only unless the why is unrecoverable from the diff. No mention of AI, Claude or any assistant anywhere; no `Co-Authored-By`.
- Comments: none by default; one line for a non-obvious why. Claims in comments, commits and docs must be verified by a command.
- `rm`/`cp`/`mv` are interactive aliases: use `/bin/rm` etc. Build outputs and IDE files in `git status` are untracked on purpose: `git add` only the files a task names.
- Ask Jim before merging, pushing or deleting; pause after each task and ask "continue?".

## Review Focus

Input classes the spec implies that no single happy-path test covers; each has a test in the named task.

1. The peer closes the socket mid-run: the emulator must keep running and TX must not kill it with SIGPIPE (Task 2, `test_peer_disconnect_leaves_the_emulator_running`).
2. A whole 132-byte block written in one `send` while the ROM drains one byte per interrupt: no byte dropped, no reordering (Task 4, every block test; Task 2, `test_second_byte_waits_until_the_first_is_read`).
3. A failed transfer (`Transfer Error!`) followed by a good one in the same session: the menu and the loader are usable again (Task 4, `test_a_failed_transfer_does_not_poison_the_next_one`).
4. Intel-HEX with CRLF line endings, the common case from tools (Task 5, `test_crlf_line_endings`).
5. An Intel-HEX file that is only the EOF record (Task 5, `test_eof_only_file`).

---

### Task 1: SerialPeer and the `acia_path` session option

**Files:**
- Create: `Harness/serial_peer.py`, `tests/harness/test_serial_peer.py`
- Modify: `Harness/x65c02_session.py` (constructor and command line), `tests/harness/fake_emu.py` (getopt string)

**Interfaces:**
- Produces: `SerialPeer(path=None)`; `.path`, `.accept(timeout=10.0)`, `.send(data)`, `.wait_for(pattern, timeout=10.0) -> bytes` (consumes through the pattern), `.read(n, timeout=10.0) -> bytes`, `.unread() -> bytes` (no consume), `.clear()`, `.disconnect()`, `.close()`. Raises `EmulatorTimeout` on timeout. `EmulatorSession(..., acia_path=None)` adds `-a <acia_path>` to the command.

- [ ] **Step 1: Write the failing tests** `tests/harness/test_serial_peer.py`:

```python
import socket
import subprocess
import threading

import pytest

from serial_peer import SerialPeer
from x65c02_session import EmulatorSession, EmulatorTimeout


@pytest.fixture
def peer():
    p = SerialPeer()
    yield p
    p.close()


def _connect(path):
    c = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    c.connect(str(path))
    return c


def test_bytes_flow_both_ways(peer):
    t = threading.Thread(target=lambda: peer.accept(5))
    t.start()
    c = _connect(peer.path)
    t.join()
    peer.send(b"abc")
    assert c.recv(3) == b"abc"
    c.sendall(b"xyzC")
    assert peer.wait_for(b"z") == b"xyz"
    assert peer.read(1) == b"C"


def test_unread_does_not_consume(peer):
    t = threading.Thread(target=lambda: peer.accept(5))
    t.start()
    c = _connect(peer.path)
    t.join()
    c.sendall(b"hello")
    assert peer.wait_for(b"hello") == b"hello"
    c.sendall(b"more")
    peer.read(4)
    assert peer.unread() == b""


def test_wait_for_times_out_with_the_unread_tail(peer):
    t = threading.Thread(target=lambda: peer.accept(5))
    t.start()
    c = _connect(peer.path)
    t.join()
    c.sendall(b"abc")
    with pytest.raises(EmulatorTimeout, match="abc"):
        peer.wait_for(b"zzz", timeout=0.2)


def test_clear_discards_unread_bytes(peer):
    t = threading.Thread(target=lambda: peer.accept(5))
    t.start()
    c = _connect(peer.path)
    t.join()
    c.sendall(b"old")
    peer.wait_for(b"old")
    c.sendall(b"stale")
    peer.read(5)
    c.sendall(b"junk")
    peer.read(4)
    peer.clear()
    c.sendall(b"new")
    assert peer.wait_for(b"new") == b"new"


def test_path_stays_short_enough_for_af_unix(peer):
    assert len(str(peer.path)) < 100


def test_acia_path_becomes_dash_a(monkeypatch, tmp_path):
    seen = {}

    class Boom(Exception):
        pass

    def fake_popen(cmd, **kw):
        seen["cmd"] = cmd
        raise Boom

    monkeypatch.setattr(subprocess, "Popen", fake_popen)
    with pytest.raises(Boom):
        EmulatorSession("rom", tmp_path / "c.txt", emulator="emu",
                        acia_path="/x/s")
    assert seen["cmd"][seen["cmd"].index("-a") + 1] == "/x/s"
```

- [ ] **Step 2:** `uv run --no-env-file pytest -q tests/harness/test_serial_peer.py` → fails (`ModuleNotFoundError: serial_peer`).
- [ ] **Step 3: `Harness/serial_peer.py`:**

```python
"""The serial line for the emulator's ACIA (x65c02 -a PATH).

The harness listens and the emulator connects, as with the Pico sim link. A
reader thread drains the socket so a chatty ROM never blocks on a full buffer.
"""
import shutil
import socket
import tempfile
import threading
import time
from pathlib import Path

from x65c02_session import EmulatorTimeout


class SerialPeer:
    def __init__(self, path=None):
        self._dir = None
        if path is None:
            # AF_UNIX paths are limited to about 104 bytes; pytest's tmp_path can exceed that.
            self._dir = Path(tempfile.mkdtemp(prefix="acia-"))
            path = self._dir / "s"
        self.path = Path(path)
        if len(str(self.path)) >= 100:
            raise ValueError(f"socket path too long for AF_UNIX: {self.path}")
        self.path.unlink(missing_ok=True)
        self._srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self._srv.bind(str(self.path))
        self._srv.listen(1)
        self._conn = None
        self._buf = bytearray()
        self._mark = 0
        self._lock = threading.Lock()

    def accept(self, timeout=10.0):
        self._srv.settimeout(timeout)
        self._conn, _ = self._srv.accept()
        self._conn.settimeout(None)
        threading.Thread(target=self._drain, daemon=True).start()

    def _drain(self):
        while True:
            try:
                data = self._conn.recv(65536)
            except OSError:
                return
            if not data:
                return
            with self._lock:
                self._buf.extend(data)

    def send(self, data: bytes) -> None:
        self._conn.sendall(data)

    def _take(self, ready, timeout, what):
        deadline = time.monotonic() + timeout
        while True:
            with self._lock:
                end = ready(self._buf, self._mark)
                if end is not None:
                    out = bytes(self._buf[self._mark:end])
                    self._mark = end
                    return out
                tail = bytes(self._buf[self._mark:][-200:])
            if time.monotonic() >= deadline:
                raise EmulatorTimeout(
                    f"no {what} on the serial line within {timeout}s; "
                    f"unread: {tail!r}")
            time.sleep(0.005)

    def wait_for(self, pattern: bytes, timeout: float = 10.0) -> bytes:
        def ready(buf, mark):
            i = buf.find(pattern, mark)
            return None if i < 0 else i + len(pattern)
        return self._take(ready, timeout, repr(pattern))

    def read(self, n: int, timeout: float = 10.0) -> bytes:
        def ready(buf, mark):
            return mark + n if len(buf) - mark >= n else None
        return self._take(ready, timeout, f"{n} byte(s)")

    def unread(self) -> bytes:
        with self._lock:
            return bytes(self._buf[self._mark:])

    def clear(self) -> None:
        with self._lock:
            self._mark = len(self._buf)

    def disconnect(self) -> None:
        if self._conn is not None:
            self._conn.close()
            self._conn = None

    def close(self) -> None:
        self.disconnect()
        self._srv.close()
        self.path.unlink(missing_ok=True)
        if self._dir is not None:
            shutil.rmtree(self._dir, ignore_errors=True)
```

- [ ] **Step 4: `Harness/x65c02_session.py`:** add `acia_path=None` to the constructor signature (after `socket_path=None`) and, after the `socket_path` block, `if acia_path: cmd += ["-a", str(acia_path)]`. In `tests/harness/fake_emu.py` change the getopt string `"snfo:p:b:"` to `"snfo:p:b:a:"`.
- [ ] **Step 5:** `uv run --no-env-file pytest -q tests/harness` → all pass (the 6 new plus the existing ones).
- [ ] **Step 6:** Commit `Add the serial peer for the emulated ACIA` (files: the two new, `x65c02_session.py`, `fake_emu.py`).

---

### Task 2: Emulator ACIA model

**Files:**
- Create: `Emulator/src/acia.h`, `Emulator/src/acia.c`, `tests/minios/test_acia_model.py`
- Modify: `Emulator/src/functions.h` (read hook), `Emulator/src/io.c` (init, close, service, write hook), `Emulator/src/main.c` (`-a`), `tests/minios/conftest.py` (fixtures), `tests/minios_session.py` (`MenuSession.peer`, `MenuSession.close`)

**Interfaces:**
- Consumes: `SerialPeer`, `EmulatorSession(acia_path=)` from Task 1.
- Produces: emulator flag `-a PATH`; fixture `serial_menu` (function scope: a freshly booted plain-sim-ROM menu with a connected `SerialPeer`, available as `serial_menu.peer`); `MenuSession.peer` (None by default) and `MenuSession.close()` (closes the emulator, then the peer).

Model rules (the tests below pin them): status `$A011` = `$10` (TX empty) | `$08` (RX full) | `$80` (IRQ). A byte from the socket is delivered only when RX is empty and no CPU interrupt is pending. Delivery sets RX full; if command `$A012` bit 1 is clear (RX IRQ enabled) it also sets the IRQ bit and `interrupt_waiting`. Reading `$A010` clears RX full and IRQ; reading `$A011` clears IRQ only. Writing `$A010` sends the byte to the socket. A closed or failed socket silently deactivates the link. Without `-a` nothing changes.

- [ ] **Step 1: Fixtures.** In `tests/minios_session.py`, in `MenuSession.__init__` add `self.peer = None`, and add:

```python
    def close(self) -> None:
        self.emu.close()
        if self.peer is not None:
            self.peer.close()
```

In `tests/minios/conftest.py` add (imports: `from serial_peer import SerialPeer`):

```python
def _booted_serial(rom, emulator_bin, directory):
    peer = SerialPeer()
    emu = EmulatorSession(rom, directory / "console.txt", emulator=emulator_bin,
                          acia_path=peer.path)
    try:
        peer.accept(10.0)
        m = MenuSession(emu)
        m.peer = peer
        m.boot()
    except BaseException:
        emu.close()
        peer.close()
        raise
    return m


@pytest.fixture
def serial_menu(rom, emulator_bin, tmp_path):
    m = _booted_serial(rom, emulator_bin, tmp_path)
    yield m
    m.close()
```

- [ ] **Step 2: Write the failing tests** `tests/minios/test_acia_model.py`. They run on the plain sim ROM through Wozmon, which can read and write any address. Command `$A012` is set to `02` first (RX IRQ off) because the plain sim ROM's ISR treats every IRQ as a keyboard byte.

```python
import time

import pytest

from minios_session import WozmonSession

IDLE = "\r\nA011: 10\r\n"
RX_FULL = "\r\nA011: 18\r\n"


@pytest.fixture
def woz(serial_menu):
    w = WozmonSession(serial_menu)
    w.enter()
    w.line("A012: 02")
    return w


def eventually(fn, timeout=10.0):
    deadline = time.monotonic() + timeout
    while not fn():
        assert time.monotonic() < deadline, "condition never became true"
        time.sleep(0.05)


def test_idle_status_is_tx_empty(woz):
    assert woz.line("A011") == IDLE


def test_received_byte_sets_rx_full(woz):
    woz.menu.peer.send(b"Z")
    eventually(lambda: woz.line("A011") == RX_FULL)


def test_data_read_returns_the_byte_and_clears_rx_full(woz):
    woz.menu.peer.send(b"Z")
    eventually(lambda: woz.line("A011") == RX_FULL)
    assert woz.line("A010") == "\r\nA010: 5A\r\n"
    assert woz.line("A011") == IDLE


def test_second_byte_waits_until_the_first_is_read(woz):
    woz.menu.peer.send(b"AB")
    eventually(lambda: woz.line("A011") == RX_FULL)
    assert woz.line("A010") == "\r\nA010: 41\r\n"
    eventually(lambda: woz.line("A011") == RX_FULL)
    assert woz.line("A010") == "\r\nA010: 42\r\n"


def test_a_data_write_reaches_the_peer(woz):
    woz.menu.peer.clear()
    woz.line("A010: 41")
    assert woz.menu.peer.wait_for(b"A") == b"A"


def test_peer_disconnect_leaves_the_emulator_running(woz):
    woz.menu.peer.disconnect()
    assert woz.line("A011") == IDLE
    woz.line("A010: 42")
    assert woz.line("A011") == IDLE
```

- [ ] **Step 3:** `uv run --no-env-file pytest -q tests/minios/test_acia_model.py` → fails (emulator rejects `-a`: its option parser prints usage and exits, so the session reports `EmulatorExited` or a socket accept timeout).
- [ ] **Step 4: `Emulator/src/acia.h`:**

```c
#ifndef __6502_ACIA__
#define __6502_ACIA__

#include <stdbool.h>
#include <stdint.h>

#include "cpu.h"

// 6551 ACIA at $A010-$A013, serial line over a Unix socket the harness
// listens on (-a PATH). Without a path the registers stay plain RAM.
extern const char *acia_path;

bool acia_init(const char *path);
bool acia_active(void);
void acia_close(void);

// Call after every instruction: delivers a pending byte and refreshes $A011.
void acia_service(cpu *m);
// Call when the last instruction stored to addr in $A010-$A013.
void acia_write(cpu *m, uint16_t addr);
// Call from read_byte for every bus read.
void acia_note_read(uint16_t addr);

#endif
```

- [ ] **Step 5: `Emulator/src/acia.c`:**

```c
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

static void drop_link(void) {
    if (link_fd >= 0)
        close(link_fd);
    link_fd = -1;
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
    drop_link();
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
            return;
        if (n < 0 && errno == EINTR)
            continue;
        drop_link();
        return;
    }
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
                m->mem[ACIA_DATA] = byte;
                rx_full = true;
                if (!(m->mem[ACIA_COMMAND] & CMD_RX_IRQ_OFF)) {
                    irq_flag = true;
                    m->interrupt_waiting = 0x01;
                }
            } else if (!(n < 0 && (errno == EINTR || errno == EAGAIN))) {
                drop_link();
                return;
            }
        }
    }

    m->mem[ACIA_STATUS] = ST_TX_EMPTY | (rx_full ? ST_RX_FULL : 0) |
                          (irq_flag ? ST_IRQ : 0);
}
```

- [ ] **Step 6: Hook it in.**
  - `functions.h`: add `#include "acia.h"`; in `read_byte` keep the existing trace lines, then replace `return m->mem[address];` with `uint8_t value = m->mem[address]; if (address == 0xA010 || address == 0xA011) acia_note_read(address); return value;`.
  - `io.c`: add `#include "acia.h"`; `init_io()` calls `acia_init(acia_path);` after `picolink_init`; `finish_io()` calls `acia_close();` after `picolink_close()`; in `handle_io` call `acia_service(m);` right after the picolink keyboard block and, inside the `get_emu_flag(m, EMU_FLAG_DIRTY)` block, add `else if (addr == 0xA010) { acia_write(m, addr); }` after the `if (addr == IO_PUTCHAR) {...}` body.
  - `main.c`: option string `"hb:snfp:o:a:"`, `case 'a': acia_path = optarg; break;`, add `optopt == 'a'` to the missing-argument check, add `printf("  -a PATH connect the emulated 6551 ACIA ($A010) to the unix socket PATH\n");` to `usage()`, and `#include "acia.h"`.
  - Build: `cd Emulator && ./build` (compiles every `src/*.c`; a new file needs no build-script change). It must finish with no warnings from the new file.
- [ ] **Step 7:** `uv run --no-env-file pytest -q tests/minios/test_acia_model.py` → 6 pass. If a test fails, decide from the model rules above whether the test or the C is wrong before editing either.
- [ ] **Step 8:** Regression check: `uv run --no-env-file pytest -q tests/harness tests/minios` → all pass (94 existing + 6 new + 6 from Task 1 = 106). Plain runs without `-a` must be unaffected.
- [ ] **Step 9:** Commit `Add a 6551 ACIA model to the emulator` (files: `acia.h`, `acia.c`, `functions.h`, `io.c`, `main.c`, `conftest.py`, `minios_session.py`, `test_acia_model.py`).

---

### Task 3: ROM variant and the measuring gate

**Files:**
- Modify: `minios/src/acia.s` (`ACIA_init` guard), `minios/src/minios.s` (ISR), `minios/src/lib.s` (`LIB_delay1ms`), `minios/src/Makefile` (target), `tests/conftest.py` (`acia_rom` fixture)
- Create: `tests/minios/test_acia_rom.py`; add a "Measured results" section to `tests/PHASE2B_DESIGN.md`

**Interfaces:**
- Produces: `make simacia` writes `minios/src/simacia-minios.rom` (exactly `$5000` bytes, `$B000-$FFFF`); session fixture `acia_rom` (path to it); fixture `loader_menu` (module scope, like `menu`: a menu booted from `acia_rom` with a connected peer, rebooted when `broken`).

- [ ] **Step 1: Baseline.** `cd minios/src && make sim && /bin/cp sim-minios.rom ../../tests/minios/.baseline.rom`. (Delete `.baseline.rom` at the end of this task; never commit it.)
- [ ] **Step 2: Makefile.** After the `SOBJS` lines add `AOBJS=$(SRCS:%.s=aobjs/%.o)` and `TARGET3 = simacia`; after the `$(SOBJS)` rule add:

```make
$(AOBJS): $(SRCS)
	@mkdir -p aobjs
	ca65 -t none -D SIM=1 -D SIM_ACIA=1 --cpu w65c02 -U -I ./include -o $@ $(@:aobjs/%.o=%.s)
```

and after the `$(TARGET2)` rule:

```make
$(TARGET3): $(AOBJS)
	ld65 -C ./$(SIMCFG) -v -Ln simacia-minios.lbl -vm -m simacia-minios.map -o $(TARGET3) $(AOBJS)
```

Add `$(TARGET3) $(AOBJS) $(TARGET3)-minios.rom simacia-minios.lbl simacia-minios.map` to the `clean` rule. (`-o simacia` makes the ROM `simacia-minios.rom` because the config names it `%O-minios.rom`.)
- [ ] **Step 3: Source edits.**
  - `acia.s`, in `ACIA_init`: replace `.IFNDEF SIM` with `.IF (.NOT .DEFINED(SIM)) .OR .DEFINED(SIM_ACIA)` and its `.ENDIF` stays.
  - `minios.s`, in `ISR`: after the existing `.ENDIF` of the `.IFNDEF SIM` block and before `jsr VIA_ihandler` insert:

```asm
.IFDEF SIM_ACIA
    bit ACIA_STATUS
    bpl @sim_via
    jsr ACIA_ihandler
    bra @done
@sim_via:
.ENDIF
```

  (An ACIA interrupt must skip `VIA_ihandler`, which would push the stale keyboard byte into the input buffer.)
  - `lib.s`, at the top of `LIB_delay1ms` (label line 80) insert, directly after the label: `.IFDEF SIM_ACIA` / `    rts` / `.ENDIF`.
- [ ] **Step 4: Blast radius.** `make sim && cmp sim-minios.rom ../../tests/minios/.baseline.rom && echo identical` must print `identical`. `make simacia && ls -l simacia-minios.rom` must show 20480 bytes. If `.IF ... .OR ...` does not assemble, use nested `.IFNDEF SIM` / `.ELSE` / `.IFDEF SIM_ACIA` instead and say so in the commit only if the reason is not obvious.
- [ ] **Step 5: Fixtures.** In `tests/conftest.py` add next to `rom`:

```python
@pytest.fixture(scope="session")
def acia_rom():
    override = os.environ.get("MINIOS_ACIA_ROM")
    if override:
        return Path(override)
    src = SOFTWARE / "minios" / "src"
    _build(["make", "simacia"], src, CA65_HINT)
    path = src / "simacia-minios.rom"
    assert path.stat().st_size == 0x5000, "sim ROM must be exactly $B000-$FFFF"
    return path
```

In `tests/minios/conftest.py` add a module-scoped holder identical to `_menu_holder` but booting with `_booted_serial(acia_rom, ...)` and closing with `m.close()`, and `loader_menu`:

```python
@pytest.fixture(scope="module")
def _loader_holder(acia_rom, emulator_bin, tmp_path_factory):
    holder = {}

    def get():
        m = holder.get("m")
        if m is None or m.broken or not m.emu.alive:
            if m is not None:
                m.close()
            holder["m"] = m = _booted_serial(acia_rom, emulator_bin,
                                             tmp_path_factory.mktemp("loader"))
        return m

    yield get
    if "m" in holder:
        holder["m"].close()


@pytest.fixture
def loader_menu(_loader_holder):
    return _loader_holder()
```

- [ ] **Step 6: Write the failing test** `tests/minios/test_acia_rom.py`:

```python
def test_variant_boots_with_the_acia_enabled(loader_menu):
    assert "ACIA-enabled" in loader_menu.boot_output
    assert b"ACIA-enabled" in loader_menu.peer.wait_for(b"ACIA-enabled")
```

  Run before Step 5/3 are complete to see it fail, then after: `uv run --no-env-file pytest -q tests/minios/test_acia_rom.py` → pass. (The banner text goes to the console and, because `MINIOS_STATUS` bit 0 is set, to the serial line.)
- [ ] **Step 7: Measure, with a throwaway probe** (scratch directory, not committed). Using `EmulatorSession(acia_rom, ..., acia_path=peer.path)`, `SerialPeer`, `MenuSession` and `time.monotonic()`, record in a table in `PHASE2B_DESIGN.md` under "Measured results", each with its real transcript:
  1. boot text on console and on the serial line;
  2. menu `1`: console text up to the `L` prompt; after `L`: serial text up to and including the first `C`; how long until the first `C` and how often `C` repeats while idle;
  3. one good 128-byte block (build it with the Task 4 helpers if present, otherwise by hand): wall time from sending the block to the ACK; EOT to the end of `Transfer Successful!`; time until `OK> ` returns; the exact bytes after EOT (expected from the source: `06 04`, then `\n\rTransfer Successful!\n\r`);
  4. same for ESC on the serial line, a bad CRC, a wrong block number;
  5. menu `2`: console text to the `L` prompt; serial text after `L`; one record plus EOF: the `.` activity output, the result text, time to `OK> `;
  6. whether console `L` is echoed.
  If a one-block transfer exceeds about 30 s, or any step needs a real-time wait over a few minutes, stop and report: the test list shrinks (spec, "Task 1 is a measuring gate").
- [ ] **Step 8:** `/bin/rm tests/minios/.baseline.rom`; `uv run --no-env-file pytest -q tests/harness tests/minios` → all pass.
- [ ] **Step 9:** Commit `Add a sim ROM variant with the ACIA enabled` (files: the four ROM-side files, `tests/conftest.py`, `tests/minios/conftest.py`, `test_acia_rom.py`, `PHASE2B_DESIGN.md`).

---

### Task 4: XMODEM tests

**Files:**
- Create: `tests/loader_data.py`, `tests/harness/test_loader_data.py`, `tests/minios/test_xmodem.py`
- Modify: `tests/minios_session.py` (`dump_ram`, `_Loader`, `XmodemSession`)

**Interfaces:**
- Consumes: `loader_menu` (Task 3), `SerialPeer`, `WozmonSession`.
- Produces: `crc16(data, crc=0) -> int`; `xmodem_block(number, data, *, bad_crc=False, bad_complement=False) -> bytes`; `ihex_record(addr, data, rtype=0, *, bad_checksum=False) -> str`; `IHEX_EOF`; `SOH, EOT, ACK, NAK, ESC`; `dump_ram(menu, start, length) -> bytes`; `XmodemSession(menu)` with `enter()`, `begin()`, `wait_c()`, `send(raw)`, `reply()`, `end()`, `finish()`, `left`.

Expectations below come from `xmodem.s`; **reconcile every transcript string against the Task 3 measurements before relying on it** (decide from the source whether the test or the reading is wrong, as in Phase 2a).

- [ ] **Step 1: Failing tests for the data helpers** `tests/harness/test_loader_data.py`:

```python
from loader_data import (ACK, EOT, IHEX_EOF, SOH, crc16, ihex_record,
                         xmodem_block)


def test_crc16_check_value():
    assert crc16(b"123456789") == 0x31C3


def test_xmodem_block_layout():
    data = bytes(range(128))
    blk = xmodem_block(1, data)
    assert blk[:3] == bytes([SOH, 1, 0xFE]) and blk[3:131] == data
    assert blk[131:] == crc16(data).to_bytes(2, "big") and len(blk) == 133


def test_xmodem_block_faults_differ_from_the_good_block():
    data = bytes(128)
    good = xmodem_block(2, data)
    assert xmodem_block(2, data, bad_crc=True) != good
    assert xmodem_block(2, data, bad_complement=True)[2] != good[2]


def test_ihex_record_matches_the_published_example():
    assert ihex_record(0x0030, bytes([0x02, 0x33, 0x7A])) == ":0300300002337A1E"


def test_ihex_eof_record():
    assert IHEX_EOF == ihex_record(0, b"", rtype=1) == ":00000001FF"


def test_ihex_bad_checksum_differs():
    assert ihex_record(0x10, b"\x01", bad_checksum=True) != ihex_record(0x10, b"\x01")
```

- [ ] **Step 2: `tests/loader_data.py`:**

```python
"""Wire formats the loader tests send down the serial line."""
SOH, EOT, ACK, NAK, ESC = 0x01, 0x04, 0x06, 0x15, 0x1B


def crc16(data: bytes, crc: int = 0) -> int:
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc


def xmodem_block(number, data, *, bad_crc=False, bad_complement=False) -> bytes:
    assert len(data) == 128
    crc = crc16(data) ^ (0x0001 if bad_crc else 0)
    comp = (255 - number) ^ (0x55 if bad_complement else 0)
    return bytes([SOH, number & 0xFF, comp & 0xFF]) + data + crc.to_bytes(2, "big")


def ihex_record(addr, data, rtype=0, *, bad_checksum=False) -> str:
    body = bytes([len(data), addr >> 8, addr & 0xFF, rtype]) + bytes(data)
    checksum = (-sum(body)) & 0xFF
    if bad_checksum:
        checksum ^= 0x55
    return ":" + (body + bytes([checksum])).hex().upper()


IHEX_EOF = ihex_record(0, b"", rtype=1)
```

  Run `uv run --no-env-file pytest -q tests/harness/test_loader_data.py` → fails before the file exists, 6 pass after.
- [ ] **Step 3: Session classes** in `tests/minios_session.py` (imports: `from loader_data import ACK, EOT, NAK`):

```python
def dump_ram(menu, start, length) -> bytes:
    woz = WozmonSession(menu)
    woz.enter()
    out = woz.line(f"{start:04X}.{start + length - 1:04X}")
    woz.leave()
    data = bytearray()
    for ln in out.split("\r\n"):
        if ":" in ln:
            data += bytes.fromhex("".join(ln.split(":", 1)[1].split()))
    return bytes(data)


class _Loader(_Program):
    banner_pattern = b"to start: "

    def __init__(self, menu):
        super().__init__(menu)
        self.peer = menu.peer

    def enter(self) -> str:
        out = super().enter()
        self.peer.clear()
        return out

    def begin(self) -> None:
        self.emu.send(b"L")

    def finish(self, timeout=60.0) -> str:
        out = _text(self._wait(MENU, timeout))
        self.left = True
        return out


class XmodemSession(_Loader):
    key = b"1"

    def wait_c(self, timeout=60.0) -> bytes:
        return self.peer.wait_for(b"C", timeout)

    def send(self, raw: bytes) -> None:
        self.peer.send(raw)

    def reply(self, timeout=60.0) -> int:
        """Next ACK/NAK; the periodic 'C' start requests are skipped."""
        while True:
            b = self.peer.read(1, timeout)[0]
            if b != ord("C"):
                return b

    def end(self, timeout=60.0) -> bytes:
        self.send(bytes([EOT]))
        return self.peer.wait_for(b"Successful!\n\r", timeout)
```

  `WozmonSession` is defined earlier in the file; keep `dump_ram` below it. If the menu is left mid-transfer by a failing test, the fixture marks the menu broken (Step 4) so the next test reboots.
- [ ] **Step 4: Tests** `tests/minios/test_xmodem.py` (timeouts are generous until the Task 3 measurements tighten them):

```python
import pytest

from loader_data import ACK, ESC, NAK, xmodem_block
from minios_session import MENU, XmodemSession, dump_ram

LOAD = 0x0400


@pytest.fixture
def xm(loader_menu):
    x = XmodemSession(loader_menu)
    x.enter()
    x.begin()
    x.wait_c()
    yield x
    if not x.left:
        loader_menu.broken = True


def pattern(seed):
    return bytes((seed + i) & 0xFF for i in range(128))


def test_one_good_block_is_stored(xm, loader_menu):
    data = pattern(1)
    xm.send(xmodem_block(1, data))
    assert xm.reply() == ACK
    assert xm.end() == b"\x06\x04\n\rTransfer Successful!\n\r"
    xm.finish()
    assert dump_ram(loader_menu, LOAD, 128) == data


def test_two_blocks_are_stored_back_to_back(xm, loader_menu):
    a, b = pattern(0x10), pattern(0x90)
    xm.send(xmodem_block(1, a))
    assert xm.reply() == ACK
    xm.send(xmodem_block(2, b))
    assert xm.reply() == ACK
    xm.end()
    xm.finish()
    assert dump_ram(loader_menu, LOAD, 256) == a + b


def test_bad_crc_is_nakked_and_a_resend_succeeds(xm, loader_menu):
    data = pattern(0x20)
    xm.send(xmodem_block(1, data, bad_crc=True))
    assert xm.reply() == NAK
    xm.send(xmodem_block(1, data))
    assert xm.reply() == ACK
    xm.end()
    xm.finish()
    assert dump_ram(loader_menu, LOAD, 128) == data


def test_a_duplicate_block_is_acked_but_not_stored_again(xm, loader_menu):
    a, b = pattern(0x30), pattern(0xB0)
    xm.send(xmodem_block(1, a))
    assert xm.reply() == ACK
    xm.send(xmodem_block(1, b))
    assert xm.reply() == ACK
    xm.end()
    xm.finish()
    assert dump_ram(loader_menu, LOAD, 128) == a
    assert dump_ram(loader_menu, LOAD + 128, 128) != b


def test_wrong_block_number_is_a_fatal_error(xm):
    xm.send(xmodem_block(3, pattern(0x40)))
    assert xm.peer.wait_for(b"Transfer Error!\n\r")
    xm.finish()


def test_bad_complement_is_a_fatal_error(xm):
    xm.send(xmodem_block(1, pattern(0x50), bad_complement=True))
    assert xm.peer.wait_for(b"Transfer Error!\n\r")
    xm.finish()


def test_a_non_soh_first_byte_is_nakked(xm, loader_menu):
    data = pattern(0x60)
    xm.send(b"X")
    assert xm.reply() == NAK
    xm.send(xmodem_block(1, data))
    assert xm.reply() == ACK
    xm.end()
    xm.finish()
    assert dump_ram(loader_menu, LOAD, 128) == data


def test_esc_on_the_serial_line_aborts_without_an_error_message(xm):
    xm.send(bytes([ESC]))
    xm.finish()
    assert b"Transfer Error" not in xm.peer.unread()


def test_a_key_other_than_l_returns_to_the_menu(loader_menu):
    x = XmodemSession(loader_menu)
    x.enter()
    loader_menu.emu.send(b"x")
    x.finish()


def test_a_failed_transfer_does_not_poison_the_next_one(loader_menu):
    x = XmodemSession(loader_menu)
    x.enter(); x.begin(); x.wait_c()
    x.send(xmodem_block(3, pattern(0x70)))
    x.peer.wait_for(b"Transfer Error!\n\r")
    x.finish()
    data = pattern(0x71)
    y = XmodemSession(loader_menu)
    y.enter(); y.begin(); y.wait_c()
    y.send(xmodem_block(1, data))
    assert y.reply() == ACK
    y.end()
    y.finish()
    assert dump_ram(loader_menu, LOAD, 128) == data
```

  (`MENU` is imported for use in reconciled assertions; remove it if unused after reconciliation. The out-of-RAM error `$FB` is deliberately not tested: reaching `PROGRAM_END` takes about 300 blocks.)
- [ ] **Step 5:** `uv run --no-env-file pytest -q tests/minios/test_xmodem.py`; reconcile mismatches against the Task 3 transcripts. A test whose real-time cost is unacceptable (Task 3 measurements) is shrunk or dropped with the reason recorded in the design doc.
- [ ] **Step 6:** Prove the tests can fail: temporarily change the expected ACK byte in `test_one_good_block_is_stored` to `NAK`, confirm it fails, revert. Also confirm `test_bad_crc...` fails if `bad_crc=True` is removed (the ROM then replies ACK, not NAK).
- [ ] **Step 7:** `uv run --no-env-file pytest -q tests/harness tests/minios` → all pass; commit `Add the XMODEM loader tests`.

---

### Task 5: Intel-HEX tests

**Files:**
- Create: `tests/minios/test_ihex.py`
- Modify: `tests/minios_session.py` (`IhexSession`)

**Interfaces:**
- Consumes: `_Loader`, `dump_ram`, `ihex_record`, `IHEX_EOF`, `loader_menu`.
- Produces: `IhexSession(menu)` with `send_text(text)`, `result()`.

Expectations come from `intel-hex.s`; reconcile against the Task 3 measurements first. The ROM stores each data byte before checking the line checksum, ends at a type-01 record, treats ESC as the end of input (and then reports the checksum state), and reads lines ended by CR or LF.

- [ ] **Step 1: Session class** in `tests/minios_session.py`:

```python
class IhexSession(_Loader):
    key = b"2"

    def send_text(self, text: str) -> None:
        self.peer.send(text.encode("ascii"))
```

  Tests wait for the exact result message with `ih.peer.wait_for(...)`; the three strings in the source are `Intel Hex Imported OK.`, `Intel Hex Imported with checksum error.` and `Intel Hex Import aborted with overflow error.`.
- [ ] **Step 2: Tests** `tests/minios/test_ihex.py`:

```python
import pytest

from loader_data import ESC, IHEX_EOF, ihex_record
from minios_session import IhexSession, dump_ram

OK = b"Intel Hex Imported OK."
BAD = b"Intel Hex Imported with checksum error."
OVERFLOW = b"Intel Hex Import aborted with overflow error."


@pytest.fixture
def ih(loader_menu):
    x = IhexSession(loader_menu)
    x.enter()
    x.begin()
    x.peer.wait_for(b"Start Intel Hex code Transfer.")
    yield x
    if not x.left:
        loader_menu.broken = True


def test_a_good_record_and_eof_are_imported(ih, loader_menu):
    data = bytes([0xA9, 0x41, 0x8D, 0x00, 0xA8, 0x60])
    ih.send_text(ihex_record(0x0500, data) + "\n" + IHEX_EOF + "\n")
    ih.peer.wait_for(OK)
    ih.finish()
    assert dump_ram(loader_menu, 0x0500, 6) == data


def test_several_records_and_a_page_crossing(ih, loader_menu):
    a, b = bytes(range(16)), bytes(range(0x80, 0x90))
    ih.send_text("\n".join([ihex_record(0x05F8, a), ihex_record(0x0610, b),
                            IHEX_EOF]) + "\n")
    ih.peer.wait_for(OK)
    ih.finish()
    assert dump_ram(loader_menu, 0x05F8, 16) == a
    assert dump_ram(loader_menu, 0x0610, 16) == b


def test_a_bad_checksum_is_reported_but_the_data_is_still_stored(ih, loader_menu):
    data = bytes([0x11, 0x22, 0x33])
    ih.send_text(ihex_record(0x0540, data, bad_checksum=True) + "\n" + IHEX_EOF + "\n")
    ih.peer.wait_for(BAD)
    ih.finish()
    assert dump_ram(loader_menu, 0x0540, 3) == data


def test_lines_without_a_colon_are_ignored(ih, loader_menu):
    data = bytes([0x5A, 0xA5])
    ih.send_text("; a comment\n" + ihex_record(0x0560, data) + "\n" + IHEX_EOF + "\n")
    ih.peer.wait_for(OK)
    ih.finish()
    assert dump_ram(loader_menu, 0x0560, 2) == data


def test_crlf_line_endings(ih, loader_menu):
    data = bytes([0x01, 0x02, 0x03, 0x04])
    ih.send_text(ihex_record(0x0570, data) + "\r\n" + IHEX_EOF + "\r\n")
    ih.peer.wait_for(OK)
    ih.finish()
    assert dump_ram(loader_menu, 0x0570, 4) == data


def test_eof_only_file(ih):
    ih.send_text(IHEX_EOF + "\n")
    ih.peer.wait_for(OK)
    ih.finish()


def test_esc_on_the_serial_line_ends_the_import(ih):
    ih.peer.send(bytes([ESC]))
    ih.peer.wait_for(OK)
    ih.finish()


def test_an_over_long_line_aborts_with_the_overflow_message(ih):
    ih.send_text(":" + "0" * 140)
    ih.peer.wait_for(OVERFLOW)
    ih.finish()


def test_a_key_other_than_l_returns_to_the_menu(loader_menu):
    x = IhexSession(loader_menu)
    x.enter()
    loader_menu.emu.send(b"x")
    x.finish()
```

- [ ] **Step 3:** `uv run --no-env-file pytest -q tests/minios/test_ihex.py`; reconcile mismatches against Task 3 transcripts (the ESC case reports `OK` because `CRCCHECK` is still 0 there: confirm on the ROM, and if a different message appears, pin what the ROM does).
- [ ] **Step 4:** Prove a test can fail: change `data` in `test_a_good_record_and_eof_are_imported` by one byte in the expected value only, confirm failure, revert.
- [ ] **Step 5:** `uv run --no-env-file pytest -q tests/harness tests/minios` → all pass; commit `Add the Intel-HEX loader tests`.

---

### Task 6: Docs, full run, review

**Files:** Modify `tests/README.md`, `Harness/README.md`, the Emulator's option docs (find with `grep -rn -- "-o PATH" Emulator README.md ../README.md`), `AGENTS.md` (untracked), `tests/PHASE2B_DESIGN.md` (final measured numbers); refresh `HANDOFF.md` (untracked).

- [ ] **Step 1:** `tests/README.md`: extend "miniOS tier" with the loader tests: the `loader_menu` fixture and the ACIA ROM variant, why `LIB_delay1ms` returns immediately there, `SerialPeer`, the stale-`C` skipping in `XmodemSession.reply`, the out-of-RAM exclusion, `MINIOS_ACIA_ROM`, and measured per-transfer times from Task 3. Add the new files to the tier table and the run examples you actually ran.
- [ ] **Step 2:** `Harness/README.md`: document `EmulatorSession(acia_path=)` and `SerialPeer`. Emulator option docs: add `-a PATH`. `AGENTS.md`: mention `tests/minios/test_xmodem.py`/`test_ihex.py` and `simacia`.
- [ ] **Step 3: Full run in the background:** `(uv run --no-env-file pytest -q --durations=8 > $SCRATCH/full.log 2>&1; echo "exit=$?" >> $SCRATCH/full.log) &`. Expect 199 + the new tests, all passing; record count and time in `tests/README.md` (replace the 199/795 s figures). Run twice if any new test is timing-sensitive.
- [ ] **Step 4:** Verify every command written in the README by running it. Commit `Document the loader tests`.
- [ ] **Step 5: Whole-branch review** by a fresh reviewer on the most capable model over `git diff <commit before Task 1>..HEAD`: give it the code and the Review Focus list, not conclusions; one test-first fix pass.
- [ ] **Step 6:** Refresh `HANDOFF.md`. Ask Jim before merging or pushing; after merge, ask whether to remove `PHASE2B_PLAN.md` and `PHASE2B_DESIGN.md` as was done for Phase 1 and 2a.

---

## Self-review

- **Spec coverage:** emulator model (Task 2), ROM variant and cheap delays (Task 3), harness peer and session option (Task 1), `LoadSession` as `XmodemSession`/`IhexSession` (Tasks 4-5), fixtures (Tasks 2-3), ACIA-model tests via Wozmon (Task 2), every XMODEM and Intel-HEX case in the spec (Tasks 4-5), measuring gate (Task 3 Step 7), out of scope respected.
- **Placeholders:** none. Expectation strings not yet run against the ROM are reconciled in Task 4 Step 5 and Task 5 Step 3 by the compare-with-measurements rule, as in Phase 2a.
- **Type consistency:** `SerialPeer` method names (`wait_for`, `read`, `unread`, `clear`, `disconnect`, `close`) match across Tasks 1-5; `MenuSession.peer` and `.close()` defined in Task 2 are used by `_Loader` in Task 4; `loader_menu` defined in Task 3 is used in Tasks 4-5; `ACK/NAK/ESC/EOT` come from `loader_data` everywhere.
