# EhBASIC Test Suite (Phase 1) Implementation Plan

**Goal:** `uv run pytest` from `Software/` boots `sim-minios.rom` in `x65c02`
and verifies EhBASIC, with a smoke tier that checks pixels rendered by the
headless Pico sim.

**Architecture:** One importable pty driver (`Harness/x65c02_session.py`) reads
program output from the emulator's `-o` console log and types with
per-character echo confirmation. `tests/` layers a `BasicSession` and pytest
fixtures on it. The sim tier runs `_sim_dump` in a new signal-driven `serve`
mode on a private socket and asserts on BMP pixels.

**Tech stack:** Python >= 3.11, pytest, uv; ca65/ld65; cc; no new C or Python
dependencies beyond pytest.

**Spec:** `Software/tests/PHASE1_DESIGN.md`. Read it first.

## Global Constraints

- All paths are relative to `Software/`; run every command from there unless a
  step says otherwise.
- Test only `minios/src/sim-minios.rom`, never `minios.rom`.
- Emulator pty is `LINES=60`, `COLUMNS=132`. Never lower `LINES`.
- Program output is read from the `-o` console log only, never the pty.
- The emulator ignores SIGTERM: always SIGKILL.
- No test uses `/tmp/jj65c02.sock`.
- Edits under `pico-code/` touch only `sim/` files; nothing in `pico_core/`.
- BASIC text typed by tests is upper case ASCII.
- Comments: none by default; one line for a non-obvious why.
- Commits: draft the message to a file, `bbedit --wait --resume <file>`, then
  `git commit -F <file>`. Subject line only unless the why is unrecoverable
  from the diff. No tool or assistant attribution anywhere.
- `rm`/`cp`/`mv` are interactive aliases: use `/bin/rm` etc.

## Facts established before planning

Captured from a real run of the current ROM through the existing harness:

- Menu ends with `OK> `. Key `7` is not echoed; the ROM prints
  `\r\n Starting EhBASIC\r\n\r\n6502 EhBASIC ver 2.22p5.14j [C]old/[W]arm ?`.
  After `C`: `\r\n39679 Bytes free\r\n...\r\n\r\nReady\r\n`.
- Typed characters are echoed; Enter echoes as `\r\n`.
- Immediate statement: `PRINT 1/3` -> ` .333333\r\n` then `\r\nReady\r\n`.
- Errors: `\r\nDivide by zero Error\r\nReady\r\n`, `\r\nSyntax Error\r\nReady\r\n`.
- Numbered program lines echo and print nothing else (no `Ready`).
- `RECT 10,20,30,40,5` -> `\x1b[Z23;10;20;30;40;5Z` then `\r\nReady\r\n`.
- So for every statement: output is everything between the echoed line and the
  next `\r\nReady\r\n`.
- Keys are lost even at 0.2 s per key (`10 FOR` arrived as `0 FOR`, `PRINT
  STR$` as `T STR$`, `PLOT` as `LOT`). `handle_io()` in `Emulator/src/io.c`
  stores a new key over an unserviced one.
- Non-stop mode wrote 169 MB to the pty in 60 s; the pty must be drained
  continuously and not kept.
- `PLOT` is a line: `PLOT x1,y1,x2,y2,c`. Graphics colour is a palette index
  (`& 0x0f`). The 16-entry RGB palette is in `pico-code/sim/sim_dump.c`.

Expected values in the tasks below that are *not* in this list come from
standard EhBASIC behaviour and have not been run against this ROM. When such a
test fails on first run, decide whether the test or the interpreter is wrong
from the EhBASIC source; do not paste the observed value in as the expectation.

## Review Focus

1. A dropped or late key: typing must either land exactly or fail naming the
   character, never silently run a corrupted statement. (Task 3)
2. Emulator dies mid-wait: reported as an exit with the console tail, not as a
   timeout. (Task 2)
3. A test fails or raises: no emulator or sim process survives it. (Tasks 2, 9)
4. Unix socket path length: macOS limits `sun_path` to 104 bytes and pytest's
   temp paths exceed it; the socket lives in a short directory. (Task 9)
5. A program that never returns to `Ready` (infinite loop): the wait times out
   and the session is discarded, so it cannot poison later tests in the
   module. (Task 5)

---

## File structure

| File | Responsibility |
| --- | --- |
| `pyproject.toml` | uv project, pytest config, markers |
| `Harness/x65c02_session.py` | `EmulatorSession` and its exceptions |
| `Harness/x65c02-headless.py` | existing CLI, rebuilt on `EmulatorSession` |
| `tests/harness/fake_emu.py` | stand-in emulator for driver unit tests |
| `tests/harness/test_session.py` | driver unit tests |
| `tests/basic_session.py` | `BasicSession` |
| `tests/conftest.py` | build fixtures, `basic`, `fresh_basic` |
| `tests/basic/test_*.py` | console tier |
| `tests/bitmap.py` | BMP reader |
| `tests/sim/conftest.py` | `sim_basic` fixture |
| `tests/sim/test_bitmap.py`, `tests/sim/test_smoke.py` | sim tier |
| `pico-code/sim/sim_dump.c`, `pico-code/sim/build.sh` | `serve` mode, `dump-build` |

---

### Task 1: Project scaffold

**Files:**
- Create: `pyproject.toml`, `tests/harness/test_scaffold.py`
- Modify: `../.gitignore`

**Interfaces:**
- Produces: `uv run pytest` works from `Software/`; `Harness/` and `tests/`
  are on `sys.path`; marker `sim` is registered.

- [ ] **Step 1: Write `pyproject.toml`**

```toml
[project]
name = "jj65c02-tests"
version = "0"
requires-python = ">=3.11"

[dependency-groups]
dev = ["pytest>=8"]

[tool.uv]
package = false

[tool.pytest.ini_options]
testpaths = ["tests"]
pythonpath = ["Harness", "tests"]
addopts = "-ra --strict-markers"
markers = ["sim: needs the headless Pico sim build"]
```

- [ ] **Step 2: Write `tests/harness/test_scaffold.py`**

```python
import sys


def test_harness_dir_is_importable():
    assert any(p.endswith("Harness") for p in sys.path)
```

- [ ] **Step 3: Ignore generated files.** Append to `../.gitignore`:

```
**/.venv/
**/__pycache__/
**/.pytest_cache/
```

- [ ] **Step 4: Run**

Run: `uv run pytest -v`
Expected: `1 passed`. uv creates `.venv/` and `uv.lock` (this downloads pytest).
Then `git status --short | grep -c venv` prints `0`.

- [ ] **Step 5: Commit** `pyproject.toml`, `uv.lock`, `../.gitignore`,
  `tests/harness/test_scaffold.py`.

---

### Task 2: EmulatorSession core

**Files:**
- Create: `Harness/x65c02_session.py`, `tests/harness/fake_emu.py`,
  `tests/harness/test_session.py`
- Delete: `tests/harness/test_scaffold.py`

**Interfaces:**
- Produces:
  - `default_emulator() -> str`
  - `EmulatorError`, and subclasses `EmulatorTimeout`, `EmulatorExited`,
    `EchoMismatch`
  - `EmulatorSession(rom, console_path, *, emulator=None, speed="n", socket_path=None, keep_pty=False)`
  - `.send(keys: bytes) -> None`
  - `.wait_for(pattern: bytes, timeout: float = 10.0) -> bytes` — returns
    output from the mark through the end of the match and moves the mark there
  - `.alive: bool`, `.tail(n=400) -> bytes`, `.pty_bytes: bytearray | None`
  - `.close() -> None` (idempotent); context-manager support

- [ ] **Step 1: Write the fake emulator**, `tests/harness/fake_emu.py`, and
  `chmod +x` it.

