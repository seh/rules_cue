load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@rules_shell//shell:sh_binary.bzl",
    "sh_binary",
)
load(
    "//cue/private:config.bzl",
    "CUEConfigInfo",
)
load(
    "//cue/private:future.bzl",
    _runfile_path = "runfile_path",
)

CUEModuleInfo = provider(
    doc = "Collects files from cue_module targets for use by referring cue_instance targets.",
    fields = {
        "module_file": """The "module.cue" file in the module directory.""",
        # TODO(seh): Consider abandoning this field in favor of using cue_instance for these.
        "external_package_sources": "The set of files in this CUE module defining external packages.",
    },
)

CUEInstanceInfo = provider(
    doc = "Collects files and references from cue_instance targets for use in downstream consuming targets.",
    fields = {
        "directory_path": """Directory path (a "short path") to the CUE instance.""",
        "files": "The CUE files defining this instance.",
        "module": "The CUE module within which this instance sits.",
        "package_name": "Name of the CUE package to load for this instance.",
        "transitive_files": "The set of files (including other instances) referenced by this instance.",
    },
)

def _replacer_if_stamping(stamping_policy):
    # NB: We can't access the "_cue_config" attribute here.
    return Label("//tools/cmd/replace-stamps") if stamping_policy != "Prevent" else None

def _add_common_source_consuming_attrs_to(attrs):
    attrs.update({
        "qualified_srcs": attr.label_keyed_string_dict(
            doc = """Additional input files that are not part of a CUE package, each together with a qualifier.

The qualifier overrides CUE's normal guessing at a file's type from
its file extension. Specify it here without the trailing colon
character.""",
            allow_files = True,
        ),
        "srcs": attr.label_list(
            doc = "Additional input files that are not part of a CUE package.",
            allow_files = True,
        ),
    })
    return attrs

def _add_common_output_producing_attrs_to(attrs):
    attrs = _add_common_source_consuming_attrs_to(attrs)
    attrs.update({
        "_cue_config": attr.label(
            default = "//cue:cue_config",
        ),
        "_replacer": attr.label(
            default = _replacer_if_stamping,
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),
        "concatenate_objects": attr.bool(
            doc = "Concatenate multiple objects into a list.",
        ),
        "cue_debug": attr.string(
            doc = """Debug flags to pass to CUE via the CUE_DEBUG environment variable.

The value is a comma-separated list of debug flags. See CUE documentation
for available debug flags.""",
            default = "",
        ),
        # Unfortunately, we can't use a private attribute for an
        # implicit dependency here, because we can't fix the default
        # label value.
        "cue_run": attr.label(
            executable = True,
            allow_files = True,
            cfg = "exec",
            mandatory = True,
        ),
        "expression": attr.string(
            doc = "CUE expression selecting a single value to export.",
            default = "",
        ),
        "inject": attr.string_dict(
            doc = "Keys and values of tagged fields.",
        ),
        "inject_shorthand": attr.string_list(
            doc = "Shorthand values of tagged fields.",
        ),
        "inject_system_variables": attr.bool(
            doc = "Whether to inject the predefined set of system variables into tagged fields",
        ),
        "merge_other_files": attr.bool(
            doc = "Merge non-CUE files.",
            default = True,
        ),
        "non_cue_file_package_name": attr.string(
            doc = """Name of the CUE package within which to merge non-CUE files.

Deprecated:
  Use "output_package_name" instead.""",
        ),
        "output_package_name": attr.string(
            doc = "Name of the CUE package within which to generate CUE output.",
        ),
        "path": attr.string_list(
            doc = """Elements of CUE path at which to place top-level values.
Each entry for an element may nominate either a CUE field, ending with
either ":" for a regular fiield or "::" for a definition, or a CUE
expression, both variants evaluated within the value, unless
"with_context" is true.""",
        ),
        "stamping_policy": attr.string(
            doc = """Whether to stamp tagged field values before injection.

If "Allow," stamp tagged field values only when the "--stamp" flag is
active.

If "Force," stamp tagged field values unconditionally, even if the
"--stamp" flag is inactive.

If "Prevent," never stamp tagged field values, even if the "--stamp"
flag is active.""",
            values = [
                "Allow",
                "Force",
                "Prevent",
            ],
            default = "Allow",
        ),
        "with_context": attr.bool(
            doc = """Evaluate "path" elements within a struct of contextual data.
Instead of evaluating these elements in the context of the value being
situated, instead evaluate them within a struct identifying the source
data, file name, record index, and record count.""",
        ),
    })
    return attrs

