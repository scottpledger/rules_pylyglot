from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys


_EXPECTED_OUTPUT = "Hello pylyglot generated ab transitive py3 one two"


def _run(
    command: list[str],
    *,
    allow_output_prefix: bool = False,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(command, check=False, capture_output=True, text=True)
    if result.returncode:
        raise AssertionError(
            f"{command!r} returned {result.returncode}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )
    output = result.stdout.strip()
    if allow_output_prefix:
        output = output.splitlines()[-1] if output else ""
    if output != _EXPECTED_OUTPUT:
        raise AssertionError(f"unexpected stdout from {command!r}: {result.stdout!r}")
    return result


def _expect_exit(command: list[str]) -> None:
    result = subprocess.run(command, check=False, capture_output=True, text=True)
    if result.returncode != 23:
        raise AssertionError(
            f"{command!r} returned {result.returncode}, expected 23\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )


def main() -> None:
    runfiles = Path(os.environ["TEST_SRCDIR"])
    workspace = os.environ["TEST_WORKSPACE"]
    package = runfiles / workspace / "pylyglot" / "tests"

    payload = package / "multiplat.py"
    payload_text = payload.read_text(encoding="utf-8")
    module_markers = [
        "_PYLYGLOT_MODULES['generated']",
        "_PYLYGLOT_MODULES['pkg']",
        "_PYLYGLOT_MODULES['pkg.cycle_a']",
        "_PYLYGLOT_MODULES['pkg.cycle_b']",
        "_PYLYGLOT_MODULES['pkg.dynamic']",
        "_PYLYGLOT_MODULES['pkg.messages']",
        "_PYLYGLOT_MODULES['pkg.parts']",
        "_PYLYGLOT_MODULES['pkg2']",
        "_PYLYGLOT_MODULES['pkg2.value']",
        "_PYLYGLOT_MODULES['py3pkg']",
        "_PYLYGLOT_MODULES['py3pkg.module']",
    ]
    positions = [payload_text.index(marker) for marker in module_markers]
    if positions != sorted(positions):
        raise AssertionError("embedded modules are not sorted deterministically")
    if """b'    return "generated"'""" not in payload_text:
        raise AssertionError("generated source without a final newline was not preserved")
    windows_text = (package / "multiplat.cmd").read_text(encoding="utf-8")
    probe = '@py -3 -c "import sys;raise SystemExit'
    invocation = '@py -3 "%~dp0multiplat.py"'
    if windows_text.index(probe) > windows_text.index(invocation):
        raise AssertionError("Windows launcher does not probe py -3 before execution")

    _run([sys.executable, str(payload), "one", "two"])
    _expect_exit([sys.executable, str(payload), "--fail"])

    if os.name == "nt":
        _run(["cmd.exe", "/d", "/c", str(package / "multiplat.cmd"), "one", "two"])
        _expect_exit(["cmd.exe", "/d", "/c", str(package / "multiplat.cmd"), "--fail"])
        posix_first = _run(
            ["cmd.exe", "/d", "/c", str(package / "posix_first.cmd"), "one", "two"],
            allow_output_prefix=True,
        )
        _expect_exit(
            ["cmd.exe", "/d", "/c", str(package / "posix_first.cmd"), "--fail"]
        )
        if "#!/bin/sh" not in posix_first.stdout:
            raise AssertionError("POSIX-first Windows execution should document its shebang")
        _run(
            ["cmd.exe", "/d", "/c", str(package / "windows_first.cmd"), "one", "two"]
        )
        _expect_exit(
            ["cmd.exe", "/d", "/c", str(package / "windows_first.cmd"), "--fail"]
        )
    else:
        _run([str(package / "multiplat"), "one", "two"])
        _expect_exit([str(package / "multiplat"), "--fail"])
        _run([str(package / "posix_first.cmd"), "one", "two"])
        _expect_exit([str(package / "posix_first.cmd"), "--fail"])
        _run(["sh", str(package / "windows_first.cmd"), "one", "two"])
        _expect_exit(["sh", str(package / "windows_first.cmd"), "--fail"])


if __name__ == "__main__":
    main()