```python
#!/usr/bin/env python3
"""Stand-in for x65c02: echoes typed bytes to the -o console log."""
import getopt
import os
import sys
import tty

opts = dict(getopt.getopt(sys.argv[1:], "snfo:p:b:")[0])
mode = os.environ.get("FAKE_EMU_MODE", "")
tty.setraw(0)
log = open(opts["-o"], "wb", buffering=0)
log.write(b"BOOT\r\n")
drop = 1 if mode == "drop-first" else 0
while True:
    b = os.read(0, 1)
    if not b or b == b"\x1b":
        break
    if mode == "die" and b == b"!":
        sys.exit(3)
    if mode == "mute":
        continue
    if drop:
        drop -= 1
        continue
    echo = b"\r\n" if b == b"\r" else b
    log.write(echo * 2 if mode == "dup" else echo)
```

- [ ] **Step 2: Write the failing tests**, `tests/harness/test_session.py`

```python
import os
import signal
from pathlib import Path

import pytest

from x65c02_session import EmulatorExited, EmulatorSession, EmulatorTimeout

FAKE = str(Path(__file__).with_name("fake_emu.py"))


@pytest.fixture
def session(tmp_path):
    s = EmulatorSession("unused.rom", tmp_path / "con.txt", emulator=FAKE)
    yield s
    s.close()


def test_wait_for_returns_output_through_match(session):
    assert session.wait_for(b"BOOT\r\n", 5) == b"BOOT\r\n"


def test_wait_for_only_sees_output_after_the_mark(session):
    session.wait_for(b"BOOT\r\n", 5)
    session.send(b"AB")
    assert session.wait_for(b"B", 5) == b"AB"
    with pytest.raises(EmulatorTimeout):
        session.wait_for(b"BOOT", 0.3)


def test_timeout_carries_pattern_and_console_tail(session):
    session.wait_for(b"BOOT\r\n", 5)
    session.send(b"XYZ")
    with pytest.raises(EmulatorTimeout) as e:
        session.wait_for(b"NEVER", 0.5)
    assert "NEVER" in str(e.value) and "XYZ" in str(e.value)


def test_exit_is_reported_as_exit_not_timeout(tmp_path, monkeypatch):
    monkeypatch.setenv("FAKE_EMU_MODE", "die")
    with EmulatorSession("unused.rom", tmp_path / "c.txt", emulator=FAKE) as s:
        s.wait_for(b"BOOT\r\n", 5)
        s.send(b"!")
        with pytest.raises(EmulatorExited):
            s.wait_for(b"NEVER", 5)
        assert not s.alive


def test_close_kills_the_process_and_is_idempotent(tmp_path):
    s = EmulatorSession("unused.rom", tmp_path / "c.txt", emulator=FAKE)
    s.wait_for(b"BOOT\r\n", 5)
    pid = s.pid
    s.close()
    s.close()
    with pytest.raises(ProcessLookupError):
        os.kill(pid, 0)


def test_context_manager_kills_on_exception(tmp_path):
    with pytest.raises(RuntimeError):
        with EmulatorSession("unused.rom", tmp_path / "c.txt", emulator=FAKE) as s:
            pid = s.pid
            raise RuntimeError("boom")
    with pytest.raises(ProcessLookupError):
        os.kill(pid, 0)


def test_pty_output_is_kept_only_on_request(tmp_path):
    with EmulatorSession("unused.rom", tmp_path / "a.txt", emulator=FAKE) as s:
        assert s.pty_bytes is None
    with EmulatorSession("unused.rom", tmp_path / "b.txt", emulator=FAKE,
                         keep_pty=True) as s:
        assert s.pty_bytes is not None
```

- [ ] **Step 3: Run to see them fail**

Run: `uv run pytest tests/harness -v`
Expected: collection error, `No module named 'x65c02_session'`.

- [ ] **Step 4: Implement `Harness/x65c02_session.py`**

```python
"""Drive the x65c02 ncurses emulator through a pty.

Program output is read from the emulator's -o console log, never from the pty.
"""
import os
import pty
import subprocess
import threading
import time
from pathlib import Path

_DEFAULT_EMU = Path(__file__).resolve().parent.parent / "Emulator" / "x65c02"


def default_emulator() -> str:
    return os.environ.get("X65C02") or str(_DEFAULT_EMU)


class EmulatorError(Exception):
    pass


class EmulatorTimeout(EmulatorError):
    pass


class EmulatorExited(EmulatorError):
    pass


class EchoMismatch(EmulatorError):
    pass


class EmulatorSession:
    def __init__(self, rom, console_path, *, emulator=None, speed="n",
                 socket_path=None, keep_pty=False):
        self.console_path = Path(console_path)
        self.console_path.unlink(missing_ok=True)
        env = dict(os.environ, LINES="60", COLUMNS="132")
        env.setdefault("TERM", "xterm-256color")
        cmd = [emulator or default_emulator(), f"-{speed}",
               "-o", str(self.console_path)]
        if socket_path:
            cmd += ["-p", str(socket_path)]
        cmd.append(str(rom))
        self._master, slave = pty.openpty()
        self._proc = subprocess.Popen(cmd, stdin=slave, stdout=slave,
                                      stderr=subprocess.DEVNULL, env=env,
                                      close_fds=True)
        os.close(slave)
        self.pid = self._proc.pid
        self.pty_bytes = bytearray() if keep_pty else None
        self._buf = bytearray()
        self._mark = 0
        self._log = None
        self._closed = False
        threading.Thread(target=self._drain_pty, daemon=True).start()

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()

    @property
    def alive(self) -> bool:
        return self._proc.poll() is None

    def _drain_pty(self):
        # Unread pty output blocks the emulator once the kernel buffer fills.
        while True:
            try:
                data = os.read(self._master, 65536)
            except OSError:
                return
            if not data:
                return
            if self.pty_bytes is not None:
                self.pty_bytes.extend(data)

    def _fill(self):
        if self._log is None:
            try:
                self._log = open(self.console_path, "rb")
            except FileNotFoundError:
                return
        self._buf.extend(self._log.read())

    def tail(self, n=400) -> bytes:
        return bytes(self._buf[-n:])

    def send(self, keys: bytes) -> None:
        os.write(self._master, keys)

    def _poll(self, ready, what, timeout):
        deadline = time.monotonic() + timeout
        while True:
            dead = not self.alive
            self._fill()
            if ready():
                return
            if dead:
                raise EmulatorExited(
                    f"emulator exited (status {self._proc.returncode}) "
                    f"waiting for {what}; console tail: {self.tail()!r}")
            if time.monotonic() >= deadline:
                raise EmulatorTimeout(
                    f"no {what} within {timeout}s; "
                    f"console tail: {self.tail()!r}")
            time.sleep(0.005)

    def wait_for(self, pattern: bytes, timeout: float = 10.0) -> bytes:
        self._poll(lambda: self._buf.find(pattern, self._mark) >= 0,
                   repr(pattern), timeout)
        end = self._buf.find(pattern, self._mark) + len(pattern)
        out = bytes(self._buf[self._mark:end])
        self._mark = end
        return out

    def close(self) -> None:
        if self._closed:
            return
        self._closed = True
        if self.alive:
            try:
                os.write(self._master, b"\x1b")
                self._proc.wait(timeout=1.0)
            except (OSError, subprocess.TimeoutExpired):
                pass
        self._proc.kill()
        self._proc.wait()
        os.close(self._master)
        if self._log is not None:
            self._log.close()
```

- [ ] **Step 5: Run**

Run: `uv run pytest tests/harness -v`
Expected: `7 passed`. Then `pgrep -f fake_emu.py` prints nothing.

- [ ] **Step 6: Delete `tests/harness/test_scaffold.py`; commit.**

---

### Task 3: Echo-confirmed typing

**Files:**
- Modify: `Harness/x65c02_session.py`
- Test: `tests/harness/test_session.py`

**Interfaces:**
- Consumes: `EmulatorSession._poll`, `.send`, `._buf`, `._mark`
- Produces:
  - `.expect_exact(expected: bytes, timeout: float) -> None` — the next bytes
    after the mark must equal `expected`; advances the mark
  - `.type_text(text: str, echo_timeout: float = 1.0, retries: int = 1) -> None`
    — `\r` is expected to echo as `\r\n`, any other character as itself