def _add_common_module_based_attrs_to(attrs):
    attrs = _add_common_output_producing_attrs_to(attrs)
    attrs.update({
        "deps": attr.label_list(
            doc = """cue_instance targets to include in the evaluation.

These instances are those mentioned in import declarations in this set
of CUE files.""",
            providers = [CUEInstanceInfo],
        ),
        "module": attr.label(
            doc = """CUE module within which these files sit.

This value must refer either to a target using the cue_module rule or
another rule that yields a CUEModuleInfo provider.""",
            providers = [CUEModuleInfo],
            mandatory = True,
        ),
    })
    return attrs

def _add_common_instance_consuming_attrs_to(attrs):
    attrs = _add_common_output_producing_attrs_to(attrs)
    attrs.update({
        "instance": attr.label(
            doc = """CUE instance to export.
 
This value must refer either to a target using the cue_instance rule
or another rule that yields a CUEInstanceInfo provider.""",
            providers = [CUEInstanceInfo],
            mandatory = True,
        ),
    })
    return attrs

def _file_from_label_keyed_string_dict_key(k):
    # NB: The Targets in a label_keyed_string_dict attribute have the key's
    # source file in a depset, as opposed being represented directly as in a
    # label_list attribute.
    files = k.files.to_list()
    if len(files) != 1:
        fail(msg = "Unexpected number of files in target {}: {}".format(k, len(files)))
    return files[0]

def _collect_packageless_file_path(ctx, file, lines):
    p = _runfile_path(ctx, file)
    if p.find(":") != -1:
        fail(msg = "CUE rejects file paths that contain a colon (:): {}".format(p))
    lines.append(p + "\n")

def _add_common_output_producing_args_to(ctx, args, stamped_args_file, packageless_files_file):
    cue_config = ctx.attr._cue_config[CUEConfigInfo]
    stamping_enabled = ctx.attr.stamping_policy == "Force" or ctx.attr.stamping_policy == "Allow" and cue_config.stamp
    required_stamp_bindings = {}

    if ctx.attr.expression:
        args.add("--expression", ctx.attr.expression)
    for k, v in ctx.attr.inject.items():
        if len(k) == 0:
            fail(msg = "injected key must not empty")
        if stamping_enabled and v.startswith("{") and v.endswith("}"):
            required_stamp_bindings[k] = v[1:-1]
            continue
        args.add(
            "--inject",
            # Allow the empty string as a specified value.
            "{}={}".format(k, v),
        )
    for v in ctx.attr.inject_shorthand:
        if len(v) == 0:
            fail(msg = "injected value must not empty")
        args.add("--inject", v)
    if ctx.attr.concatenate_objects:
        args.add("--list")
    if ctx.attr.inject_system_variables:
        args.add("--inject-vars")
    if not ctx.attr.merge_other_files:
        args.add("--merge=false")
    if ctx.attr.output_package_name:
        args.add("--package", ctx.attr.output_package_name)
    elif ctx.attr.non_cue_file_package_name:  # TODO(seh): Remove this after deprecation period.
        args.add("--package", ctx.attr.non_cue_file_package_name)
    for p in ctx.attr.path:
        if not p:
            fail(msg = "path element must not be empty")
        args.add("--path", p)
    if ctx.attr.with_context:
        args.add("--with-context")

    if len(required_stamp_bindings) == 0:
        # Create an empty file, in order to unify the command that
        # consumes extra arguments when stamping is in effect.
        ctx.actions.write(
            stamped_args_file,
            "",
        )
    else:
        stamp_placeholders_file = ctx.actions.declare_file("{}-stamp-bindings".format(ctx.label.name))
        ctx.actions.write(
            stamp_placeholders_file,
            "\n".join([k + "=" + v for k, v in required_stamp_bindings.items()]),
        )
        args = ctx.actions.args()
        args.add("-prefix", "--inject ")
        args.add("-output", stamped_args_file.path)
        args.add(stamp_placeholders_file.path)
        args.add(ctx.info_file.path)  # stable-status.txt
        args.add(ctx.version_file.path)  # volatile-status.txt
        ctx.actions.run(
            executable = ctx.executable._replacer,
            arguments = [args],
            inputs = [
                stamp_placeholders_file,
                ctx.info_file,
                ctx.version_file,
            ],
            outputs = [stamped_args_file],
            mnemonic = "CUEReplaceStampBindings",
            progress_message = "Replacing injection placeholders with stamped values for {}".format(ctx.label.name),
        )

    lines = []
    srcs = list(ctx.files.srcs)
    for src in srcs:
        _collect_packageless_file_path(ctx, src, lines)
    for k, v in ctx.attr.qualified_srcs.items():
        file = _file_from_label_keyed_string_dict_key(k)
        if file in srcs:
            srcs.remove(file)
        if not v:
            _collect_packageless_file_path(ctx, file, lines)
            continue
        lines.append(v + ":")
        _collect_packageless_file_path(ctx, file, lines)
    ctx.actions.write(
        packageless_files_file,
        "\n".join(lines),
    )

