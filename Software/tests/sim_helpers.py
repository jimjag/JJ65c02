import time


def eventually(check, timeout=5.0):
    deadline = time.monotonic() + timeout
    while True:
        try:
            return check()
        except AssertionError:
            if time.monotonic() >= deadline:
                raise
            time.sleep(0.1)


# PIDs of every sim the fixtures started, so a test can prove none outlived its test.
STARTED_SIM_PIDS = []