- [ ] **Step 1: Add failing tests** to `tests/harness/test_session.py`

```python
from x65c02_session import EchoMismatch


def _mode_session(tmp_path, monkeypatch, mode):
    monkeypatch.setenv("FAKE_EMU_MODE", mode)
    s = EmulatorSession("unused.rom", tmp_path / "c.txt", emulator=FAKE)
    s.wait_for(b"BOOT\r\n", 5)
    return s


def test_type_text_confirms_every_character(session):
    session.wait_for(b"BOOT\r\n", 5)
    session.type_text("PRINT 1\r")
    assert session.tail().endswith(b"PRINT 1\r\n")
    with pytest.raises(EmulatorTimeout):
        session.wait_for(b"1", 0.2)          # mark is past the whole echo


def test_dropped_key_is_resent_once(tmp_path, monkeypatch):
    s = _mode_session(tmp_path, monkeypatch, "drop-first")
    try:
        s.type_text("PLOT", echo_timeout=0.3)
        assert s.tail().endswith(b"BOOT\r\nPLOT")
    finally:
        s.close()


def test_key_never_echoed_fails_naming_the_character(tmp_path, monkeypatch):
    s = _mode_session(tmp_path, monkeypatch, "mute")
    try:
        with pytest.raises(EmulatorTimeout) as e:
            s.type_text("Q", echo_timeout=0.2)
        assert "b'Q'" in str(e.value)
    finally:
        s.close()


def test_wrong_echo_is_a_mismatch_not_a_pass(tmp_path, monkeypatch):
    s = _mode_session(tmp_path, monkeypatch, "dup")
    try:
        with pytest.raises(EchoMismatch):
            s.type_text("AB", echo_timeout=0.3)
    finally:
        s.close()
```

- [ ] **Step 2: Run to see them fail**

Run: `uv run pytest tests/harness -v`
Expected: 4 failures, `AttributeError: ... 'type_text'`.

- [ ] **Step 3: Implement.** Add to `EmulatorSession`:

```python
    def expect_exact(self, expected: bytes, timeout: float) -> None:
        start = self._mark
        try:
            self._poll(lambda: len(self._buf) - start >= len(expected),
                       f"echo {expected!r}", timeout)
        except EmulatorTimeout:
            if len(self._buf) == start:
                raise
        got = bytes(self._buf[start:start + len(expected)])
        if got != expected:
            raise EchoMismatch(f"typed {expected!r}, console shows {got!r}; "
                               f"console tail: {self.tail()!r}")
        self._mark = start + len(expected)

    def type_text(self, text: str, echo_timeout: float = 1.0,
                  retries: int = 1) -> None:
        for ch in text:
            echo = b"\r\n" if ch == "\r" else ch.encode("ascii")
            for attempt in range(retries + 1):
                self.send(ch.encode("ascii"))
                try:
                    self.expect_exact(echo, echo_timeout)
                    break
                except EmulatorTimeout:
                    if attempt == retries:
                        raise
```

In the `dup` case the first `A` matches and the second `A` is then read where
`B` is expected, which is the mismatch the test wants.

- [ ] **Step 4: Run**

Run: `uv run pytest tests/harness -v`
Expected: `11 passed`.

- [ ] **Step 5: Commit.**

---

### Task 4: Build fixtures and measurement against the real emulator

Settles spec open items 2 and 3. **Stop and report to Jim at Step 5** before
continuing.

**Files:**
- Create: `tests/conftest.py`, `tests/basic/test_boot.py`

**Interfaces:**
- Produces fixtures `rom -> Path`, `emulator_bin -> str` (both session scope).

- [ ] **Step 1: Write `tests/conftest.py`**

```python
import os
import subprocess
from pathlib import Path

import pytest

SOFTWARE = Path(__file__).resolve().parent.parent
CA65_HINT = ("If ca65 cannot open 'generic.mac': "
             "export CA65_INC=/Users/jim/src/6502/cc65/asminc")


def _build(cmd, cwd, hint=""):
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if r.returncode != 0:
        pytest.fail(f"{' '.join(cmd)} failed in {cwd}:\n{r.stdout}{r.stderr}\n{hint}",
                    pytrace=False)


@pytest.fixture(scope="session")
def rom():
    src = SOFTWARE / "minios" / "src"
    _build(["make", "sim"], src, CA65_HINT)
    path = src / "sim-minios.rom"
    assert path.stat().st_size == 0x5000, "sim ROM must be exactly $B000-$FFFF"
    return path


@pytest.fixture(scope="session")
def emulator_bin():
    override = os.environ.get("X65C02")
    if override:
        return override
    emu = SOFTWARE / "Emulator"
    _build(["./build"], emu)
    return str(emu / "x65c02")
```

- [ ] **Step 2: Write `tests/basic/test_boot.py`**

```python
import time

from x65c02_session import EmulatorSession


def test_boots_to_basic_ready(rom, emulator_bin, tmp_path, capsys):
    t0 = time.monotonic()
    with EmulatorSession(rom, tmp_path / "con.txt", emulator=emulator_bin) as s:
        s.wait_for(b"OK> ", 60)
        t_menu = time.monotonic() - t0
        s.send(b"7")
        s.wait_for(b"[C]old/[W]arm ?", 30)
        s.send(b"C")
        s.wait_for(b"\r\nReady\r\n", 60)
        t_ready = time.monotonic() - t0
        t1 = time.monotonic()
        for _ in range(20):
            s.type_text("PRINT 12345\r", echo_timeout=2.0, retries=0)
            assert s.wait_for(b"\r\nReady\r\n", 10) == b" 12345\r\n\r\nReady\r\n"
        t_typing = time.monotonic() - t1
    with capsys.disabled():
        print(f"\nmenu {t_menu:.1f}s  ready {t_ready:.1f}s  "
              f"20 statements {t_typing:.1f}s")
```

`retries=0` is deliberate: this measures whether keys drop when each one waits
for its echo. A drop fails the test instead of being hidden by a resend.

- [ ] **Step 3: Run it five times**

Run: `for i in 1 2 3 4 5; do uv run pytest tests/basic/test_boot.py -q || break; done`
Record the three timings from each run.

- [ ] **Step 4: Interpret**

| Observation | Consequence |
| --- | --- |
| 5/5 pass | Echo-paced typing is lossless. Keep `retries=1` as the default anyway. |
| `EmulatorTimeout` on a character | Keys still drop with echo pacing. Re-run with `retries=1`; if that passes 5/5, proceed. |
| `EchoMismatch` with `retries=1` | A resend duplicated a late echo. Raise `echo_timeout`; if still failing, stop — the fix belongs in `handle_io()` (do not take a new key while `interrupt_waiting` is set, as the Pico-link path already does), which is an emulator change Jim must approve. |
| `7` or `C` not taken (timeout at those waits) | Task 5 already retries those keys; note it. |

- [ ] **Step 5: Report to Jim:** pass counts, the timings, and which row
  applied. If `ready` is under about 3 s, propose making `basic` function
  scoped (spec open item 3); otherwise keep module scope as written in Task 5.

- [ ] **Step 6: Commit** `tests/conftest.py`, `tests/basic/test_boot.py`.

---

### Task 5: BasicSession and fixtures

**Files:**
- Create: `tests/basic_session.py`, `tests/basic/test_session_basics.py`
- Modify: `tests/conftest.py`, `tests/basic/test_boot.py`

**Interfaces:**
- Consumes: `EmulatorSession`, `EmulatorError`; fixtures `rom`, `emulator_bin`
- Produces:
  - `BasicSession(emu: EmulatorSession)`; `.emu`; `.broken: bool`
  - `.boot() -> None`
  - `.eval(statement: str, timeout: float = 10.0) -> str` — output with
    `\r\n` normalised to `\n`
  - `.enter(program: str) -> None` — one numbered line per text line
  - `.run(program: str, timeout: float = 30.0) -> str` — `NEW`, enter, `RUN`
  - `.new() -> None`
  - fixtures `basic` (fresh `NEW` per test, one boot per module) and
    `fresh_basic` (own boot)

