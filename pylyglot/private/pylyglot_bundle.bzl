"""Implementation of the public Pylyglot bundle rules."""

load("@rules_python//python:py_info.bzl", "PyInfo")
load(":modules_aspect.bzl", "PylyglotModuleInfo", "pylyglot_modules_aspect")

_MULTIPLAT = "multiplat"
_POSIX_FIRST = "posix_first"
_WINDOWS_FIRST = "windows_first"

def _repo_relative_path(file):
    path = file.short_path
    if path.startswith("../"):
        parts = path.split("/", 2)
        if len(parts) == 3:
            return parts[2]
    return path

def _normalize_path(path):
    parts = []
    for part in path.replace("\\", "/").split("/"):
        if not part or part == ".":
            continue
        if part == "..":
            if not parts:
                fail("Import path escapes the repository: {}".format(path))
            parts.pop()
        else:
            parts.append(part)
    return "/".join(parts)

def _import_roots(package, imports):
    roots = [""]
    for import_path in imports:
        if import_path.startswith("/"):
            fail("Absolute Python import paths are unsupported: {}".format(import_path))
        roots.append(_normalize_path("/".join([package, import_path])))
    return roots

def _provider_import_roots(imports):
    roots = []
    for import_path in imports:
        normalized = _normalize_path(import_path)
        roots.append(normalized)
        if "/" in normalized:
            # PyInfo import roots are normally rooted below a runfiles
            # repository name, while source paths here are repository-relative.
            roots.append(normalized.partition("/")[2])
    return roots

def _module_from_path(path, roots):
    matches = []
    for root in roots:
        if not root:
            matches.append((0, path))
        elif path.startswith(root + "/"):
            matches.append((len(root), path[len(root) + 1:]))

    if not matches:
        fail("No Python import root contains '{}'".format(path))

    longest = max([match[0] for match in matches])
    logical_paths = {
        match[1]: True
        for match in matches
        if match[0] == longest
    }
    if len(logical_paths) != 1:
        fail("Ambiguous Python import roots for '{}': {}".format(path, logical_paths.keys()))

    logical_path = logical_paths.keys()[0]
    if logical_path.endswith("/__init__.py"):
        return logical_path[:-len("/__init__.py")].replace("/", "."), True
    if logical_path.endswith("/__init__.py3"):
        return logical_path[:-len("/__init__.py3")].replace("/", "."), True
    if logical_path in ("__init__.py", "__init__.py3"):
        fail("A repository-root __init__.py cannot be assigned a module name")
    if logical_path.endswith(".py"):
        return logical_path[:-3].replace("/", "."), False
    if logical_path.endswith(".py3"):
        return logical_path[:-4].replace("/", "."), False
    fail("Expected a Python source file, got '{}'".format(path))

def _entry_for_file(file, package, imports, extra_roots, module_mappings, venv_path = None):
    path = _repo_relative_path(file)
    override = module_mappings.get(path)
    if override == None:
        override = module_mappings.get(file.short_path)

    if override != None:
        module_name = override
        is_package = file.basename in ("__init__.py", "__init__.py3")
    elif venv_path:
        module_name, is_package = _module_from_path(
            _normalize_path(venv_path),
            [""],
        )
    else:
        module_name, is_package = _module_from_path(
            path,
            _import_roots(package, imports) + extra_roots,
        )

    if not module_name:
        fail("Python module name for '{}' is empty".format(path))
    return struct(
        file = file,
        is_package = is_package,
        module_name = module_name,
        origin = path,
    )

def _collect_entries(ctx):
    extra_roots = _import_roots(ctx.label.package, ctx.attr.imports)
    for dep in ctx.attr.deps:
        extra_roots.extend(_provider_import_roots(dep[PyInfo].imports.to_list()))

    entries = []
    for file in ctx.files.srcs:
        entries.append(_entry_for_file(
            file,
            ctx.label.package,
            ctx.attr.imports,
            extra_roots,
            ctx.attr.module_mappings,
            venv_path = None,
        ))

    uses_shared_libraries = False
    for dep in ctx.attr.deps:
        info = dep[PylyglotModuleInfo]
        uses_shared_libraries = uses_shared_libraries or info.uses_shared_libraries
        dep_entries = info.entries.to_list()
        if not dep_entries:
            fail(
                "dependency '{}' exposes no original Python source".format(dep.label),
                attr = "deps",
            )
        for source in dep_entries:
            entries.append(_entry_for_file(
                source.file,
                source.package,
                source.imports,
                extra_roots,
                ctx.attr.module_mappings,
                venv_path = source.venv_path,
            ))

    if uses_shared_libraries:
        fail(
            "pylyglot bundles only Python source; a dependency reports native shared libraries",
            attr = "deps",
        )

    main_path = _repo_relative_path(ctx.file.main)
    modules = {}
    files = {}
    packages = {}
    for entry in entries:
        if entry.file.path == ctx.file.main.path:
            continue
        prior = modules.get(entry.module_name)
        if prior != None and prior.file.path != entry.file.path:
            fail(
                "Python module '{}' maps to both '{}' and '{}'".format(
                    entry.module_name,
                    prior.origin,
                    entry.origin,
                ),
            )
        modules[entry.module_name] = entry
        files[entry.file.path] = entry.file
        if entry.is_package:
            packages[entry.module_name] = True

    for module_name in modules:
        parts = module_name.split(".")
        for index in range(1, len(parts)):
            package_name = ".".join(parts[:index])
            if package_name not in packages:
                fail(
                    (
                        "Module '{}' requires package '{}', but no __init__.py was bundled; " +
                        "namespace packages are unsupported in v1"
                    ).format(
                        module_name,
                        package_name,
                    ),
                )

    main_entry = _entry_for_file(
        ctx.file.main,
        ctx.label.package,
        ctx.attr.imports,
        extra_roots,
        ctx.attr.module_mappings,
        venv_path = None,
    )
    main_package = ""
    if "." in main_entry.module_name:
        main_package = main_entry.module_name.rpartition(".")[0]

    files[ctx.file.main.path] = ctx.file.main
    return struct(
        files = files.values(),
        main_package = main_package,
        main_path = main_path,
        modules = modules,
    )

