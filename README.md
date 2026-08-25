# Bazel rules for Pylyglot

`rules_pylyglot` provides Bazel rules for combining a Python entry point and
its first-party dependencies into reviewable, text-only scripts.

## Usage

```starlark
load("@rules_python//python:defs.bzl", "py_library")
load(
    "@rules_pylyglot//pylyglot:defs.bzl",
    "pylyglot_multiplat_bundle",
)

py_library(
    name = "lib",
    srcs = [
        "my_app/__init__.py",
        "my_app/lib.py",
    ],
)

pylyglot_multiplat_bundle(
    name = "my_tool",
    main = "main.py",
    deps = [":lib"],
)
```

The rules accept:

- `main`: the `.py` entry point executed as `__main__`.
- `srcs`: additional direct `.py` sources.
- `deps`: source-based targets that provide `PyInfo`, such as `py_library`.
- `imports`: extra import roots, with the same repository-relative intent as
  the corresponding Python rule attribute.
- `module_mappings`: overrides from repository-relative source paths to fully
  qualified module names for unusual or generated layouts.

Every declared source is embedded. Pylyglot does not prune dependencies by
scanning imports, so computed imports work when their modules are present in
`srcs` or `deps`.

## Bundle styles

### `pylyglot_multiplat_bundle`

Produces three files:

- `<name>.py`: the self-contained Python payload.
- `<name>`: a clean POSIX launcher.
- `<name>.cmd`: a clean Windows launcher.

`bazel run` selects the appropriate launcher for the target platform. Keep all
three files together when copying or checking generated outputs into another
repository.

### `pylyglot_posix_first_binary`

Produces one `<name>.cmd` that starts with a POSIX shebang. It executes directly
on POSIX and as a native batch file on Windows. Because `cmd.exe` attempts to
interpret the shebang before reaching `@echo off`, Windows echoes that line once
on standard output before running the payload.

### `pylyglot_windows_first_binary`

Produces one `<name>.cmd` with clean native Windows execution. On POSIX it
depends on the caller's `ENOEXEC` shell fallback; callers that invoke files
directly, including some Go programs, may need `sh <name>.cmd`.

Each launcher tries Python 3 without bundling an interpreter. POSIX checks
`python3` and then `python`; Windows checks `py -3`, `python3`, and then
`python`.

## Limitations

The initial release supports conventionally laid-out, first-party Python
source. It does not support:

- native extension modules or dependencies that expose no original source;
- package data, `importlib.resources`, or distribution metadata;
- namespace packages (packages must contain `__init__.py`);
- guaranteed bundling of third-party wheels.

Pure-Python third-party code may work, but it is not currently part of the
compatibility contract. Standard `PyInfo` does not provide an authoritative
file-to-module mapping, so ambiguous layouts fail with an error instead of
being guessed. Pylyglot uses experimental `venv_symlinks` mappings as
supplemental evidence when a provider supplies direct file links; use
`module_mappings` for generated files, unusual roots, and collisions.

## Installation

From the release you wish to use:
<https://github.com/scottpledger/rules_pylyglot/releases>
copy the Bzlmod snippet into your `MODULE.bazel` file.

To use a commit rather than a release, you can point at any SHA of the repo with an `archive_override` in MODULE.bazel.

For example to use commit `abc123`:

```starlark
archive_override(
    module_name = "rules_pylyglot",
    url = "https://github.com/scottpledger/rules_pylyglot/archive/abc123.tar.gz",
    strip_prefix = "rules_pylyglot-abc123",
    # The easiest way to set this is to comment out this line, then Bazel will print
    # a message with the correct value. Note that GitHub source archives don't have a strong
    # guarantee on the sha256 stability, see <https://github.blog/2023-02-21-update-on-the-future-stability-of-source-code-archives-and-hashes/>
    integrity = "...",
)
```
