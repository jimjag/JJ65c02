# miniOS Test Suite (Phase 2a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `uv run --no-env-file pytest` also boots `sim-minios.rom` and verifies the miniOS menu, Wozmon, MilliForth and Supermon+, so a ROM change that breaks any of them fails a test.

**Architecture:** One new module, `tests/minios_session.py`, holds a `MenuSession` plus one small session class per program. It reuses the Phase 1 `EmulatorSession` and gains one option on `type_text` for programs whose echo differs from EhBASIC's. Tests live in `tests/minios/`, one module per program, with module-scoped fixtures that enter the program before each test and leave it after. Coverage guards, modelled on `tests/basic/test_keyword_coverage.py`, fail when a Supermon command or MilliForth word has no test.

**Tech Stack:** Python >= 3.11, pytest, uv. No ROM, emulator or sim changes.

**Spec:** `Software/tests/PHASE2A_DESIGN.md`. Read it first. Phase 1 is `tests/PHASE1_DESIGN.md`, `tests/README.md`.

## Global Constraints

- All paths are relative to `Software/`; run every command from there.
- Test only `minios/src/sim-minios.rom`, never `minios.rom`.
- Run pytest as `uv run --no-env-file pytest ...` (the shell exports `UV_ENV_FILE`). If `ca65` cannot open `generic.mac`: `export CA65_INC=/Users/jim/src/6502/cc65/asminc`.
- Program output is read from the `-o` console log only, never the pty.
- Type upper-case only. Exception: tests that exist to prove a program upper-cases its input.
- Never send ESC (`\x1b`): the emulator's `handle_io()` treats it as a GUI key and never delivers it to the 6502.
- Nothing under `minios/`, `Emulator/` or `pico-code/` changes. Tests only, plus the driver option in Task 2.
- Do not run the full suite in the foreground (about 10 minutes before Phase 2a); background it.
- Comments: none by default; one line for a non-obvious why.
- Commits: draft the message to a file, `bbedit --wait --resume <file>`, then `git commit -F <file>`. Subject line only unless the why cannot be recovered from the diff (2-3 lines max). No AI or assistant attribution anywhere. `rm`/`cp`/`mv` are interactive aliases: use `/bin/rm` etc.
- Address Jim by name in every message; pause after each task and ask whether to continue.

## Facts established before planning

Read from the ROM sources and the built `sim-minios.lbl`/`.map`, **not yet run**. Task 1 confirms every one against the real ROM; where a plan expectation disagrees with a real run, decide from the source whether the test or the ROM is wrong. Do not paste the observed value in as the expectation.

**Console path (all four programs):** `CON_write_byte` writes bytes raw to `$A800` (no CR expansion). Menu keys are **not echoed**. Menu prompt is `OK> `; menu text is `"\r\n" + items + "\r\n" + "OK> "`, items end with `A. About`. An invalid key (and lower-case `a`) redraws the menu.

| Program | Enter | Banner (ends at) | Typed CR echoes as | Idle marker |
| --- | --- | --- | --- | --- |
| Wozmon | `6` | `"\r\nWelcome to EWOZMON 1.0.\r\n]"` | `\r\n` | send BS: expect `\x08\r\n` |
| MilliForth | `8` | `"\r\nMilliForth for JJ6502\r\nok> "` | `\r` only | count `"\r\nok> "` prompts |
| Supermon+ | `9` | `"\r\n\r\nSUPERMON+ @ $E786 \r\n\r\n   PC  SR AC XR YR SP   V1.2+\r\n; 0000 00 00 00 00 00 \r\n"` (address varies per build) | `\r` only | send BS: expect `\x08` |

- **Wozmon:** no prompt after a line. Input is upper-cased before the echo, so `a` echoes `A`. `Q` anywhere quits (echoes `Q`, returns to the menu). `R` is `jmp`, so a stored routine ending in `RTS` lands in the **menu**. Examine `0500` + CR prints `"\r\n0500: XX\r\n"` after the echo; store `0500: A9 41` prints the *old* byte the same way; block `0500.0505` prints `"\r\n0500: b0 b1 ... b5\r\n"` (new `"\r\nADDR:"` every 16 bytes).
- **MilliForth:** prints `"\r\nok> "` after **every word executed** in interpret mode, not once per line. `:` and `;` execute (one prompt each); words between them print nothing; the name after `:` is consumed by `:`. Unknown word: silent abort, stacks cleared, rest of the line dropped, one prompt. Lower-case only (`BYE` is unknown). No numeric literals; `s@` pushes `$0022`. `.` prints `" "` + 4 hex digits and does not drop. `.S` empty is `"S0498 00 "`; `.R` is `"R04E0 00 "`. `tty` is a no-op on the SIM build. User dictionary starts at `$0600`; re-entering from the menu resets it.
- **Supermon+:** line-buffered, 38 chars max, lower-case echoes as typed and is upper-cased only in the buffer. Backspace echoes `\x08`, clamps at an empty buffer. Command prompt is just `"\r\n"`. Unknown command `Z`: `"Z\r?\r\n\r\n"` in the log. Avoid `=` and `U` as "unknown" probes (they match vector bytes). `X` leaves. Registers are not reset on re-entry. `G` and `J` use the stored SP and SR: set them with `;` first. `M` lines: `"\r\n>AAAA " + 16 bytes + ":" + 16 ASCII` (`.` for `<$20` and `>=$7E`). `D` lines: `". AAAA  " + 3 byte slots of "hh " or 3 spaces + mnemonic (3 letters + 2 spaces, or 4 + 1) + operand`. Assemble `A 0500 LDA #$41` prints `"0500  A9 41    LDA  #$41"` then `"A 0502 "` pre-filled; a bare CR on the pre-filled line leaves. Bad mnemonic prints `?` and leaves assemble mode. Conversions: `$41` prints `"\r\n $0041 \r\n +65\r\n &101\r\n %1000001\r\n"`.
- Safe RAM for test code is `$0500-$7FFF` (`$0400` is Forth's input buffer and the menu's `$0400` program slot; use it only where a task says so).

## Review Focus

1. A program that never returns to its idle marker (hangs): the wait times out, the session is marked broken and replaced before the next test. (Task 3)
2. A lost or mismatched echo in a program whose echo differs from EhBASIC's: fails naming the character, never silently runs a corrupted line. (Tasks 2, 3)
3. State leaking between tests: Forth words defined in one test must not exist in the next; Supermon register edits must not change another test's expectation. (Tasks 6, 7)
4. A coverage guard whose parser silently returns nothing, so every entry "passes". (Tasks 6, 7)
5. A test that passes vacuously because its sync marker matched earlier output (e.g. a stale `\x08` or prompt). (Task 3)