def _cue_module_impl(ctx):
    module_file = ctx.file.file
    expected_module_file = "module.cue"
    if module_file.basename != expected_module_file:
        fail(msg = """supplied CUE module file is not named "{}"; got "{}" instead""".format(expected_module_file, module_file.basename))
    expected_module_directory = "cue.mod"

    directory = paths.basename(module_file.dirname)
    if directory != expected_module_directory:
        fail(msg = """supplied CUE module directory is not named "{}"; got "{}" instead""".format(expected_module_directory, directory))
    return [
        CUEModuleInfo(
            module_file = module_file,
            external_package_sources = depset(
                direct = ctx.files.srcs,
            ),
        ),
    ]

_cue_module = rule(
    implementation = _cue_module_impl,
    attrs = {
        "file": attr.label(
            doc = "module.cue file for this CUE module.",
            allow_single_file = [".cue"],
            mandatory = True,
        ),
        "srcs": attr.label_list(
            doc = """Source files defining external packages from the "gen," "pkg," and "usr" directories.""",
            allow_files = [".cue"],
        ),
    },
)

def cue_module(name = "cue.mod", **kwargs):
    file = kwargs.pop("file", "module.cue")

    _cue_module(
        name = name,
        file = file,
        **kwargs
    )

def _cue_module_root_directory_path(ctx, module):
    return paths.dirname(paths.dirname(_runfile_path(ctx, module.module_file)))

def _cue_instance_directory_path(ctx):
    if ctx.file.directory_of:
        f = ctx.file.directory_of
        runfile_path = _runfile_path(ctx, f)
        return runfile_path if f.is_directory else paths.dirname(runfile_path)
    return paths.dirname(_runfile_path(ctx, ctx.files.srcs[0]))

def _cue_instance_impl(ctx):
    ancestor_instance = None
    if CUEModuleInfo in ctx.attr.ancestor:
        module = ctx.attr.ancestor[CUEModuleInfo]
    else:
        ancestor_instance = ctx.attr.ancestor[CUEInstanceInfo]
        module = ancestor_instance.module
        for dep in ctx.attr.deps:
            instance = dep[CUEInstanceInfo]
            if instance.module != module:
                fail(msg = """dependency {} of instance {} is not part of CUE module "{}"; got "{}" instead""".format(dep, ctx.label, module, dep.module))

    instance_directory_path = _cue_instance_directory_path(ctx)
    module_root_directory = _cue_module_root_directory_path(ctx, module)
    if not (instance_directory_path == module_root_directory or
            # The CUE module may be at the root of the Bazel workspace.
            not module_root_directory or
            instance_directory_path.startswith(module_root_directory + "/")):
        fail(msg = "directory {} for instance {} is not dominated by the module root directory {}".format(
            instance_directory_path,
            ctx.label,
            module_root_directory,
        ))
    return [
        CUEInstanceInfo(
            directory_path = instance_directory_path,
            files = ctx.files.srcs,
            module = module,
            package_name = ctx.attr.package_name or paths.basename(instance_directory_path),
            transitive_files = depset(
                direct = ctx.files.srcs +
                         ([module.module_file] if not ancestor_instance else []),
                transitive = [instance.transitive_files for instance in (
                                 [dep[CUEInstanceInfo] for dep in ctx.attr.deps] +
                                 ([ancestor_instance] if ancestor_instance else [])
                             )] +
                             ([module.external_package_sources] if not ancestor_instance else []),
            ),
        ),
    ]

