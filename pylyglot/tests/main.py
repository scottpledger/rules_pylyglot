from __future__ import annotations

import importlib
import sys

import generated
from pkg.cycle_a import cycle_value
from pkg.messages import greeting
from pkg2.value import value
from py3pkg import py3_value


def main() -> int:
    if sys.argv[1:] == ["--fail"]:
        return 23
    dynamic = importlib.import_module("pkg.dynamic")
    print(
        f"{greeting()} {dynamic.subject()} {generated.suffix()} {cycle_value()} {value()} "
        f"{py3_value()} "
        f"{' '.join(sys.argv[1:])}".rstrip()
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