def _declare_outputs(ctx, style):
    if style == _MULTIPLAT:
        payload = ctx.actions.declare_file(ctx.label.name + ".py")
        posix = ctx.actions.declare_file(ctx.label.name)
        windows = ctx.actions.declare_file(ctx.label.name + ".cmd")
        return struct(
            all = [payload, posix, windows],
            payload = payload,
            posix = posix,
            windows = windows,
        )

    output = ctx.actions.declare_file(ctx.label.name + ".cmd")
    return struct(
        all = [output],
        payload = None,
        posix = output,
        windows = output,
    )

def _bundle_impl(ctx, style):
    collected = _collect_entries(ctx)
    outputs = _declare_outputs(ctx, style)
    manifest = ctx.actions.declare_file(ctx.label.name + ".pylyglot.json")

    module_records = []
    for name in sorted(collected.modules):
        entry = collected.modules[name]
        module_records.append({
            "is_package": entry.is_package,
            "name": name,
            "origin": entry.origin,
            "path": entry.file.path,
        })

    ctx.actions.write(
        output = manifest,
        content = json.encode_indent({
            "main": {
                "package": collected.main_package,
                "path": ctx.file.main.path,
                "origin": collected.main_path,
            },
            "modules": module_records,
            "outputs": {
                "payload": outputs.payload.path if outputs.payload else None,
                "posix": outputs.posix.path,
                "windows": outputs.windows.path,
            },
            "style": style,
        }) + "\n",
    )

    args = ctx.actions.args()
    args.add("--manifest", manifest.path)
    ctx.actions.run(
        executable = ctx.executable._bundler,
        arguments = [args],
        inputs = depset(
            direct = [manifest],
            transitive = [depset(collected.files)],
        ),
        outputs = outputs.all,
        mnemonic = "PylyglotBundle",
        progress_message = "Bundling Python sources for %{label}",
        toolchain = None,
    )

    executable = outputs.posix
    if style == _MULTIPLAT and ctx.target_platform_has_constraint(
        ctx.attr._windows_constraint[platform_common.ConstraintValueInfo],
    ):
        executable = outputs.windows

    return [DefaultInfo(
        executable = executable,
        files = depset(outputs.all),
    )]

def _multiplat_impl(ctx):
    return _bundle_impl(ctx, _MULTIPLAT)

def _posix_first_impl(ctx):
    return _bundle_impl(ctx, _POSIX_FIRST)

def _windows_first_impl(ctx):
    return _bundle_impl(ctx, _WINDOWS_FIRST)

def _attrs():
    return {
        "deps": attr.label_list(
            doc = "Source-based Python libraries to embed.",
            aspects = [pylyglot_modules_aspect],
            providers = [[PyInfo]],
        ),
        "imports": attr.string_list(
            doc = "Additional repository-relative Python import roots.",
        ),
        "main": attr.label(
            doc = "Python source file to execute as __main__.",
            allow_single_file = [".py", ".py3"],
            mandatory = True,
        ),
        "module_mappings": attr.string_dict(
            doc = "Overrides from repository-relative source paths to module names.",
        ),
        "srcs": attr.label_list(
            doc = "Additional direct Python source files to embed.",
            allow_files = [".py", ".py3"],
        ),
        "_bundler": attr.label(
            default = Label("//pylyglot/private:bundler"),
            cfg = "exec",
            executable = True,
        ),
        "_windows_constraint": attr.label(
            default = Label("@platforms//os:windows"),
        ),
    }

pylyglot_multiplat_bundle = rule(
    implementation = _multiplat_impl,
    attrs = _attrs(),
    executable = True,
    doc = """Bundles Python source with separate clean POSIX and Windows launchers.

The target emits `<name>.py`, `<name>`, and `<name>.cmd`. Native extensions,
package data, namespace packages, and third-party distributions are unsupported.
""",
)

pylyglot_posix_first_binary = rule(
    implementation = _posix_first_impl,
    attrs = _attrs(),
    executable = True,
    doc = """Bundles Python source into one POSIX-first shell/batch file.

The shebang makes direct POSIX execution reliable. Windows cmd.exe emits one
initial diagnostic before the batch launcher starts. Native extensions, package
data, namespace packages, and third-party distributions are unsupported.
""",
)

pylyglot_windows_first_binary = rule(
    implementation = _windows_first_impl,
    attrs = _attrs(),
    executable = True,
    doc = """Bundles Python source into one Windows-first batch/shell file.

Windows execution is clean. POSIX execution relies on shell ENOEXEC fallback or
an explicit `sh <name>.cmd`. Native extensions, package data, namespace packages,
and third-party distributions are unsupported.
""",
)