- [ ] **Step 1: Write failing tests**, `tests/basic/test_session_basics.py`

```python
import pytest

from x65c02_session import EmulatorTimeout


def test_eval_returns_only_program_output(basic):
    assert basic.eval("PRINT 1/3") == " .333333\n"


def test_print_list(basic):
    assert basic.eval('PRINT "A";1;-2;"B"') == "A 1-2B\n"


def test_run_program(basic):
    out = basic.run("""
        10 FOR I=1 TO 3
        20 PRINT I*I
        30 NEXT
    """)
    assert out == " 1\n 4\n 9\n"


def test_new_between_tests_clears_the_program(basic):
    assert basic.eval("LIST") == "\n"


def test_error_text_is_returned(basic):
    assert basic.eval("PRINT 1/0") == "\nDivide by zero Error"


def test_runaway_program_marks_session_broken(fresh_basic):
    with pytest.raises(EmulatorTimeout):
        fresh_basic.run("10 GOTO 10", timeout=2.0)
    assert fresh_basic.broken


def test_session_after_a_broken_one_still_works(basic):
    assert basic.eval("PRINT 2") == " 2\n"
```

- [ ] **Step 2: Run to see them fail**

Run: `uv run pytest tests/basic/test_session_basics.py -v`
Expected: errors, `fixture 'basic' not found`.

- [ ] **Step 3: Write `tests/basic_session.py`**

```python
"""EhBASIC on top of an EmulatorSession."""
import textwrap

from x65c02_session import EmulatorError, EmulatorTimeout

PROMPT = b"\r\nReady\r\n"


class BasicSession:
    def __init__(self, emu):
        self.emu = emu
        self.broken = False

    def _key_until(self, key: bytes, pattern: bytes, tries=3, timeout=5.0):
        for attempt in range(tries):
            self.emu.send(key)
            try:
                return self.emu.wait_for(pattern, timeout)
            except EmulatorTimeout:
                if attempt == tries - 1:
                    raise

    def boot(self) -> None:
        self.emu.wait_for(b"OK> ", 60)
        self._key_until(b"7", b"[C]old/[W]arm ?")
        self._key_until(b"C", b"Bytes free")
        self.emu.wait_for(PROMPT, 60)

    def eval(self, statement: str, timeout: float = 10.0) -> str:
        try:
            self.emu.type_text(statement + "\r")
            out = self.emu.wait_for(PROMPT, timeout)
        except EmulatorError:
            self.broken = True
            raise
        return out[:-len(PROMPT)].decode("latin-1").replace("\r\n", "\n")

    def enter(self, program: str) -> None:
        try:
            for line in textwrap.dedent(program).strip().splitlines():
                self.emu.type_text(line.strip() + "\r")
        except EmulatorError:
            self.broken = True
            raise

    def new(self) -> None:
        self.eval("NEW")

    def run(self, program: str, timeout: float = 30.0) -> str:
        self.new()
        self.enter(program)
        return self.eval("RUN", timeout)
```

- [ ] **Step 4: Add fixtures** to `tests/conftest.py`

```python
from basic_session import BasicSession
from x65c02_session import EmulatorSession


def _booted(rom, emulator_bin, directory):
    emu = EmulatorSession(rom, directory / "console.txt", emulator=emulator_bin)
    try:
        b = BasicSession(emu)
        b.boot()
    except BaseException:
        emu.close()
        raise
    return b


@pytest.fixture(scope="module")
def _basic_holder(rom, emulator_bin, tmp_path_factory):
    holder = {}

    def get():
        b = holder.get("b")
        if b is None or b.broken or not b.emu.alive:
            if b is not None:
                b.emu.close()
            holder["b"] = b = _booted(rom, emulator_bin,
                                      tmp_path_factory.mktemp("basic"))
        return b

    yield get
    if "b" in holder:
        holder["b"].emu.close()


@pytest.fixture
def basic(_basic_holder):
    b = _basic_holder()
    b.new()
    return b


@pytest.fixture
def fresh_basic(rom, emulator_bin, tmp_path):
    b = _booted(rom, emulator_bin, tmp_path)
    yield b
    b.emu.close()
```

A broken or dead shared session is replaced before the next test, which is
what keeps one runaway program from failing the rest of the module.

- [ ] **Step 5: Run**

Run: `uv run pytest tests/basic/test_session_basics.py -v`
Expected: `7 passed`. Then `pgrep x65c02` prints nothing.

- [ ] **Step 6: Prove the echo stripping could fail.** Temporarily change
  `eval` to return `(statement + "\n" + ...)`; run; expect
  `test_eval_returns_only_program_output` to fail; revert.

- [ ] **Step 7: Simplify `tests/basic/test_boot.py`** to use `fresh_basic` and
  drop the timing print (its job ended with Task 4):

```python
def test_twenty_statements_in_a_row(fresh_basic):
    for _ in range(20):
        assert fresh_basic.eval("PRINT 12345") == " 12345\n"
```

- [ ] **Step 8: Run the whole suite, then commit.**

Run: `uv run pytest -q`
Expected: all pass.

---

### Task 6: Rebuild the CLI on EmulatorSession

**Files:**
- Modify: `Harness/x65c02-headless.py` (replace `main()`; keep the docstring,
  `ANSI_RE`, `clean()`, and every option)

**Interfaces:**
- Consumes: `EmulatorSession(..., keep_pty=True)`, `.send`, `.alive`,
  `.pty_bytes`, `.close`, `default_emulator`
- Produces: unchanged command line, script format, exit status and closing
  line.

- [ ] **Step 1: Capture a baseline with the current script** (from the repo
  root, as its README requires)

```bash
cd .. && printf '2.0 7\n3.0 C\n2.0 PRINT 1/3\\r\n' > /tmp/cli-probe.txt
./Software/Harness/x65c02-headless.py Software/minios/src/sim-minios.rom \
    /tmp/cli-probe.txt -o /tmp/base-t.txt --console /tmp/base-con.txt \
    --speed n --boot 4 --char-delay 0.2; echo "exit=$?"
```

Expected: `(emulator ok)`, `exit=0`, and `grep -c 333333 /tmp/base-con.txt`
prints `1`. Use the session scratch directory instead of `/tmp` if one is
provided.

- [ ] **Step 2: Replace the body.** Remove the `EMU` constant and the `pty`,
  `select`, `signal`, `subprocess` imports; add `import tempfile` and
  `from x65c02_session import EmulatorSession, default_emulator`. New `main()`
  after the unchanged argument parsing and script reading:

```python
    console = args.console
    scratch = None
    if console is None:
        scratch = tempfile.NamedTemporaryFile(suffix=".console", delete=False)
        scratch.close()
        console = scratch.name

    session = EmulatorSession(args.rom, console, emulator=default_emulator(),
                              speed=args.speed, keep_pty=True)
    deadline = time.time() + args.deadline

    def pause(duration: float) -> None:
        end = min(time.time() + duration, deadline)
        while session.alive and time.time() < end:
            time.sleep(0.02)

    status = 0
    pause(args.boot)
    for step in steps:
        if not session.alive or time.time() >= deadline:
            status = 1
            break
        delay, _, text = step.partition(" ")
        for ch in text.replace("\\r", "\r").replace("\\e", "\x1b"):
            if not session.alive:
                break
            session.send(ch.encode())
            pause(args.char_delay)
        pause(float(delay))
    if not session.alive:
        status = 1

    session.close()
    collected = bytes(session.pty_bytes)
    if scratch is not None:
        os.unlink(console)

    if args.raw:
        with open(args.raw, "wb") as f:
            f.write(collected)
    with open(args.out, "w") as f:
        f.write(clean(collected))
```

Keep the existing closing `print(...)` and `return status` lines as they are.
`close()` does not join the drain thread, so the last pty bytes can arrive
after it returns. If Step 3's raw byte count comes up short, join the thread
in `close()` rather than sleeping here.