cue_instance = rule(
    implementation = _cue_instance_impl,
    attrs = {
        "ancestor": attr.label(
            doc = """Containing CUE instance or module root.

This value must refer either to a dominating target using the
cue_instance rule (or another rule that yields a CUEInstanceInfo
provider) or a dominating target using the cue_module rule (or another
rule that yields a CUEModuleInfo provider).
""",
            providers = [[CUEInstanceInfo], [CUEModuleInfo]],
            mandatory = True,
        ),
        "deps": attr.label_list(
            doc = """cue_instance targets to include in the evaluation.

These instances are those mentioned in import declarations in this
instance's CUE files.""",
            providers = [CUEInstanceInfo],
        ),
        "directory_of": attr.label(
            doc = """Directory designator to use as the instance directory.

If the given target is a directory, use that directly. If the given
target is a file, use the file's containing directory.

If left unspecified, use the directory containing the first CUE file
nominated in this cue_instance's "srcs" attribute.""",
            allow_single_file = True,
        ),
        "package_name": attr.string(
            doc = """Name of the CUE package to load for this instance.

If left unspecified, use the basename of the containing directory as
the CUE pacakge name.""",
        ),
        "srcs": attr.label_list(
            doc = "CUE input files that are part of the nominated CUE package.",
            mandatory = True,
            allow_empty = False,
            allow_files = [".cue"],
        ),
    },
)

def _call_rule_after(name, rule_fn, prepare_fns = [], **kwargs):
    for f in prepare_fns:
        kwargs = f(
            name = name,
            **kwargs
        )
    rule_fn(
        name = name,
        **kwargs
    )

def _collect_direct_file_sources(ctx):
    files = list(ctx.files.srcs)
    for k, _ in ctx.attr.qualified_srcs.items():
        file = _file_from_label_keyed_string_dict_key(k)
        if file not in files:
            files.append(file)
    return files

def _cue_standalone_runfiles_impl(ctx):
    return [
        DefaultInfo(runfiles = ctx.runfiles(
            files = _collect_direct_file_sources(ctx),
        )),
    ]

_cue_standalone_runfiles = rule(
    implementation = _cue_standalone_runfiles_impl,
    attrs = _add_common_source_consuming_attrs_to({}),
)

def _cue_module_runfiles_impl(ctx):
    module = ctx.attr.module[CUEModuleInfo]
    return [
        DefaultInfo(runfiles = ctx.runfiles(
            files = [module.module_file] +
                    _collect_direct_file_sources(ctx),
            transitive_files = depset(
                transitive = [module.external_package_sources] +
                             [dep[CUEInstanceInfo].transitive_files for dep in ctx.attr.deps],
            ),
        )),
    ]

_cue_module_runfiles = rule(
    implementation = _cue_module_runfiles_impl,
    attrs = _add_common_source_consuming_attrs_to({
        "deps": attr.label_list(
            doc = """cue_instance targets to include in the evaluation.

These instances are those mentioned in import declarations in this set
of CUE files.""",
            providers = [CUEInstanceInfo],
        ),
        "module": attr.label(
            doc = """CUE module within which these files sit.

This value must refer either to a target using the cue_module rule or
another rule that yields a CUEModuleInfo provider.""",
            providers = [CUEModuleInfo],
            mandatory = True,
        ),
    }),
)

def _cue_instance_runfiles_impl(ctx):
    instance = ctx.attr.instance[CUEInstanceInfo]
    return [
        DefaultInfo(runfiles = ctx.runfiles(
            files = _collect_direct_file_sources(ctx),
            transitive_files = depset(
                transitive = [instance.transitive_files],
            ),
        )),
    ]