---

### Task 0: Save the plan

**Files:** Create `tests/PHASE2A_PLAN.md` (copy of this plan).

- [ ] **Step 1:** `/bin/cp /Users/jim/.claude/plans/snazzy-hugging-bumblebee.md tests/PHASE2A_PLAN.md`
- [ ] **Step 2:** Commit with subject `Add the Phase 2a implementation plan`. (Draft in bbedit first.)

---

### Task 1: Measure the facts

Settles every "not yet run" fact above and the design's open items before any test is written.

**Files:**
- Modify: `tests/PHASE2A_DESIGN.md` (replace "Open items" with "Measured results"; add a "Measured transcripts" table)
- Throwaway script in the scratchpad directory, not committed.

- [ ] **Step 1: Build and write the probe script** (`$SCRATCH/probe.py`; run with `python3 -I`? no: needs `Harness` on the path, so use `PYTHONPATH=Harness python3`):

```python
import sys, time
from x65c02_session import EmulatorSession, EmulatorError

ROM = "minios/src/sim-minios.rom"
EMU = "Emulator/x65c02"
OUT = sys.argv[1]


def start(name):
    emu = EmulatorSession(ROM, f"{OUT}/{name}.txt", emulator=EMU)
    emu.wait_for(b"OK> ", 60)
    return emu


def key(emu, k, pattern, timeout=10):
    emu.send(k)
    return emu.wait_for(pattern, timeout)


def typed(emu, text, echo_for=None):
    """type_text with a pluggable echo; Task 2 moves this into the driver."""
    t0 = time.monotonic()
    for ch in text:
        emu.send(ch.encode("ascii"))
        emu.expect_exact(echo_for(ch) if echo_for
                         else (b"\r\n" if ch == "\r" else ch.encode("ascii")), 5.0)
    return time.monotonic() - t0


def idle(emu, marker, timeout=15):
    emu.send(b"\x08")
    return emu.wait_for(marker, timeout)


def show(label, data):
    print(f"{label:28} {data!r}")


# menu
e = start("menu")
show("invalid key Z", key(e, b"Z", b"OK> "))
show("lower a", key(e, b"a", b"OK> "))
show("A", key(e, b"A", b"OK> ")[:60])
e.close()

# wozmon: echo with default rules, BS marker, store/examine/block/run
e = start("woz")
show("woz banner", key(e, b"6", b"]"))
for line in ["0500: A9 41 8D 00 A8 60", "0500", "0500.0505"]:
    secs = typed(e, line + "\r")
    show(f"woz {line!r} ({secs:.1f}s)", idle(e, b"\x08\r\n"))
for ch in "0500: ab\r":                         # lower-case folding
    e.send(ch.encode())
    show(f"woz send {ch!r}", e.wait_for(ch.upper().encode() if ch != "\r" else b"\r\n"))
show("woz idle", idle(e, b"\x08\r\n"))
typed(e, "0500R\r")
show("woz run", e.wait_for(b"OK> ", 15)[:80])
e.close()

# forth: CR echo, prompt per word, unknown word, reset on re-entry
e = start("forth")
show("forth banner", key(e, b"8", b"ok> "))
cr = lambda c: b"\r" if c == "\r" else c.encode()
for line, prompts in [("s@ .", 2), (".S", 1), ("s@ s@ .S", 3), (": foo s@ ;", 2),
                      ("foo .", 2), ("s@ nonesuch", 2), (".S", 1), ("tty", 1),
                      (".R", 1), ("s@ emit", 2), ("s@ @ .", 3),
                      ("s@ s@ + s@ s@ + !", 6), ("s@ s@ + @ .", 5)]:
    secs = typed(e, line + "\r", echo_for=cr)
    outs = [e.wait_for(b"\r\nok> ", 10) for _ in range(prompts)]
    show(f"forth {line!r} ({secs:.1f}s)", outs)
typed(e, "bye\r", echo_for=cr)
show("forth bye", e.wait_for(b"OK> ")[-12:])
show("forth re-enter", key(e, b"8", b"ok> "))
typed(e, "foo\r", echo_for=cr)
show("forth foo after reentry", e.wait_for(b"\r\nok> "))
typed(e, ".S\r", echo_for=cr)
show("forth .S after reentry", e.wait_for(b"\r\nok> "))
e.close()

# supermon: banner, BS marker, each command shape
e = start("super")
banner = key(e, b"9", b"V1.2+")
show("super banner", banner + idle(e, b"\x08"))
for line in ["R", "; 0500 00 11 22 33 FF", "R", ">0500 A9 41 8D 00 A8 60", "M0500 050F",
             "D0500 0505", "F0600 060F AA", "M0600 060F", "T0600 060F 0700",
             "C0600 060F 0700", "H0500 050F 41", "$41", "%0", "Z"]:
    cr1 = lambda c: b"\r" if c == "\r" else c.encode()
    secs = typed(e, line + "\r", echo_for=cr1)
    show(f"super {line!r} ({secs:.1f}s)", idle(e, b"\x08"))
typed(e, "A 0500 LDA #$41\r", echo_for=cr1)
show("super asm 1", e.wait_for(b"A 0502 "))
typed(e, "RMB5 $12\r", echo_for=cr1)
show("super asm 2", e.wait_for(b"A 0504 "))
typed(e, "\r", echo_for=cr1)
show("super asm exit", idle(e, b"\x08"))
typed(e, "A 0500 XYZ\r", echo_for=cr1)
show("super asm bad", idle(e, b"\x08"))
typed(e, "X\r", echo_for=cr1)
show("super X", e.wait_for(b"OK> ")[-12:])
e.close()
```