- [ ] **Step 3: Re-run the Step 1 command** with `/tmp/new-*` outputs.

Expected: `(emulator ok)`, `exit=0`,
`diff /tmp/base-con.txt /tmp/new-con.txt` empty, and both transcripts contain
all four pane titles:

```bash
for t in Terminal "CPU Monitor" "Bus Trace" Memory; do
  printf '%-12s %s %s\n' "$t" "$(grep -c "$t" /tmp/base-t.txt)" "$(grep -c "$t" /tmp/new-t.txt)"
done
```

Expected: no count is 0. Raw byte counts within a few percent of each other.

- [ ] **Step 4: Check the deadline path**

Run the same command with `--deadline 3`.
Expected: `exit=1`, returns in about 4 s, `pgrep x65c02` prints nothing.

- [ ] **Step 5: Confirm one driver remains**

Run: `grep -rn "openpty" --include='*.py' .`
Expected: only `Harness/x65c02_session.py`.

- [ ] **Step 6: Commit.**

---

### Task 7: Console tier — language tests

**Files:**
- Create: `tests/basic/test_numeric.py`, `test_strings.py`, `test_control.py`,
  `test_data.py`, `test_errors.py`
- Delete: `tests/basic/test_session_basics.py` cases now duplicated (keep the
  runaway and broken-session tests there)

**Interfaces:**
- Consumes: fixture `basic`; `BasicSession.eval`, `.run`

Each module is a table of `(source, expected)`; a failure shows the BASIC text.

- [ ] **Step 1: `tests/basic/test_numeric.py`**

```python
import pytest

CASES = [
    ("PRINT 1/3", " .333333\n"),
    ("PRINT 2+3*4", " 14\n"),
    ("PRINT (2+3)*4", " 20\n"),
    ("PRINT 2^10", " 1024\n"),
    ("PRINT -2^2", "-4\n"),
    ("PRINT 7-10", "-3\n"),
    ("PRINT 0", " 0\n"),
    ("PRINT 1E10", " 1E+10\n"),
    ("PRINT 1/1E10", " 1E-10\n"),
    ("PRINT 123456789", " 1.23457E+8\n"),
    ("PRINT INT(3.7);INT(-3.7)", " 3-4\n"),
    ("PRINT ABS(-5);SGN(-5);SGN(0);SGN(5)", " 5-1 0 1\n"),
    ("PRINT SQR(16)", " 4\n"),
    ("PRINT 7 AND 3;7 OR 8;7 EOR 2", " 3 15 5\n"),
    ("PRINT 1<<4;256>>4", " 16 16\n"),
    ("PRINT MAX(3,9,4);MIN(3,9,4)", " 9 3\n"),
    ("PRINT 3=3;3=4;3<4", "-1 0-1\n"),
    ("PRINT $FF;%1010", " 255 10\n"),
    ('PRINT HEX$(255);" ";BIN$(5)', "FF 101\n"),
]


@pytest.mark.parametrize("source,expected", CASES, ids=[c[0] for c in CASES])
def test_numeric(basic, source, expected):
    assert basic.eval(source) == expected
```

- [ ] **Step 2: `tests/basic/test_strings.py`**

```python
import pytest

CASES = [
    ('PRINT "HELLO"', "HELLO\n"),
    ('PRINT "AB"+"CD"', "ABCD\n"),
    ('PRINT LEN("HELLO")', " 5\n"),
    ('PRINT LEFT$("HELLO",2);"|";RIGHT$("HELLO",2);"|";MID$("HELLO",2,3)',
     "HE|LO|ELL\n"),
    ('PRINT MID$("HELLO",4)', "LO\n"),
    ('PRINT ASC("A");CHR$(66)', " 65B\n"),
    ('PRINT STR$(12.5)+"X"', " 12.5X\n"),
    ('PRINT STR$(-3)+"X"', "-3X\n"),
    ('PRINT VAL("12.5")+1', " 13.5\n"),
    ('PRINT VAL("ABC")', " 0\n"),
    ('PRINT UCASE$("abC");LCASE$("ABc")', "ABCabc\n"),
    ('PRINT "A"<"B";"B"<"A";"A"="A"', "-1 0-1\n"),
    ('A$="X":B$=A$+A$:PRINT B$;LEN(B$)', "XX 2\n"),
]


@pytest.mark.parametrize("source,expected", CASES, ids=[c[0] for c in CASES])
def test_strings(basic, source, expected):
    assert basic.eval(source) == expected


def test_cstr_matches_its_documented_behaviour(basic):
    # Read LAB_CSTRS in minios/src/ehbasic.s first and assert what it documents.
    out = basic.eval("PRINT CSTR$(1234)")
    assert "Error" not in out and out.strip() != ""
```

The two lower-case string literals are inside quotes, where case is preserved;
they are the only lower case this suite types. `test_cstr...` is deliberately
weak as written: Step 6 replaces it.

- [ ] **Step 3: `tests/basic/test_control.py`**

```python
def test_for_step_and_reverse(basic):
    assert basic.run("""
        10 FOR I=10 TO 1 STEP -3
        20 PRINT I;
        30 NEXT
    """) == " 10 7 4 1\n"


def test_nested_for(basic):
    assert basic.run("""
        10 FOR I=1 TO 2:FOR J=1 TO 2
        20 PRINT I*10+J;
        30 NEXT J:NEXT I
    """) == " 11 12 21 22\n"


def test_gosub_return(basic):
    assert basic.run("""
        10 GOSUB 100:GOSUB 100:END
        100 PRINT "S";:RETURN
    """) == "SS\n"


def test_if_then_else(basic):
    assert basic.run("""
        10 FOR I=1 TO 3
        20 IF I=2 THEN PRINT "T"; ELSE PRINT "F";
        30 NEXT
    """) == "FTF\n"


def test_on_goto(basic):
    assert basic.run("""
        10 FOR I=1 TO 3:ON I GOTO 100,200,300
        100 PRINT "A";:GOTO 400
        200 PRINT "B";:GOTO 400
        300 PRINT "C";
        400 NEXT
    """) == "ABC\n"


def test_do_loop_until(basic):
    assert basic.run("""
        10 I=0
        20 DO:I=I+1:PRINT I;:LOOP UNTIL I=3
    """) == " 1 2 3\n"


def test_do_while_loop(basic):
    assert basic.run("""
        10 I=3
        20 DO WHILE I>0:PRINT I;:I=I-1:LOOP
    """) == " 3 2 1\n"


def test_def_fn(basic):
    assert basic.run("""
        10 DEF FNS(X)=X*X
        20 PRINT FNS(7)
    """) == " 49\n"


def test_inc_dec_swap(basic):
    assert basic.run("""
        10 A=1:B=9:INC A:DEC B:SWAP A,B
        20 PRINT A;B
    """) == " 8 2\n"


def test_list_round_trips_a_line(basic):
    basic.enter("10 PRINT 1+2")
    assert basic.eval("LIST") == "\n10 PRINT 1+2\n"
```

- [ ] **Step 4: `tests/basic/test_data.py`**

```python
def test_array(basic):
    assert basic.run("""
        10 DIM A(5)
        20 FOR I=0 TO 5:A(I)=I*2:NEXT
        30 PRINT A(0);A(5)
    """) == " 0 10\n"


def test_two_dimensional_array(basic):
    assert basic.run("""
        10 DIM A(2,2):A(1,2)=7:A(2,1)=9
        20 PRINT A(1,2);A(2,1);A(0,0)
    """) == " 7 9 0\n"


def test_string_array(basic):
    assert basic.run("""
        10 DIM A$(2):A$(0)="X":A$(2)="Z"
        20 PRINT A$(0);A$(1);A$(2)
    """) == "XZ\n"


def test_data_read_restore(basic):
    assert basic.run("""
        10 DATA 1,2,"THREE"
        20 READ A,B,C$:PRINT A;B;C$
        30 RESTORE:READ A:PRINT A
    """) == " 1 2THREE\n 1\n"


def test_poke_peek_and_doke_deek(basic):
    assert basic.run("""
        10 POKE $7000,171:DOKE $7002,4660
        20 PRINT PEEK($7000);DEEK($7002)
    """) == " 171 4660\n"
```