_cue_instance_runfiles = rule(
    implementation = _cue_instance_runfiles_impl,
    attrs = _add_common_source_consuming_attrs_to({
        "instance": attr.label(
            doc = """CUE instance to export.
 
This value must refer either to a target using the cue_instance rule
or another rule that yields a CUEInstanceInfo provider.""",
            providers = [CUEInstanceInfo],
            mandatory = True,
        ),
    }),
)

_cue_toolchain_type = "//tools/cue:toolchain_type"

# TODO(seh): Consider feeding an argument for the
# "cue_cache_directory_path" parameter here by way of new rule
# attributes.
def _make_output_producing_action(ctx, cue_subcommand, mnemonic, description, augment_args = None, module_file = None, instance_directory_path = None, instance_package_name = None, cue_cache_directory_path = None):
    cue_tool = ctx.toolchains[_cue_toolchain_type].cueinfo.tool
    args = ctx.actions.args()
    if ctx.attr.cue_debug:
        args.add("-d", ctx.attr.cue_debug)
    if module_file:
        args.add("-m", _runfile_path(ctx, module_file))
        if instance_directory_path:
            args.add("-i", instance_directory_path)
            if instance_package_name:
                args.add("-p", instance_package_name)
    elif instance_directory_path:
        fail(msg = "CUE instance directory path provided without a module directory path")
    elif instance_package_name:
        fail(msg = "CUE package name provided without an instance directory path")
    if cue_cache_directory_path:
        args.add("-c", cue_cache_directory_path)
    args.add(cue_tool.path)
    args.add(cue_subcommand)
    stamped_args_file = ctx.actions.declare_file("%s-stamped-args" % ctx.label.name)
    args.add(stamped_args_file.path)
    packageless_files_file = ctx.actions.declare_file("%s-packageless-files" % ctx.label.name)
    args.add(packageless_files_file.path)
    args.add(ctx.outputs.result.path)
    _add_common_output_producing_args_to(ctx, args, stamped_args_file, packageless_files_file)

    if augment_args:
        augment_args(ctx, args)

    ctx.actions.run(
        executable = ctx.executable.cue_run,
        arguments = [args],
        inputs = [
            stamped_args_file,
            packageless_files_file,
        ],
        tools = [cue_tool],
        outputs = [ctx.outputs.result],
        mnemonic = mnemonic,
        progress_message = "Capturing the {} CUE configuration for target \"{}\"".format(description, ctx.label.name),
    )

def _make_module_based_output_producing_action(ctx, cue_subcommand, mnemonic, description, augment_args = None):
    module = ctx.attr.module[CUEModuleInfo]
    _make_output_producing_action(
        ctx,
        cue_subcommand,
        mnemonic,
        description,
        augment_args,
        module.module_file,
    )

def _make_instance_consuming_action(ctx, cue_subcommand, mnemonic, description, augment_args = None):
    instance = ctx.attr.instance[CUEInstanceInfo]

    # NB: If the input path is equal to the starting path, the
    # "paths.relativize" function returns the input path unchanged, as
    # opposed to returning "." to indicate that it's the same
    # directory.
    module_root_directory = _cue_module_root_directory_path(ctx, instance.module)
    relative_instance_path = paths.relativize(instance.directory_path, module_root_directory)
    if relative_instance_path == instance.directory_path:
        relative_instance_path = "."
    else:
        relative_instance_path = "./" + relative_instance_path

    _make_output_producing_action(
        ctx,
        cue_subcommand,
        mnemonic,
        description,
        augment_args,
        instance.module.module_file,
        relative_instance_path,
        instance.package_name,
    )

def _declare_cue_run_binary(name, runfiles_name, tags = []):
    native.config_setting(
        name = name + "_lacks_runfiles_directory",
        constraint_values = [
            Label("@platforms//os:windows"),
        ],
        visibility = ["//visibility:private"],
    )
    cue_run_name = name + "_cue_run_from_runfiles"
    sh_binary(
        name = cue_run_name,
        # NB: On Windows, we don't expect to have a runfiles directory
        # available, so instead we rely on a runfiles manifest to tell
        # us which files should be present where. We use a ZIP archive
        # to collect and project these runfiles into the right place.
        srcs = select({
            ":{}_lacks_runfiles_directory".format(name): [Label("//cue:cue-run-from-archived-runfiles")],
            "//conditions:default": [Label("//cue:cue-run-from-runfiles")],
        }),
        data = [":" + runfiles_name] + select({
            ":{}_lacks_runfiles_directory".format(name): ["@bazel_tools//tools/zip:zipper"],
            "//conditions:default": [],
        }),
        deps = ["@bazel_tools//tools/bash/runfiles"],
        tags = tags,
    )
    return cue_run_name

