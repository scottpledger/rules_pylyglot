from .parts import word


def greeting() -> str:
    return word().capitalize()