`$7000` is free RAM below the bank window with a cold-started BASIC reporting
39679 bytes free from `$0400`; confirm against `sim-minios.map` before relying
on it, and pick another address in free RAM if BASIC's memory reaches it.

- [ ] **Step 5: `tests/basic/test_errors.py`**

```python
import pytest

IMMEDIATE = [
    ("PRINT 1/0", "\nDivide by zero Error"),
    ("FOO BAR", "\nSyntax Error"),
    ("GOTO 999", "\nUndefined statement Error"),
    ('PRINT "A"+1', "\nType mismatch Error"),
    ("RETURN", "\nRETURN without GOSUB Error"),
    ("NEXT", "\nNEXT without FOR Error"),
    ("READ A", "\nOut of DATA Error"),
    ("PRINT SQR(-1)", "\nFunction call Error"),
    ("PRINT 1E38*1E38", "\nOverflow Error"),
]


@pytest.mark.parametrize("source,expected", IMMEDIATE,
                         ids=[c[0] for c in IMMEDIATE])
def test_immediate_error(basic, source, expected):
    assert basic.eval(source) == expected


def test_error_in_program_names_the_line(basic):
    assert basic.run("""
        10 PRINT "A"
        20 PRINT 1/0
    """) == "A\n\nDivide by zero Error in line 20"


def test_subscript_out_of_range(basic):
    assert basic.run("""
        10 DIM A(3)
        20 A(4)=1
    """) == "\nArray bounds Error in line 20"


def test_interpreter_recovers_after_an_error(basic):
    basic.eval("PRINT 1/0")
    assert basic.eval("PRINT 2+2") == " 4\n"
```

- [ ] **Step 6: Run, and resolve every failure from the source**

Run: `uv run pytest tests/basic -v`

Only the cases listed under "Facts established before planning" are known
outputs. For each other failure, find the behaviour in `minios/src/ehbasic.s`
(error strings are in the `LAB_BAER` table; number formatting in the
print-number routine) and correct whichever side is wrong. Report any case
where the interpreter is wrong to Jim rather than changing the expectation.
Replace `test_cstr_matches_its_documented_behaviour` with exact-output cases
taken from the comment block above `LAB_CSTRS`.

- [ ] **Step 7: Prove the table tests can fail.** Change one expected value in
  each module to a wrong one, run, see exactly those five fail, revert.

- [ ] **Step 8: Commit.**

---

### Task 8: Console tier — regressions and graphics escapes

**Files:**
- Create: `tests/basic/test_regressions.py`, `tests/basic/test_escapes.py`

**Interfaces:**
- Consumes: fixture `basic`; `BasicSession.eval`; `basic.emu.send`,
  `basic.emu.wait_for`

- [ ] **Step 1: `tests/basic/test_regressions.py`**

```python
PROMPT = b"\r\nReady\r\n"


def test_two_live_str_values_do_not_alias(basic):
    # 73df9e9: STR$ returned a pointer into the shared conversion buffer.
    assert basic.eval('A$=STR$(12345):B$=STR$(777):PRINT A$;"|";B$') \
        == " 12345| 777\n"


def test_str_inside_left_and_concatenation(basic):
    assert basic.eval('PRINT LEFT$(STR$(98765),3)+STR$(4)') == " 98 4\n"


def test_backspace_erases_the_character(basic):
    # d2d9636: backspace must echo BS, space, BS, and remove the character.
    emu = basic.emu
    emu.type_text("PRINT 12")
    emu.send(b"\x08")
    emu.expect_exact(b"\x08 \x08", 2.0)
    emu.type_text("3\r")
    assert emu.wait_for(PROMPT, 10) == b" 13\r\n" + PROMPT
```

- [ ] **Step 2: `tests/basic/test_escapes.py`**

```python
import pytest

ESC = "\x1b"

CASES = [
    ("PLOT 1,2,3,4,5", "[Z22;1;2;3;4;5Z"),
    ("RECT 10,20,30,40,5", "[Z23;10;20;30;40;5Z"),
    ("RECTF 10,20,30,40,5", "[Z24;10;20;30;40;5Z"),
    ("CIRCLE 100,90,25,7", "[Z25;100;90;25;7Z"),
    ("CIRCLEF 100,90,25,7", "[Z26;100;90;25;7Z"),
    ("RECT 0,0,639,479,15", "[Z23;0;0;639;479;15Z"),
    ("X=5:RECT X,X*2,X+1,40,X", "[Z23;5;10;6;40;5Z"),
]


@pytest.mark.parametrize("source,body", CASES, ids=[c[0] for c in CASES])
def test_graphics_statement_emits_exact_escape(basic, source, body):
    assert basic.eval(source) == ESC + body


def test_graphics_statement_in_a_program(basic):
    assert basic.run("""
        10 FOR I=1 TO 2
        20 RECT I,I,I,I,I
        30 NEXT
    """) == f"{ESC}[Z23;1;1;1;1;1Z{ESC}[Z23;2;2;2;2;2Z"


@pytest.mark.parametrize("source", ["RECT 1,2,3", "CIRCLE 1,2", "PLOT 1,2,3"])
def test_too_few_arguments_is_a_syntax_error(basic, source):
    assert basic.eval(source) == "\nSyntax Error"
```

- [ ] **Step 3: Run**

Run: `uv run pytest tests/basic/test_regressions.py tests/basic/test_escapes.py -v`
Resolve failures as in Task 7 Step 6 (the `RECT 10,20,30,40,5` case is a
captured fact and must pass as written).

- [ ] **Step 4: Prove the regression tests detect their bugs.** Build a ROM
  from the parent of each fix and run the matching test against it:

```bash
S=$(mktemp -d /tmp/jjrom.XXXX) && git worktree add "$S" 73df9e9~1
(cd "$S/Software/minios/src" && make sim)
```

Then temporarily point the `rom` fixture at
`$S/Software/minios/src/sim-minios.rom` (return that path instead of building)
and run `uv run pytest tests/basic/test_regressions.py -v`.
Expected: `test_two_live_str_values_do_not_alias` fails with ` 777` garbage in
`A$`. Repeat with `d2d9636~1` for the backspace test. Then
`git worktree remove --force "$S"`, revert the fixture, and confirm
`git status --short tests/` shows no stray change. If either test passes on
the pre-fix ROM, it is not testing the fix: say so, do not keep it as a
regression test.

- [ ] **Step 5: Commit.**

---

### Task 9: Headless sim serve mode and fixture

Settles spec open item 1.

**Files:**
- Modify: `pico-code/sim/sim_dump.c`, `pico-code/sim/build.sh`
- Create: `tests/bitmap.py`, `tests/sim/test_bitmap.py`, `tests/sim/conftest.py`,
  `tests/sim/test_link.py`

**Interfaces:**
- Consumes: `_booted`-style boot via `BasicSession`, `EmulatorSession(socket_path=)`
- Produces:
  - `./build.sh dump-build` — builds `_sim_dump`, does not run it
  - `_sim_dump serve <out.bmp>` — runs until SIGTERM; each SIGUSR1 rewrites
    `<out.bmp>` atomically
  - `bitmap.PALETTE: list[int]` (16 `0xRRGGBB` values)
  - `bitmap.Bitmap(data: bytes)`, `.width`, `.height`,
    `.pixel(x, y) -> int`, `.count(rgb) -> int`
  - `Sim.snapshot() -> Bitmap`
  - fixture `sim_basic -> tuple[Sim, BasicSession]`, and helper
    `eventually(check, timeout=5.0)` in `tests/sim/conftest.py`

- [ ] **Step 1: Bitmap tests first**, `tests/sim/test_bitmap.py`

