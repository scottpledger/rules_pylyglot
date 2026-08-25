from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys


def _check(command: list[str]) -> None:
    result = subprocess.run(command, check=False, capture_output=True, text=True)
    if result.returncode != 0 or result.stdout.strip() != "external module bundle works":
        raise AssertionError(
            f"{command!r} returned {result.returncode}\n"
            f"stdout: {result.stdout!r}\nstderr: {result.stderr!r}"
        )


def main() -> None:
    root = Path(os.environ["TEST_SRCDIR"]) / os.environ["TEST_WORKSPACE"]
    _check([sys.executable, str(root / "smoke_bundle.py")])
    if os.name == "nt":
        _check(["cmd.exe", "/d", "/c", str(root / "smoke_bundle.cmd")])
    else:
        _check([str(root / "smoke_bundle")])


if __name__ == "__main__":
    main()