- [ ] **Step 2: Run it:** `mkdir -p $SCRATCH/out && PYTHONPATH=Harness python3 $SCRATCH/probe.py $SCRATCH/out 2>&1 | tee $SCRATCH/probe.log`. The script is self-contained (its `typed` helper stands in for the Task 2 option).
- [ ] **Step 3: Compare every line with "Facts established before planning" and record in `PHASE2A_DESIGN.md`:**
  - Open item 1 (echo): which programs need `echo_for`, and that Wozmon upper-case folding echoes upper.
  - Open item 2 (speed): seconds per typed line for each program; derive the suite estimate.
  - Open item 3 (reset): output of `foo` after re-entry (expected: unknown word, `.S` empty).
  - Open item 4 (exit): `Q`, `bye`, `X` each reach `OK> `.
  - **Gate:** the BS idle markers (`\x08\r\n` for Wozmon, `\x08` for Supermon) must each appear exactly once per probe and not earlier. If a marker does not work, stop and change the design: pick another harmless key whose echo is unique, and update Task 3's constants.
  - Forth scratch cell `$0044`: `grep -n "^al 0000[2-4]" minios/src/sim-minios.lbl` and the Forth zero-page equates in `milliforth.s` to confirm nothing Forth uses lives at `$44-$45`. If it does, pick another cell and update Task 6.
  - Record any plan expectation that disagrees with the transcript, with your decision (test wrong, reading wrong, or ROM defect to raise with Jim).
- [ ] **Step 4:** Commit `tests/PHASE2A_DESIGN.md` with subject `Record the measured Phase 2a probe results`.

---

### Task 2: `type_text` echo option

**Files:**
- Modify: `Harness/x65c02_session.py` (`type_text`, ~line 137)
- Modify: `tests/harness/fake_emu.py` (two new modes)
- Test: `tests/harness/test_session.py`

**Interfaces:**
- Produces: `EmulatorSession.type_text(text, echo_timeout=5.0, retries=0, echo_for=None)`; `echo_for` is `Callable[[str], bytes]` returning the bytes expected for one typed character. Default behaviour is unchanged.

- [ ] **Step 1: Write the failing tests** (append to `tests/harness/test_session.py`):

```python
def test_cr_only_echo_is_a_mismatch_by_default(tmp_path, monkeypatch):
    monkeypatch.setenv("FAKE_EMU_MODE", "cr-only")
    with EmulatorSession("unused.rom", tmp_path / "c.txt", emulator=FAKE) as s:
        s.wait_for(b"BOOT\r\n", 5)
        with pytest.raises(EchoMismatch):
            s.type_text("A\r")


def test_echo_for_accepts_a_bare_cr(tmp_path, monkeypatch):
    monkeypatch.setenv("FAKE_EMU_MODE", "cr-only")
    with EmulatorSession("unused.rom", tmp_path / "c.txt", emulator=FAKE) as s:
        s.wait_for(b"BOOT\r\n", 5)
        s.type_text("A\r", echo_for=lambda c: c.encode())


def test_echo_for_accepts_an_upper_cased_echo(tmp_path, monkeypatch):
    monkeypatch.setenv("FAKE_EMU_MODE", "upper")
    with EmulatorSession("unused.rom", tmp_path / "c.txt", emulator=FAKE) as s:
        s.wait_for(b"BOOT\r\n", 5)
        s.type_text("ab", echo_for=lambda c: c.upper().encode())
```

- [ ] **Step 2:** `uv run --no-env-file pytest -q tests/harness -k "cr_only or echo_for"` → FAIL (`type_text() got an unexpected keyword argument` / unknown mode).
- [ ] **Step 3: Implement.** In `fake_emu.py` change the echo line to:

```python
    echo = b if mode == "cr-only" else (b"\r\n" if b == b"\r" else b)
    if mode == "upper":
        echo = echo.upper()
```
and in `x65c02_session.py`:

```python
    def type_text(self, text: str, echo_timeout: float = 5.0,
                  retries: int = 0, echo_for=None) -> None:
        for ch in text:
            if echo_for is not None:
                echo = echo_for(ch)
            else:
                echo = b"\r\n" if ch == "\r" else ch.encode("ascii")
```
(rest of the loop unchanged.)
- [ ] **Step 4:** `uv run --no-env-file pytest -q tests/harness` → all pass (existing 13 plus 3).
- [ ] **Step 5:** Commit `Add an echo_for option to type_text`.

---

### Task 3: Sessions and fixtures

**Files:**
- Create: `tests/minios_session.py`, `tests/minios/conftest.py`, `tests/minios/__init__.py` (empty, only if `tests/basic` has one: `ls tests/basic/__init__.py`; do not add if it does not)
- Test: `tests/harness/test_minios_session.py` (no emulator: `prompts_for`)

**Interfaces:**
- Produces (`tests/minios_session.py`):
  - `MENU = b"OK> "`
  - `MenuSession(emu)`: `.emu`, `.broken`, `.boot_output: str`, `.boot()`, `.press(key: bytes, pattern: bytes, timeout=10.0, tries=3) -> bytes`
  - `WozmonSession(menu)`, `ForthSession(menu)`, `SupermonSession(menu)`, each with `.enter() -> str` (banner text, also `.banner`), `.leave() -> str`, `.left: bool`, and:
    - Wozmon / Supermon: `.line(text, timeout=10.0, **type_kw) -> str` (output after the echo, idle marker removed)
    - Forth: `.eval(line, prompts=None, timeout=10.0) -> str`
    - Supermon: `.assemble(start, steps, cmd="A") -> str` where `steps = [(instruction, next_address), ...]`
  - `prompts_for(line: str) -> int`
- Produces (`tests/minios/conftest.py`): fixtures `menu`, `wozmon`, `forth`, `supermon`.

- [ ] **Step 1: Write the failing test** `tests/harness/test_minios_session.py`:

```python
import pytest

from minios_session import prompts_for


@pytest.mark.parametrize("line,expected", [
    ("s@ .", 2),
    (".S", 1),
    ("s@ s@ + .", 4),
    (": foo s@ ;", 2),
    (": foo s@ s@ + ;", 2),
    ("foo", 1),
    (": a s@ ; : b a ; b .", 5),
    ("", 0),
])
def test_prompts_for(line, expected):
    assert prompts_for(line) == expected
```
- [ ] **Step 2:** `uv run --no-env-file pytest -q tests/harness/test_minios_session.py` → FAIL (`ModuleNotFoundError: minios_session`).
- [ ] **Step 3: Write `tests/minios_session.py`:**