```python
import struct

from bitmap import Bitmap


def _bmp(width, height, rows):
    pad = (4 - width * 3 % 4) % 4
    body = b""
    for row in reversed(rows):
        for rgb in row:
            body += bytes((rgb & 0xFF, rgb >> 8 & 0xFF, rgb >> 16 & 0xFF))
        body += b"\0" * pad
    head = b"BM" + struct.pack("<IHHI", 54 + len(body), 0, 0, 54)
    info = struct.pack("<IiiHHIIiiII", 40, width, height, 1, 24, 0,
                       len(body), 2835, 2835, 0, 0)
    return head + info + body


def test_pixel_addresses_top_left_origin_with_row_padding():
    b = Bitmap(_bmp(3, 2, [[0x110000, 0x002200, 0x000033],
                           [0xAABBCC, 0x000000, 0xFFFFFF]]))
    assert (b.width, b.height) == (3, 2)
    assert b.pixel(0, 0) == 0x110000
    assert b.pixel(2, 0) == 0x000033
    assert b.pixel(0, 1) == 0xAABBCC
    assert b.pixel(2, 1) == 0xFFFFFF


def test_count():
    b = Bitmap(_bmp(2, 2, [[1, 2], [1, 1]]))
    assert b.count(1) == 3 and b.count(2) == 1 and b.count(9) == 0
```

- [ ] **Step 2: Run; expect** `No module named 'bitmap'`.

- [ ] **Step 3: Write `tests/bitmap.py`**

```python
"""Reader for the 24-bit BMPs written by pico-code/sim/sim_dump.c."""

# Same order as palette[] in sim_dump.c.
PALETTE = [
    0x000000, 0xC00000, 0x00C000, 0xC0C000, 0x0000C0, 0xC000C0, 0x00C0C0, 0xC0C0C0,
    0x808080, 0xFF0000, 0x00FF00, 0xFFFF00, 0x0080FF, 0xFF00FF, 0x00FFFF, 0xFFFFFF,
]


class Bitmap:
    def __init__(self, data: bytes):
        assert data[:2] == b"BM", "not a BMP"
        self._data = data
        self._offset = int.from_bytes(data[10:14], "little")
        self.width = int.from_bytes(data[18:22], "little")
        self.height = int.from_bytes(data[22:26], "little")
        assert int.from_bytes(data[28:30], "little") == 24, "expected 24 bpp"
        self._stride = (self.width * 3 + 3) & ~3

    def pixel(self, x: int, y: int) -> int:
        i = self._offset + (self.height - 1 - y) * self._stride + x * 3
        b, g, r = self._data[i:i + 3]
        return r << 16 | g << 8 | b

    def count(self, rgb: int) -> int:
        return sum(self.pixel(x, y) == rgb
                   for y in range(self.height) for x in range(self.width))
```

- [ ] **Step 4: Run** `uv run pytest tests/sim/test_bitmap.py -v`; expect `2 passed`.

- [ ] **Step 5: Add serve mode to `pico-code/sim/sim_dump.c`.** Add
  `#include <signal.h>` and `#include <string.h>`, then above `main`:

```c
// Signals are blocked before the firmware thread exists so every thread
// inherits the mask and only sigwait() here ever sees them.
static int serve(const char *out) {
    sigset_t set;
    int sig;
    char tmp[1024];
    pthread_t th;

    sigemptyset(&set);
    sigaddset(&set, SIGUSR1);
    sigaddset(&set, SIGTERM);
    pthread_sigmask(SIG_BLOCK, &set, NULL);
    pthread_create(&th, NULL, demo_thread, NULL);
    snprintf(tmp, sizeof tmp, "%s.tmp", out);
    for (;;) {
        if (sigwait(&set, &sig) != 0 || sig == SIGTERM) return 0;
        write_bmp(tmp);
        if (rename(tmp, out) != 0) { perror("rename"); return 1; }
    }
}
```

and as the first statement of `main`:

```c
    if (argc > 2 && strcmp(argv[1], "serve") == 0) return serve(argv[2]);
```

- [ ] **Step 6: Add `dump-build` to `pico-code/sim/build.sh`.** Replace the
  `if [ "$1" = "dump" ]; then ... fi` block with:

```sh
if [ "$1" = "dump" ] || [ "$1" = "dump-build" ]; then
    echo "cc  _sim_dump  (headless)"
    $CC $CFLAGS sim_dump.c sim_platform.c "$SOURCE" "$SYNTH" "$LINK" -lpthread -o _sim_dump
    [ "$1" = "dump-build" ] && exit 0
    exec ./_sim_dump "${2:-2}" out.bmp
fi
```

and add to the usage comment at the top:
`#   ./build.sh dump-build # build the headless harness without running it`.

- [ ] **Step 7: Check it by hand** (this is open item 1)

```bash
cd pico-code/sim && SIM_SOURCE=console ./build.sh dump-build
D=$(mktemp -d /tmp/jjsim.XXXX)
SIM_SOCKET=$D/s ./_sim_dump serve $D/o.bmp & P=$!
sleep 1; ls -l $D/s; kill -USR1 $P; sleep 1; ls -l $D/o.bmp
kill -TERM $P; wait $P; echo "exit=$?"; ./build.sh dump 1 && ls -l out.bmp
```

Expected: the build has no new warnings; `$D/s` is a socket; `o.bmp` is
921654 bytes (54 + 640*480*3); `exit=0`; the old timed `dump` still writes
`out.bmp`. If the console firmware does not build or link as `_sim_dump`,
stop and report: the sim tier's premise is wrong.

Also confirm the firmware build is untouched:
`git diff --stat -- pico-code/pico_core` prints nothing.

- [ ] **Step 8: Write `tests/sim/conftest.py`**

```python
import os
import shutil
import signal
import subprocess
import tempfile
import time
from pathlib import Path

import pytest

from basic_session import BasicSession
from bitmap import Bitmap
from x65c02_session import EmulatorSession

SIM_DIR = Path(__file__).resolve().parents[2] / "pico-code" / "sim"


def eventually(check, timeout=5.0):
    deadline = time.monotonic() + timeout
    while True:
        try:
            return check()
        except AssertionError:
            if time.monotonic() >= deadline:
                raise
            time.sleep(0.1)


class Sim:
    def __init__(self, binary, directory):
        self.socket = directory / "s"
        self._bmp = directory / "o.bmp"
        self._proc = subprocess.Popen(
            [str(binary), "serve", str(self._bmp)],
            env=dict(os.environ, SIM_SOCKET=str(self.socket)),
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        deadline = time.monotonic() + 10
        while not self.socket.is_socket():
            if self._proc.poll() is not None:
                raise RuntimeError("sim exited before creating its socket")
            if time.monotonic() >= deadline:
                self.close()
                raise RuntimeError("sim socket did not appear within 10s")
            time.sleep(0.05)

    def snapshot(self) -> Bitmap:
        self._bmp.unlink(missing_ok=True)
        self._proc.send_signal(signal.SIGUSR1)
        deadline = time.monotonic() + 5
        while not self._bmp.exists():
            if self._proc.poll() is not None:
                raise RuntimeError("sim exited while dumping")
            if time.monotonic() >= deadline:
                raise RuntimeError("sim did not write a snapshot within 5s")
            time.sleep(0.02)
        return Bitmap(self._bmp.read_bytes())

    def close(self):
        if self._proc.poll() is None:
            self._proc.kill()
        self._proc.wait()


@pytest.fixture(scope="session")
def sim_bin():
    r = subprocess.run(["./build.sh", "dump-build"], cwd=SIM_DIR,
                       env=dict(os.environ, SIM_SOURCE="console"),
                       capture_output=True, text=True)
    if r.returncode != 0:
        pytest.fail(f"sim build failed:\n{r.stdout}{r.stderr}", pytrace=False)
    return SIM_DIR / "_sim_dump"


@pytest.fixture
def sim_basic(sim_bin, rom, emulator_bin, tmp_path):
    # sun_path is 104 bytes on macOS; pytest's tmp_path is longer than that.
    short = Path(tempfile.mkdtemp(prefix="jj", dir="/tmp"))
    sim = emu = None
    try:
        sim = Sim(sim_bin, short)
        emu = EmulatorSession(rom, tmp_path / "console.txt",
                              emulator=emulator_bin, socket_path=sim.socket)
        basic = BasicSession(emu)
        basic.boot()
        yield sim, basic
    finally:
        if emu is not None:
            emu.close()
        if sim is not None:
            sim.close()
        shutil.rmtree(short, ignore_errors=True)
```

