from . import cycle_b

VALUE = "a"


def cycle_value() -> str:
    return VALUE + cycle_b.VALUE
