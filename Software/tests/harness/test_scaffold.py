import sys


def test_harness_dir_is_importable():
    assert any(p.endswith("Harness") for p in sys.path)