The sim is SIGKILLed rather than sent SIGTERM so teardown cannot hang on a
sim that has stopped servicing signals.

- [ ] **Step 9: Write `tests/sim/test_link.py`**

```python
import subprocess

import pytest

pytestmark = pytest.mark.sim


def test_emulator_and_sim_connect_and_snapshot(sim_basic):
    sim, basic = sim_basic
    assert basic.eval("PRINT 1/3") == " .333333\n"
    bmp = sim.snapshot()
    assert (bmp.width, bmp.height) == (640, 480)


def test_socket_path_is_short_and_private(sim_basic):
    sim, _ = sim_basic
    assert len(str(sim.socket)) < 100
    assert str(sim.socket) != "/tmp/jj65c02.sock"


def test_nothing_survives_teardown():
    assert subprocess.run(["pgrep", "-f", "_sim_dump serve"],
                          capture_output=True).returncode == 1
```

The third test takes no fixtures on purpose: it observes the state the two
tests above left behind, so it must stay last in the file.

- [ ] **Step 10: Run**

Run: `uv run pytest tests/sim -v` then `uv run pytest -m "not sim" -q`
Expected: sim tests pass; the second run deselects `test_link.py` and never
invokes `build.sh` (check with `-m "not sim" --setup-show | grep -c sim_bin`
printing `0`).

- [ ] **Step 11: Commit** the two sim files separately from the tests.

---

### Task 10: Sim smoke tests

**Files:**
- Create: `tests/sim/test_smoke.py`

**Interfaces:**
- Consumes: `sim_basic`, `eventually`, `Sim.snapshot`, `Bitmap.pixel`,
  `Bitmap.count`, `PALETTE`

Assertions compare against a baseline snapshot taken in the same test, so
they do not assume the background colour or the text cell size. `eventually`
re-snapshots because the sim renders asynchronously to the console log.

- [ ] **Step 1: Write `tests/sim/test_smoke.py`**

```python
import pytest

from bitmap import PALETTE
from conftest import eventually  # tests/sim/conftest.py

pytestmark = pytest.mark.sim


def test_rectf_fills_its_area_and_nothing_outside(sim_basic):
    sim, basic = sim_basic
    before = sim.snapshot()
    assert before.pixel(325, 225) != PALETTE[10]
    basic.eval("RECTF 300,200,50,50,10")

    def check():
        now = sim.snapshot()
        assert now.pixel(325, 225) == PALETTE[10]
        assert now.pixel(301, 201) == PALETTE[10]
        assert now.pixel(290, 225) == before.pixel(290, 225)
        assert now.pixel(360, 225) == before.pixel(360, 225)
    eventually(check)


def test_rect_draws_an_outline_only(sim_basic):
    sim, basic = sim_basic
    before = sim.snapshot()
    basic.eval("RECT 300,200,50,50,9")

    def check():
        now = sim.snapshot()
        assert now.pixel(300, 225) == PALETTE[9]
        assert now.pixel(325, 200) == PALETTE[9]
        assert now.pixel(325, 225) == before.pixel(325, 225)
    eventually(check)


def test_plot_draws_a_line(sim_basic):
    sim, basic = sim_basic
    basic.eval("PLOT 300,300,340,300,12")

    def check():
        now = sim.snapshot()
        assert now.pixel(320, 300) == PALETTE[12]
        assert now.pixel(320, 310) != PALETTE[12]
    eventually(check)


def test_text_colour_change_applies_to_printed_text(sim_basic):
    sim, basic = sim_basic
    assert sim.snapshot().count(PALETTE[13]) == 0
    basic.eval('PRINT CHR$(27);"[Z2;13Z";"HELLO"')
    eventually(lambda: _assert_positive(sim.snapshot().count(PALETTE[13])))


def test_clear_screen_removes_drawing(sim_basic):
    sim, basic = sim_basic
    basic.eval("RECTF 300,200,50,50,10")
    eventually(lambda: _assert_equal(sim.snapshot().pixel(325, 225), PALETTE[10]))
    basic.eval('PRINT CHR$(27);"[2J";')
    eventually(lambda: _assert_not_equal(sim.snapshot().pixel(325, 225),
                                         PALETTE[10]))


def _assert_positive(n):
    assert n > 0


def _assert_equal(a, b):
    assert a == b


def _assert_not_equal(a, b):
    assert a != b
```

`from conftest import eventually` resolves to `tests/sim/conftest.py` under
pytest's rootdir-relative import; if it resolves to `tests/conftest.py`
instead, move `eventually` into `tests/bitmap.py` and import it from there.

- [ ] **Step 2: Run**

Run: `uv run pytest tests/sim/test_smoke.py -v`

Unverified assumptions these tests make, to check on the first failure rather
than by loosening the assertion:
- the rectangle at (300,200) is clear of console text at boot;
- `ESC[2J` (`case 'J'` in `escape_seq.c`) clears graphics as well as text
  cells — if it only erases text cells, clear is not a graphics operation and
  the test should assert on text pixels instead;
- colour 13 does not appear on a freshly booted screen.

- [ ] **Step 3: Prove the pixel checks can fail.** Change `RECTF` to colour 11
  in the first test without changing the assertion; expect a failure after the
  5 s `eventually` window; revert.

- [ ] **Step 4: Run everything twice**

Run: `uv run pytest -q && uv run pytest -q`
Expected: identical pass counts; `pgrep -f "x65c02|_sim_dump"` prints nothing;
`ls /tmp | grep -c '^jj'` prints `0`.

- [ ] **Step 5: Commit.**

---

### Task 11: Documentation

**Files:**
- Create: `tests/README.md`
- Modify: `Harness/README.md`, `AGENTS.md`, `tests/PHASE1_DESIGN.md`

- [ ] **Step 1: `tests/README.md`** — how to run (`uv run pytest`,
  `-m "not sim"`, `-k`, `X65C02=...` for a baseline emulator), what each tier
  asserts on, how to add a case to a table, and the three rules: upper-case
  BASIC, expectations come from the source not from observed output, sim tests
  compare against a baseline snapshot. State the measured boot and suite times
  from Task 4 and Task 10, not estimates.

- [ ] **Step 2: `Harness/README.md`** — add a section for
  `x65c02_session.py` (the class, `wait_for`, `type_text`, the exceptions),
  and replace the advice that `--char-delay 0.2` is reliable with the measured
  finding from Task 4.

- [ ] **Step 3: `AGENTS.md`** — add `tests/` to the layout table and one
  bullet under "Emulator and harness": pytest suite via `uv run pytest`; new
  scripted checks go there, built on `EmulatorSession`.

- [ ] **Step 4: `tests/PHASE1_DESIGN.md`** — replace "Open items" with what
  was measured.

- [ ] **Step 5: Verify every command in the new docs by running it**, then
  commit.

---

## Spec coverage

| Spec section | Task |
| --- | --- |
| uv project, pytest | 1 |
| EmulatorSession, exceptions | 2, 3 |
| CLI rebuilt on the module | 6 |
| BasicSession, `basic`/`fresh_basic` | 5 |
| `rom`, `emulator_bin` | 4 |
| Console tier modules | 7, 8 |
| Sim serve mode, private socket, `sim` marker | 9 |
| Sim smoke tests | 10 |
| Error handling | 2, 3, 5, 9 |
| Open items 1, 2, 3 | 9, 4, 4 |