def _augment_consolidated_output_args(ctx, args):
    if ctx.attr.inline_imports:
        args.add("--inline-imports")
    args.add("--out", ctx.attr.output_format)

def _add_common_consolidated_output_attrs_to(attrs):
    attrs.update({
        "inline_imports": attr.bool(
            doc = "Expand references to non-core imports.",
            default = False,
        ),
        "output_format": attr.string(
            doc = "Output format",
            default = "cue",
            values = [
                "cue",
                "json",
                "text",
                "yaml",
            ],
        ),
        "result": attr.output(
            doc = """The built result in the format specified in the "output_format" attribute.""",
            mandatory = True,
        ),
    })
    return attrs

def _prepare_consolidated_output_rule(name, **kwargs):
    extension_by_format = {
        "cue": "cue",
        "json": "json",
        "text": "txt",
        "yaml": "yaml",
    }
    output_format = kwargs.get("output_format", "cue")
    result = kwargs.pop("result", name + "." + extension_by_format[output_format])
    return kwargs | {
        "result": result,
    }

def _prepare_module_consuming_rule(name, **kwargs):
    deps = kwargs.get("deps", [])
    module = kwargs["module"]
    qualified_srcs = kwargs.get("qualified_srcs", {})
    srcs = kwargs.get("srcs", [])
    tags = kwargs.get("tags", [])

    runfiles_name = name + "_cue_runfiles"
    _cue_module_runfiles(
        name = runfiles_name,
        deps = deps,
        module = module,
        srcs = srcs,
        qualified_srcs = qualified_srcs,
        tags = tags,
    )
    return kwargs | {
        "cue_run": ":" + _declare_cue_run_binary(name, runfiles_name, tags),
    }

def _prepare_instance_consuming_rule(name, **kwargs):
    instance = kwargs["instance"]
    qualified_srcs = kwargs.get("qualified_srcs", {})
    srcs = kwargs.get("srcs", [])
    tags = kwargs.get("tags", [])

    runfiles_name = name + "_cue_runfiles"
    _cue_instance_runfiles(
        name = runfiles_name,
        instance = instance,
        srcs = srcs,
        qualified_srcs = qualified_srcs,
        tags = tags,
    )
    return kwargs | {
        "cue_run": ":" + _declare_cue_run_binary(name, runfiles_name, tags),
    }

def _prepare_standalone_rule(name, **kwargs):
    qualified_srcs = kwargs.get("qualified_srcs", {})
    srcs = kwargs.get("srcs", [])
    tags = kwargs.get("tags", [])

    runfiles_name = name + "_cue_runfiles"
    _cue_standalone_runfiles(
        name = runfiles_name,
        srcs = srcs,
        qualified_srcs = qualified_srcs,
        tags = tags,
    )
    return kwargs | {
        "cue_run": ":" + _declare_cue_run_binary(name, runfiles_name, tags),
    }

def _cue_consolidated_standalone_files_impl(ctx):
    _make_output_producing_action(
        ctx,
        "def",
        "CUEDef",
        "consolidated",
        _augment_consolidated_output_args,
    )

_cue_consolidated_standalone_files = rule(
    implementation = _cue_consolidated_standalone_files_impl,
    attrs = _add_common_consolidated_output_attrs_to(_add_common_output_producing_attrs_to({})),
    toolchains = [_cue_toolchain_type],
)

def cue_consolidated_standalone_files(name, **kwargs):
    _call_rule_after(
        name,
        _cue_consolidated_standalone_files,
        [
            _prepare_standalone_rule,
            _prepare_consolidated_output_rule,
        ],
        **kwargs
    )

def _cue_consolidated_files_impl(ctx):
    _make_module_based_output_producing_action(ctx, "def", "CUEDef", "consolidated", _augment_consolidated_output_args)

