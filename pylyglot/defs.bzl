"""Public API for rules_pylyglot."""

load(
    "//pylyglot/private:pylyglot_bundle.bzl",
    _pylyglot_multiplat_bundle = "pylyglot_multiplat_bundle",
    _pylyglot_posix_first_binary = "pylyglot_posix_first_binary",
    _pylyglot_windows_first_binary = "pylyglot_windows_first_binary",
)

pylyglot_multiplat_bundle = _pylyglot_multiplat_bundle
pylyglot_posix_first_binary = _pylyglot_posix_first_binary
pylyglot_windows_first_binary = _pylyglot_windows_first_binary
