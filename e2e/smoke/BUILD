"""Provides a simple way to test your rules as an external module.
Add a basic smoke-test target below.
"""

load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@rules_pylyglot//pylyglot:defs.bzl", "pylyglot_multiplat_bundle")
load("@rules_python//python:defs.bzl", "py_library", "py_test")

py_library(
    name = "message",
    srcs = ["message.py"],
)

pylyglot_multiplat_bundle(
    name = "smoke_bundle",
    main = "main.py",
    deps = [":message"],
)

build_test(
    name = "smoke_build_test",
    targets = [":smoke_bundle"],
)

py_test(
    name = "smoke_test",
    srcs = ["smoke_test.py"],
    data = [":smoke_bundle"],
    legacy_create_init = 0,
)