```python
"""miniOS menu and the monitors reachable from it, on top of an EmulatorSession."""
from x65c02_session import EmulatorError, EmulatorTimeout

MENU = b"OK> "
BS = b"\x08"


def _text(data: bytes) -> str:
    return data.decode("latin-1")


def _default_echo(ch: str) -> bytes:
    return b"\r\n" if ch == "\r" else ch.encode("ascii")


def _cr_only_echo(ch: str) -> bytes:
    return ch.encode("ascii")


def prompts_for(line: str) -> int:
    """MilliForth prints a prompt after every executed word, not every line."""
    count, compiling, skip = 0, False, False
    for tok in line.split():
        if skip:
            skip = False
        elif tok == ":":
            count += 1
            compiling, skip = True, True
        elif tok == ";":
            count += 1
            compiling = False
        elif not compiling:
            count += 1
    return count


class MenuSession:
    def __init__(self, emu):
        self.emu = emu
        self.broken = False
        self.boot_output = ""

    def boot(self) -> None:
        self.boot_output = _text(self.emu.wait_for(MENU, 60)).replace("\r\n", "\n")

    def press(self, key: bytes, pattern: bytes, timeout=10.0, tries=3) -> bytes:
        """Menu keys are not echoed, so a lost key shows only as a missing reply."""
        for attempt in range(tries):
            self.emu.send(key)
            try:
                return self.emu.wait_for(pattern, timeout)
            except EmulatorTimeout:
                if attempt == tries - 1:
                    self.broken = True
                    raise
            except EmulatorError:
                self.broken = True
                raise


class _Program:
    key = b""
    banner_pattern = b""
    echo_for = staticmethod(_default_echo)

    def __init__(self, menu):
        self.menu = menu
        self.emu = menu.emu
        self.banner = ""
        self.left = False

    def _guard(self, fn, *args, **kw):
        try:
            return fn(*args, **kw)
        except EmulatorError:
            self.menu.broken = True
            raise

    def _type(self, text, **kw):
        self._guard(self.emu.type_text, text, echo_for=self.echo_for, **kw)

    def _wait(self, pattern, timeout=10.0):
        return self._guard(self.emu.wait_for, pattern, timeout)

    def _finish_enter(self, out: bytes) -> str:
        self.banner = _text(out)
        return self.banner

    def enter(self) -> str:
        return self._finish_enter(
            self.menu.press(self.key, self.banner_pattern))

    def _leave_with(self, text: str) -> str:
        self._type(text)
        out = _text(self._wait(MENU, 15.0))
        self.left = True
        return out


class WozmonSession(_Program):
    key = b"6"
    banner_pattern = b"EWOZMON 1.0.\r\n]"
    SYNC = BS + b"\r\n"

    def line(self, text, timeout=10.0, **type_kw) -> str:
        self._type(text + "\r", **type_kw)
        self.emu.send(BS)
        out = self._wait(self.SYNC, timeout)
        return _text(out[:-len(self.SYNC)])

    def leave(self) -> str:
        return self._leave_with("Q")


class ForthSession(_Program):
    key = b"8"
    banner_pattern = b"MilliForth for JJ6502\r\nok> "
    echo_for = staticmethod(_cr_only_echo)
    PROMPT = b"\r\nok> "

    def eval(self, line, prompts=None, timeout=10.0) -> str:
        n = prompts_for(line) if prompts is None else prompts
        self._type(line + "\r")
        pieces = [self._wait(self.PROMPT, timeout)[:-len(self.PROMPT)]
                  for _ in range(n)]
        return _text(b"".join(pieces))

    def leave(self) -> str:
        return self._leave_with("bye\r")


class SupermonSession(_Program):
    key = b"9"
    banner_pattern = b"V1.2+"
    echo_for = staticmethod(_cr_only_echo)

    def _sync(self, timeout=10.0) -> str:
        self.emu.send(BS)
        out = self._wait(BS, timeout)
        return _text(out[:-1])

    def enter(self) -> str:
        head = self.menu.press(self.key, self.banner_pattern)
        return self._finish_enter(head + self._sync().encode("latin-1"))

    def line(self, text, timeout=10.0) -> str:
        self._type(text + "\r")
        return self._sync(timeout)

    def assemble(self, start, steps, cmd="A") -> str:
        """Each step is (instruction, address of the next pre-filled prompt)."""
        self._type(f"{cmd} {start} {steps[0][0]}\r")
        out = []
        for i, (_, nxt) in enumerate(steps):
            out.append(_text(self._wait(f"A {nxt} ".encode())))
            if i + 1 < len(steps):
                self._type(steps[i + 1][0] + "\r")
        self._type("\r")
        out.append(self._sync())
        return "".join(out)

    def leave(self) -> str:
        return self._leave_with("X\r")
```

(`_Program.enter` for Wozmon and Forth: the pattern ends at the last banner byte, so nothing is left unread. Supermon leaves `0000 00 00 00 00 00 \r\n` after `V1.2+\r\n; `, which `_sync` consumes.)

- [ ] **Step 4:** `uv run --no-env-file pytest -q tests/harness/test_minios_session.py` → 8 passed.
- [ ] **Step 5: Write `tests/minios/conftest.py`:**

```python
import pytest

from minios_session import (ForthSession, MenuSession, SupermonSession,
                            WozmonSession)
from x65c02_session import EmulatorError, EmulatorSession


def _booted(rom, emulator_bin, directory):
    emu = EmulatorSession(rom, directory / "console.txt", emulator=emulator_bin)
    try:
        m = MenuSession(emu)
        m.boot()
    except BaseException:
        emu.close()
        raise
    return m


@pytest.fixture(scope="module")
def _menu_holder(rom, emulator_bin, tmp_path_factory):
    holder = {}

    def get():
        m = holder.get("m")
        if m is None or m.broken or not m.emu.alive:
            if m is not None:
                m.emu.close()
            holder["m"] = m = _booted(rom, emulator_bin,
                                      tmp_path_factory.mktemp("menu"))
        return m

    yield get
    if "m" in holder:
        holder["m"].emu.close()


@pytest.fixture
def menu(_menu_holder):
    return _menu_holder()


def _program(cls):
    @pytest.fixture
    def fixture(menu):
        p = cls(menu)
        p.enter()
        yield p
        if not p.left and not menu.broken and menu.emu.alive:
            try:
                p.leave()
            except EmulatorError:
                pass
    return fixture


wozmon = _program(WozmonSession)
forth = _program(ForthSession)
supermon = _program(SupermonSession)
```
- [ ] **Step 6: Write a smoke test that proves the fixtures work and a hung program is discarded** (`tests/minios/test_sessions.py`):

