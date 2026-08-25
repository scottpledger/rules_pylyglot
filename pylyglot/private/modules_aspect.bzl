"""Collects Python sources while retaining their owning import context."""

load("@rules_python//python:py_info.bzl", "PyInfo")

PylyglotModuleInfo = provider(
    doc = "Python sources and per-target import metadata for bundling.",
    fields = {
        "entries": "Depset of source metadata structs.",
        "uses_shared_libraries": "Whether any dependency uses native libraries.",
    },
)

def _direct_sources(target):
    py_info = target[PyInfo]
    if hasattr(py_info, "direct_original_sources"):
        return py_info.direct_original_sources.to_list()

    return [
        file
        for file in target[DefaultInfo].files.to_list()
        if file.extension in ("py", "py3")
    ]

def _venv_path_for_file(py_info, file):
    if not hasattr(py_info, "venv_symlinks"):
        return None
    for entry in py_info.venv_symlinks.to_list():
        if entry.kind == "LIB" and entry.link_to_file == file:
            return entry.venv_path
    return None

def _modules_aspect_impl(target, ctx):
    if PyInfo not in target:
        return []

    imports = ()
    if hasattr(ctx.rule.attr, "imports"):
        imports = tuple(ctx.rule.attr.imports)

    entries = []
    for file in _direct_sources(target):
        entries.append(struct(
            file = file,
            imports = imports,
            label = str(target.label),
            package = target.label.package,
            venv_path = _venv_path_for_file(target[PyInfo], file),
        ))

    transitive_entries = []
    uses_shared_libraries = target[PyInfo].uses_shared_libraries
    if hasattr(ctx.rule.attr, "deps"):
        for dep in ctx.rule.attr.deps:
            if PylyglotModuleInfo in dep:
                transitive_entries.append(dep[PylyglotModuleInfo].entries)
                uses_shared_libraries = (
                    uses_shared_libraries or
                    dep[PylyglotModuleInfo].uses_shared_libraries
                )

    return [PylyglotModuleInfo(
        entries = depset(entries, transitive = transitive_entries),
        uses_shared_libraries = uses_shared_libraries,
    )]

pylyglot_modules_aspect = aspect(
    implementation = _modules_aspect_impl,
    attr_aspects = ["deps"],
    doc = "Collect direct Python sources and their import roots.",
)