_cue_consolidated_files = rule(
    implementation = _cue_consolidated_files_impl,
    attrs = _add_common_consolidated_output_attrs_to(_add_common_module_based_attrs_to({})),
    toolchains = [_cue_toolchain_type],
)

def cue_consolidated_files(name, **kwargs):
    _call_rule_after(
        name,
        _cue_consolidated_files,
        [
            _prepare_module_consuming_rule,
            _prepare_consolidated_output_rule,
        ],
        **kwargs
    )

def _cue_consolidated_instance_impl(ctx):
    _make_instance_consuming_action(ctx, "def", "CUEDef", "consolidated", _augment_consolidated_output_args)

_cue_consolidated_instance = rule(
    implementation = _cue_consolidated_instance_impl,
    attrs = _add_common_consolidated_output_attrs_to(_add_common_instance_consuming_attrs_to({})),
    toolchains = [_cue_toolchain_type],
)

def cue_consolidated_instance(name, **kwargs):
    _call_rule_after(
        name,
        _cue_consolidated_instance,
        [
            _prepare_instance_consuming_rule,
            _prepare_consolidated_output_rule,
        ],
        **kwargs
    )

def _augment_exported_output_args(ctx, args):
    if ctx.attr.escape:
        args.add("--escape")
    args.add("--out", ctx.attr.output_format)

def _add_common_exported_output_attrs_to(attrs):
    attrs.update({
        "escape": attr.bool(
            doc = "Use HTML escaping.",
            default = False,
        ),
        "output_format": attr.string(
            doc = "Output format",
            default = "json",
            values = [
                "cue",
                "json",
                "text",
                "yaml",
            ],
        ),
        "result": attr.output(
            doc = """The built result in the format specified in the "output_format" attribute.""",
            mandatory = True,
        ),
    })
    return attrs

def _prepare_exported_output_rule(name, **kwargs):
    extension_by_format = {
        "cue": "cue",
        "json": "json",
        "text": "txt",
        "yaml": "yaml",
    }
    output_format = kwargs.get("output_format", "json")
    result = kwargs.pop("result", name + "." + extension_by_format[output_format])
    return kwargs | {
        "result": result,
    }

def _cue_exported_standalone_files_impl(ctx):
    _make_output_producing_action(
        ctx,
        "export",
        "CUEExport",
        "exported",
        _augment_exported_output_args,
    )

_cue_exported_standalone_files = rule(
    implementation = _cue_exported_standalone_files_impl,
    attrs = _add_common_exported_output_attrs_to(_add_common_output_producing_attrs_to({})),
    toolchains = [_cue_toolchain_type],
)

def cue_exported_standalone_files(name, **kwargs):
    _call_rule_after(
        name,
        _cue_exported_standalone_files,
        [
            _prepare_standalone_rule,
            _prepare_exported_output_rule,
        ],
        **kwargs
    )

def _cue_exported_files_impl(ctx):
    _make_module_based_output_producing_action(ctx, "export", "CUEExport", "exported", _augment_exported_output_args)

_cue_exported_files = rule(
    implementation = _cue_exported_files_impl,
    attrs = _add_common_exported_output_attrs_to(_add_common_module_based_attrs_to({})),
    toolchains = [_cue_toolchain_type],
)

def cue_exported_files(name, **kwargs):
    _call_rule_after(
        name,
        _cue_exported_files,
        [
            _prepare_module_consuming_rule,
            _prepare_exported_output_rule,
        ],
        **kwargs
    )

def _cue_exported_instance_impl(ctx):
    _make_instance_consuming_action(ctx, "export", "CUEExport", "exported", _augment_exported_output_args)

_cue_exported_instance = rule(
    implementation = _cue_exported_instance_impl,
    attrs = _add_common_exported_output_attrs_to(_add_common_instance_consuming_attrs_to({})),
    toolchains = [_cue_toolchain_type],
)

def cue_exported_instance(name, **kwargs):
    _call_rule_after(
        name,
        _cue_exported_instance,
        [
            _prepare_instance_consuming_rule,
            _prepare_exported_output_rule,
        ],
        **kwargs
    )