```python
import pytest

from x65c02_session import EmulatorTimeout


def test_menu_boots(menu):
    assert menu.boot_output.endswith("OK> ")
    assert "1. Load RAM Image (via XMODEM) to @0400" in menu.boot_output


def test_wozmon_enters_and_leaves(wozmon):
    assert wozmon.banner == "\r\nWelcome to EWOZMON 1.0.\r\n]"


def test_a_hung_program_marks_the_session_broken(menu, wozmon):
    assert not menu.broken
    with pytest.raises(EmulatorTimeout):
        wozmon.line("0500", timeout=0.01)
    assert menu.broken


def test_next_test_gets_a_replaced_session(menu, wozmon):
    assert menu.emu.alive and not menu.broken
    assert wozmon.line("0500") == "\r\n0500: 00\r\n"
```
`test_a_hung_program...` relies on the answer taking longer than 10 ms, so the wait for the sync marker times out. Run `uv run --no-env-file pytest -q tests/minios/test_sessions.py -v` (about 20 s): 4 pass, and the last test runs on a freshly booted session (it is the first to use the session the holder replaced). Test order matters here by design, as in `tests/basic/test_session_basics.py`.
- [ ] **Step 7:** Commit `Add the miniOS session classes and fixtures`.

---

### Task 4: Menu tests

**Files:** Create `tests/minios/test_menu.py`, `tests/minios/golden/menu.txt`, `tests/minios/golden/ram_test.txt` (written by `--update-golden`).

- [ ] **Step 1: Write the tests:**

