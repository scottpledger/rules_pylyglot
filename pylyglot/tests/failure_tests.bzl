"""Analysis tests for rejected bundle layouts."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_python//python:py_info.bzl", "PyInfo")

def _failure_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, ctx.attr.expected_message)
    return analysistest.end(env)

failure_test = analysistest.make(
    _failure_test_impl,
    expect_failure = True,
    attrs = {
        "expected_message": attr.string(mandatory = True),
    },
)

def _empty_py_library_impl(_ctx):
    return [
        DefaultInfo(),
        PyInfo(transitive_sources = depset()),
    ]

empty_py_library = rule(
    implementation = _empty_py_library_impl,
    provides = [PyInfo],
)