```python
from pathlib import Path

import pytest

from minios_session import MENU, WozmonSession

GOLDEN = Path(__file__).parent / "golden"


def test_menu_text_is_unchanged(menu, golden):
    golden(GOLDEN / "menu.txt", menu.boot_output)


@pytest.mark.parametrize("key", [b"Z", b"a", b"0"])
def test_invalid_key_redraws_the_menu(menu, key):
    out = menu.press(key, MENU).decode("latin-1").replace("\r\n", "\n")
    assert out.startswith("\n1. Load RAM Image")
    assert menu.boot_output.endswith(out)


def test_about_prints_the_project_url_then_the_menu(menu):
    out = menu.press(b"A", MENU).decode("latin-1")
    assert out.startswith("\r\nhttps://github.com/jimjag/JJ6502\r\n1. Load RAM")


def test_clear_ram_reports_and_returns(menu):
    out = menu.press(b"4", MENU, timeout=30).decode("latin-1")
    assert out.startswith("\r\n Cleaning RAM... ")
    assert out.endswith("A. About\r\nOK> ")


def test_ram_test_runs_every_bank(menu, golden):
    out = menu.press(b"5", MENU, timeout=60).decode("latin-1")
    assert out.count(" Testing RAM... ") == 8
    golden(GOLDEN / "ram_test.txt", out.replace("\r\n", "\n"))


def test_run_program_executes_ram_at_0400(menu):
    w = WozmonSession(menu)
    w.enter()
    w.line("0400: 60")
    w.leave()
    out = menu.press(b"3", MENU, timeout=15).decode("latin-1")
    assert out.startswith("\r\n Running RAM@$0400\r\n1. Load RAM")
```
- [ ] **Step 2:** Run `uv run --no-env-file pytest -q tests/minios/test_menu.py`. Expected: golden tests fail with "has no recorded output".
- [ ] **Step 3:** `uv run --no-env-file pytest -q tests/minios/test_menu.py --update-golden`, then **read `golden/menu.txt` and `golden/ram_test.txt` by hand**: `menu.txt` must be the real menu ending `OK> `; `ram_test.txt` must contain eight ` Testing RAM... PASS|FAIL` pairs. Do not accept a golden that holds an error or an empty string.
- [ ] **Step 4:** Rerun without `--update-golden` → all pass. Rerun once more to check stability. (Option 4 clears RAM before test 3's store, which is why `test_run_program...` stores its own `RTS`: order-independent.)
- [ ] **Step 5:** Commit `Add the miniOS menu tests`.

---

### Task 5: Wozmon tests

**Files:** Create `tests/minios/test_wozmon.py`.

- [ ] **Step 1: Write the tests** (each uses its own address so test order cannot matter):

```python
from minios_session import MENU


def test_banner(wozmon):
    assert wozmon.banner == "\r\nWelcome to EWOZMON 1.0.\r\n]"


def test_examine_shows_one_byte(wozmon):
    wozmon.line("0510: 5A")
    assert wozmon.line("0510") == "\r\n0510: 5A\r\n"


def test_store_reports_the_old_byte(wozmon):
    assert wozmon.line("0520: 11") == "\r\n0520: 00\r\n"
    assert wozmon.line("0520: 22") == "\r\n0520: 11\r\n"


def test_store_several_bytes_then_block_examine(wozmon):
    wozmon.line("0530: A9 41 8D 00 A8 60")
    assert wozmon.line("0530.0535") == "\r\n0530: A9 41 8D 00 A8 60\r\n"


def test_block_examine_starts_a_new_line_every_16_bytes(wozmon):
    wozmon.line("0540: 00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F 10 11 12 13")
    assert wozmon.line("0540.0553") == (
        "\r\n0540: 00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F"
        "\r\n0550: 10 11 12 13\r\n")


def test_input_is_upper_cased(wozmon):
    wozmon.line("0560: ab", echo_for=lambda c: c.upper().encode()
                if c != "\r" else b"\r\n")
    assert wozmon.line("0560") == "\r\n0560: AB\r\n"


def test_run_executes_stored_code_and_rts_returns_to_the_menu(wozmon):
    wozmon.line("0570: A9 41 8D 00 A8 60")
    wozmon._type("0570R\r")
    out = wozmon._wait(MENU, 15).decode("latin-1")
    wozmon.left = True
    assert out.startswith("\r\n0570: A9A\r\n1. Load RAM")


def test_q_quits_to_the_menu(wozmon):
    out = wozmon.leave()
    assert out.startswith("\r\n1. Load RAM")
    assert out.endswith("A. About\r\nOK> ")
```
- [ ] **Step 2:** `uv run --no-env-file pytest -q tests/minios/test_wozmon.py` and compare failures with the measured transcripts from Task 1. Fix only after deciding from the source whether test or reading is wrong.
- [ ] **Step 3:** Prove the sync cannot pass vacuously: temporarily change `WozmonSession.SYNC` to `b"ZZZ"` and confirm every test times out (then revert).
- [ ] **Step 4:** Commit `Add the Wozmon tests`.

---

### Task 6: MilliForth tests and guard

**Files:** Create `tests/minios/test_forth.py`, `tests/minios/test_forth_coverage.py`.

- [ ] **Step 1: `test_forth.py`:**

```python
from minios_session import MENU

SCRATCH = "s@ s@ +"


def test_banner(forth):
    assert forth.banner == "\r\nMilliForth for JJ6502\r\nok> "


def test_s_at_pushes_0022(forth):
    assert forth.eval("s@ .") == " 0022"


def test_dot_does_not_drop(forth):
    assert forth.eval("s@ . .") == " 0022 0022"


def test_stack_display(forth):
    assert forth.eval(".S") == "S0498 00 "
    assert forth.eval("s@ s@ .S") == "S0494 02  0022 0022"


def test_return_stack_display(forth):
    assert forth.eval(".R") == "R04E0 00 "


def test_plus(forth):
    assert forth.eval("s@ s@ + .") == " 0044"


def test_nand(forth):
    assert forth.eval("s@ s@ nand .") == " FFDD"


def test_halve(forth):
    assert forth.eval("s@ 2/ .") == " 0011"


def test_zero_test(forth):
    assert forth.eval("s@ 0# .") == " FFFF"


def test_fetch(forth):
    assert forth.eval("s@ @ .") == " 0000"


def test_store_then_fetch(forth):
    forth.eval(f"{SCRATCH} {SCRATCH} !")
    assert forth.eval(f"{SCRATCH} @ .") == " 0044"


def test_emit_writes_the_low_byte(forth):
    assert forth.eval("s@ emit") == '"'


def test_colon_definition(forth):
    forth.eval(": sq s@ s@ + ;")
    assert forth.eval("sq .") == " 0044"


def test_unknown_word_aborts_silently_and_clears_the_stack(forth):
    assert forth.eval("s@ nonesuch", prompts=2) == ""
    assert forth.eval(".S") == "S0498 00 "


def test_abort_clears_the_stack(forth):
    forth.eval("s@ abort", prompts=2)
    assert forth.eval(".S") == "S0498 00 "


def test_words_lists_the_dictionary(forth):
    out = forth.eval("words")
    for name in ["tty", "bye", "abort", ".S", ".R", "dump", "words", ".", "2/",
                 "exec", ":$", ";$", "key", "emit", "!", "nand", "+", "@",
                 "0#", "s@", ";", ":", "exit"]:
        assert f" {name} " in out, name


def test_upper_case_words_are_unknown(forth):
    forth.eval("S@", prompts=1)
    assert forth.eval(".S") == "S0498 00 "


def test_tty_is_a_no_op_on_the_sim_build(forth):
    assert forth.eval("tty") == ""


def test_definitions_do_not_survive_re_entering_from_the_menu(menu, forth):
    forth.eval(": foo s@ ;")
    forth.leave()
    forth.enter()
    forth.left = False
    forth.eval("foo", prompts=1)
    assert forth.eval(".S") == "S0498 00 "


def test_bye_returns_to_the_menu(forth):
    out = forth.leave()
    assert out.startswith("\r\n1. Load RAM")
    assert out.endswith("A. About\r\nOK> ")
```
(The scratch cell for `!` is `$0044` = `s@ s@ +`, confirmed free in Task 1. If Task 1 chose a different cell, change `SCRATCH`.)
- [ ] **Step 2:** `uv run --no-env-file pytest -q tests/minios/test_forth.py`; resolve mismatches against the Task 1 transcripts as in Task 5. `test_words_lists_the_dictionary` checks the ` name ` form because `words` prints a space after every name.
- [ ] **Step 3: `test_forth_coverage.py`:**

```python
"""Every MilliForth word must appear in a test or carry a reason it does not."""
import ast
import re
from pathlib import Path

HERE = Path(__file__).parent
SOURCE = HERE.parents[1] / "minios" / "src" / "milliforth.s"

EXCLUDED = {
    "bye": "issued by ForthSession.leave after every test",
    "key": "interactive input",
    "dump": "writes raw binary up to `here`; runs through 64 KB when nothing is defined",
    "exec": "jumps to a machine-code address",
    ":$": "internal: inline machine code",
    ";$": "internal: inline machine code",
    "exit": "internal: unnest; crashes at top level",
}


def words():
    return set(re.findall(r'^\s*def_word\s+"([^"]+)"', SOURCE.read_text(), re.M))


def tested_tokens():
    tokens = set()
    tree = ast.parse((HERE / "test_forth.py").read_text())
    for node in ast.walk(tree):
        if (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
                and node.func.attr == "eval"):
            for arg in node.args[:1]:
                for const in ast.walk(arg):
                    if isinstance(const, ast.Constant) and isinstance(const.value, str):
                        tokens.update(const.value.split())
    return tokens


def test_word_table_was_parsed():
    assert {"nand", "s@", ".S", "bye"} <= words()
    assert len(words()) == 23


def test_every_word_is_tested_or_excluded():
    missing = sorted(words() - set(EXCLUDED) - tested_tokens())
    assert not missing, f"words with no test: {missing}"


def test_exclusions_are_real_words():
    assert set(EXCLUDED) <= words()


def test_the_test_scan_finds_tokens():
    assert {"s@", "nand", ".S", ":", ";"} <= tested_tokens()
```
Note `"words"` is also tested through `forth.eval("words")`. `SCRATCH` f-strings are `JoinedStr`, whose `Constant` parts include `"!"`, `"@ ."`, so `!` and `@` are found; confirm in Step 4.
- [ ] **Step 4:** `uv run --no-env-file pytest -q tests/minios/test_forth_coverage.py` → 4 pass. Then prove the guard can fail: temporarily delete `test_nand` from `test_forth.py` and confirm the guard reports `['nand']`; restore it. Confirm `len(words()) == 23` matches `grep -c '^\s*def_word' minios/src/milliforth.s`; if the real count differs, use the real count.
- [ ] **Step 5:** Commit `Add the MilliForth tests and word coverage guard`.

---

### Task 7: Supermon+ tests and guard

**Files:** Create `tests/minios/test_supermon.py`, `tests/minios/test_supermon_coverage.py`.

- [ ] **Step 1: `test_supermon.py`.** Helper: `lines(out)` returns `[l.rstrip() for l in out.split("\r\n") if l.strip()]`.

```python
import re

import pytest

REGS = r"; [0-9A-F]{4}( [0-9A-F]{2}){5} "
HEADER = "   PC  SR AC XR YR SP   V1.2+"


def lines(out):
    return [ln.rstrip() for ln in out.split("\r\n") if ln.strip()]


def set_regs(sm, pc, sr="00", ac="00", xr="00", yr="00", sp="FF"):
    sm.line(f"; {pc} {sr} {ac} {xr} {yr} {sp}")


def test_banner(supermon):
    assert re.fullmatch(
        r"\r\n\r\nSUPERMON\+ @ \$[0-9A-F]{4} \r\n\r\n" + re.escape(HEADER)
        + r"\r\n" + REGS + r"\r\n", supermon.banner)


def test_register_display(supermon):
    set_regs(supermon, "0500", "00", "11", "22", "33", "FF")
    assert lines(supermon.line("R")) == [HEADER, "; 0500 00 11 22 33 FF"]


def test_alter_memory_redisplays_the_line(supermon):
    out = supermon.line(">0580 41 42 43 44 45 46 47 48")
    assert lines(out) == [">0580 41 42 43 44 45 46 47 48 00 00 00 00 00 00 00 00:ABCDEFGH........"]


def test_memory_dump_one_line(supermon):
    supermon.line(">0590 41 42")
    assert lines(supermon.line("M0590 059F")) == [
        ">0590 41 42 00 00 00 00 00 00 00 00 00 00 00 00 00 00:AB.............."]


def test_memory_dump_two_lines(supermon):
    out = lines(supermon.line("M05A0 05AF"))
    assert len(out) == 1
    out = lines(supermon.line("M05A0 05B0"))
    assert [ln[:5] for ln in out] == [">05A0", ">05B0"]


def test_fill(supermon):
    assert lines(supermon.line("F0600 060F AA")) == []
    assert lines(supermon.line("M0600 060F")) == [
        ">0600 " + " ".join(["AA"] * 16) + ":" + "." * 16]


def test_transfer_then_compare_equal(supermon):
    supermon.line("F0610 061F 5A")
    supermon.line("T0610 061F 0620")
    assert lines(supermon.line("M0620 062F")) == [
        ">0620 " + " ".join(["5A"] * 16) + ":" + "Z" * 16]
    assert lines(supermon.line("C0610 061F 0620")) == []


def test_compare_reports_each_mismatch(supermon):
    supermon.line("F0630 063F 11")
    supermon.line("F0640 064F 11")
    supermon.line(">0642 22")
    assert lines(supermon.line("C0630 063F 0640")) == ["0632"]


def test_hunt_finds_a_byte_string(supermon):
    supermon.line(">0650 43 44 45")
    assert lines(supermon.line("H0650 065F 44 45")) == ["0651"]


def test_disassemble_a_short_routine(supermon):
    supermon.line(">0660 A9 41 8D 00 A8 60")
    assert lines(supermon.line("D0660 0665")) == [
        ". 0660  A9 41    LDA  #$41",
        ". 0662  8D 00 A8 STA  $A800",
        ". 0665  60       RTS"]


# (source, bytes) covering each 65C02 addressing mode and the bit forms
CASES = [
    ("NOP", "EA"),
    ("LDA #$41", "A9 41"),
    ("LDA $12", "A5 12"),
    ("LDA $12,X", "B5 12"),
    ("LDA $1234", "AD 34 12"),
    ("LDA $1234,X", "BD 34 12"),
    ("LDA $1234,Y", "B9 34 12"),
    ("LDA ($12,X)", "A1 12"),
    ("LDA ($12),Y", "B1 12"),
    ("LDA ($12)", "B2 12"),
    ("JMP ($1234)", "6C 34 12"),
    ("JMP ($1234,X)", "7C 34 12"),
    ("STZ $12", "64 12"),
    ("RMB5 $12", "57 12"),
    ("SMB2 $12", "A7 12"),
    ("BBR3 $12,$0510", "3F 12 0D"),
]


def mnemonic_field(src):
    mnem, _, operand = src.partition(" ")
    return mnem + " " * (5 - len(mnem)) + operand


def test_assemble_then_disassemble_round_trip(supermon):
    addr, steps, expect = 0x0500, [], []
    for src, raw in CASES:
        n = len(raw.split())
        expect.append((addr, raw, src))
        steps.append((src, f"{addr + n:04X}"))
        addr += n
    listing = lines(supermon.assemble("0500", steps))
    assert len(listing) == len(CASES)
    for got, (a, raw, src) in zip(listing, expect):
        assert got == f"{a:04X}  {raw.ljust(9)}{mnemonic_field(src)}".rstrip()
    last = f"{expect[-1][0]:04X}"
    back = lines(supermon.line(f"D0500 {last}"))
    assert back == [f". {a:04X}  {raw.ljust(9)}{mnemonic_field(src)}".rstrip()
                    for a, raw, src in expect]


def test_dot_is_an_alias_for_assemble(supermon):
    out = lines(supermon.assemble("0540", [("INX", "0541")], cmd="."))
    assert out == ["0540  E8       INX"]


def test_bad_mnemonic_is_an_error_and_leaves_assemble_mode(supermon):
    assert lines(supermon.line("A0500 XYZ")) == ["?"]
    assert lines(supermon.line("R"))[0] == HEADER


def test_unknown_command(supermon):
    assert lines(supermon.line("Z")) == ["?"]


@pytest.mark.parametrize("cmd", ["$41", "+65", "&101", "%1000001"])
def test_base_conversion(supermon, cmd):
    assert supermon.line(cmd) == "\r\n $0041 \r\n +65\r\n &101\r\n %1000001\r\n"


def test_base_conversion_of_zero(supermon):
    assert supermon.line("$0") == "\r\n $0000 \r\n +0\r\n &0\r\n %0\r\n"


def test_jsr_runs_a_routine_and_shows_its_registers(supermon):
    supermon.line(">0670 A9 41 8D 00 A8 60")
    set_regs(supermon, "0000")
    out = supermon.line("J0670")
    assert out.startswith("A\r\n" + HEADER)
    assert re.search(r"; 0670 [0-9A-F]{2} 41 ", out)


def test_go_runs_code_that_returns_to_supermon(supermon):
    entry = re.search(r"SUPERMON\+ @ \$([0-9A-F]{4}) ", supermon.banner).group(1)
    lo, hi = entry[2:], entry[:2]
    supermon.line(f">0680 A9 41 8D 00 A8 4C {lo} {hi}")
    set_regs(supermon, "0680")
    out = supermon.line("G0680")
    assert out.startswith("A\r\n\r\nSUPERMON+ @ $")


def test_x_returns_to_the_menu(supermon):
    out = supermon.leave()
    assert out.startswith("\r\n1. Load RAM")
    assert out.endswith("A. About\r\nOK> ")
```
`test_compare_reports_each_mismatch` expects the address `C` reports for the first range (`0632`). The listing assertions in `test_assemble_then_disassemble_round_trip` compare the assembler's own output (`0500  A9 41    LDA  #$41`, no `. ` prefix) and then `D`'s output (with the `. ` prefix) against the same generated layout.
- [ ] **Step 2:** `uv run --no-env-file pytest -q tests/minios/test_supermon.py`. Expect mismatches in whitespace and trailing text on first run: compare with the Task 1 transcripts, fix the helper (`lines`) or the expectation after deciding from `supermon.s` which is right. Known soft spots: whether `T` and `C` print an extra blank line; whether `M` ASCII shows `Z`; the exact `.` alias listing.
- [ ] **Step 3: `test_supermon_coverage.py`:**

```python
"""Every Supermon+ command letter must be exercised by a test or carry a reason."""
import ast
import re
from pathlib import Path

HERE = Path(__file__).parent
SOURCE = HERE.parents[1] / "minios" / "src" / "supermon.s"

EXCLUDED = {
    "X": "issued by SupermonSession.leave after every test",
}


def commands():
    m = re.search(r'\.IFDEF ENABLE_ASSEMBLER\s*\nKEYW:\s*\.byte "([^"]+)"',
                  SOURCE.read_text())
    return set(m.group(1)) if m else set()


def tested_commands():
    found = set()
    tree = ast.parse((HERE / "test_supermon.py").read_text())
    for node in ast.walk(tree):
        if not (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)):
            continue
        if node.func.attr == "line" and node.args:
            first = node.args[0]
        elif node.func.attr == "assemble":
            for kw in node.keywords:
                if kw.arg == "cmd" and isinstance(kw.value, ast.Constant):
                    found.add(kw.value.value)
            found.add("A")
            continue
        else:
            continue
        for const in ast.walk(first):
            if isinstance(const, ast.Constant) and isinstance(const.value, str):
                if const.value.strip():
                    found.add(const.value.strip()[0])
                break
    return found


def test_command_table_was_parsed():
    assert commands() == set("ACDFGHJMRTX.>;")


def test_every_command_is_tested_or_excluded():
    missing = sorted(commands() - set(EXCLUDED) - tested_commands())
    assert not missing, f"commands with no test: {missing}"


def test_exclusions_are_real_commands():
    assert set(EXCLUDED) <= commands()


def test_the_test_scan_finds_commands():
    assert {"M", "R", ">", ";", "D", "J", "G", "."} <= tested_commands()
```
For JoinedStr first arguments, `ast.walk(first)` visits the first `Constant`. `;` is found through `set_regs`, whose `sm.line(f"; {pc} ...")` is a `JoinedStr` starting with the constant `"; "`.
- [ ] **Step 4:** Run the guard (4 pass). Then prove it can fail: temporarily delete `test_hunt_finds_a_byte_string` from `test_supermon.py`, confirm the guard reports `['H']`, and restore the test.
- [ ] **Step 5:** Commit `Add the Supermon+ tests and command coverage guard`.

---

### Task 8: Docs, full run, review

**Files:** Modify `tests/README.md`, `AGENTS.md` (untracked), `tests/PHASE2A_DESIGN.md`; add `HANDOFF.md` refresh (untracked).

- [ ] **Step 1: `tests/README.md`:** add a "miniOS tier" section: the `tests/minios/` modules, the four fixtures, why Enter echoes differently (`echo_for`), the idle markers (BS) and why ESC cannot be used, the Forth prompt-per-word rule (`prompts_for`), the two coverage guards and their `EXCLUDED` tables, how to add a command/word test. Quote the measured per-line timings and suite time from Task 1 and the full run (Step 3), not estimates. Add `-m`/path examples that were actually run.
- [ ] **Step 2: `AGENTS.md`:** extend the `tests/` row and the regression-tests bullet to name `tests/minios/` and `tests/minios_session.py`.
- [ ] **Step 3: Full run in the background:** `export CA65_INC=...; (uv run --no-env-file pytest -q > $SCRATCH/full.log 2>&1; echo "exit=$?" >> $SCRATCH/full.log) &`. Expect Phase 1's 118 plus the new tests, all passing; record count and time. Run it twice if any test is order- or timing-sensitive.
- [ ] **Step 4:** Verify every command written in `tests/README.md` by running it.
- [ ] **Step 5:** Commit `Document the miniOS test tier`.
- [ ] **Step 6: Whole-branch review.** Run `review-package` (merge base: the commit before Task 0; list it with `git log --oneline`) from `~/.claude/plugins/cache/claude-plugins-official/superpowers/6.4.1/skills/subagent-driven-development/scripts/`; fresh reviewer on the most capable model; pass it the Review Focus above; one test-first fix pass.
- [ ] **Step 7:** Refresh `HANDOFF.md`; ask Jim before merging or pushing (he decides integration).

---

## Self-review

- **Spec coverage:** components (Tasks 2, 3), per-program tests (4-7), coverage guards (6, 7), four open items (Task 1, with a gate), docs (8). Loaders are out of scope per the spec.
- **Open assumptions that Task 1 must close:** BS idle markers, `T`/`C` blank-line behaviour, the `.` alias listing, Forth scratch cell `$0044`, word count 23, and the `=`/`U` quirk in Supermon's unknown-command scan.
- **Type consistency:** `type_text(..., echo_for=)` (Task 2) is used by `_Program._type` (Task 3) and by the Wozmon upper-case test (Task 5); `line`/`eval`/`assemble`/`leave`/`left`/`banner` names match across Tasks 3-7; guards parse the `eval`, `line` and `assemble(cmd=)` call shapes the tests use.
- **Placeholders:** none; expectations marked "not yet run" are reconciled in Task 1 and by the compare-from-source rule in Tasks 5-7.

## Verification

`uv run --no-env-file pytest -q tests/harness tests/minios` after Task 7; the full suite in the background in Task 8 Step 3; each guard proven able to fail (Tasks 6, 7); each sync marker proven able to fail (Task 5 Step 3).
