load(
    "//cue/private:config.bzl",
    "CUEConfigInfo",
)

CUEModuleInfo = provider(
    doc = "Collects files from cue_module targets for use by referring cue_instance targets.",
    fields = {
        "module_file": """The "module.cue" file in the module directory.""",
        "root": """The directory containing the "cue.mod" directory immediately containing the module file defining this CUE module.""",
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
        "transitive_instances": "The set of instances referenced by this instance.",
    },
)

def _basename(p):
    # Avoid dependency on Skylib's paths.basename function.
    return p.rpartition("/")[-1]

def _dirname(p):
    # Avoid dependency on Skylib's paths.dirname function.
    prefix, sep, _ = p.rpartition("/")
    if not prefix:
        return sep
    else:
        return prefix.rstrip("/")

def _replacer_if_stamping(stamping_policy):
    # NB: We can't access the "_cue_config" attribute here.
    return Label("//tools/cmd/replace-stamps") if stamping_policy != "Never" else None

def _add_common_instance_consuming_attrs_to(attrs):
    attrs.update({
        "_cue": attr.label(
            default = "//cue:cue_runtime",
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),
        "_cue_config": attr.label(
            default = "//:cue_config",
        ),
        "_replacer": attr.label(
            default = _replacer_if_stamping,
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),
        "_zipper": attr.label(
            default = Label("@bazel_tools//tools/zip:zipper"),
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),
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
        "expression": attr.string(
            doc = "CUE expression selecting a single value to export.",
            default = "",
        ),
        "instance": attr.label(
            doc = """CUE instance to export.

This value must refer either to a target using the cue_instance rule
or another rule that yields a CUEInstanceInfo provider.
""",
            providers = [CUEInstanceInfo],
            mandatory = True,
        ),
        "inject": attr.string_dict(
            doc = "Keys and values of tagged fields.",
        ),
        "inject_shorthand": attr.string_list(
            doc = "Shorthand values of tagged fields.",
        ),
        "concatenate_objects": attr.bool(
            doc = "Concatenate multiple objects into a list.",
        ),
        "merge_other_files": attr.bool(
            doc = "Merge non-CUE files.",
            default = True,
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

def _file_from_label_keyed_string_dict_key(k):
    # NB: The Targets in a label_keyed_string_dict attribute have the key's
    # source file in a depset, as opposed being represented directly as in a
    # label_list attribute.
    files = k.files.to_list()
    if len(files) != 1:
        fail(msg = "Unexpected number of files in target {}: {}".format(k, len(files)))
    return files[0]

def _file_path_in_zip_archive(file):
    return file.short_path

def _collect_packageless_file_path(file, lines):
    p = _file_path_in_zip_archive(file)
    if p.find(":") != -1:
        fail(msg = "CUE rejects file paths that contain a colon (:): {}".format(p))
    lines.append(p + "\n")

def _add_common_instance_consuming_args_to(ctx, args, stamped_args_file, packageless_files_file):
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
    if not ctx.attr.merge_other_files:
        args.add("--merge=false")
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

    # NB: We need to be able to map these source file paths from
    # relative paths to absolute paths, or at least adjust them to be
    # relative to whichever working directory within the CUE module we
    # choose.
    lines = []
    srcs = list(ctx.files.srcs)
    for k, v in ctx.attr.qualified_srcs.items():
        file = _file_from_label_keyed_string_dict_key(k)
        if file in srcs:
            srcs.remove(file)
        if not v:
            _collect_packageless_file_path(file, lines)
            continue
        lines.append(v + ":")
        _collect_packageless_file_path(file, lines)
    for src in srcs:
        _collect_packageless_file_path(src, lines)
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

    directory = _basename(module_file.dirname)
    if directory != expected_module_directory:
        fail(msg = """supplied CUE module directory is not named "{}"; got "{}" instead""".format(expected_module_directory, directory))
    return [
        CUEModuleInfo(
            module_file = ctx.file.file,
            root = _dirname(module_file.dirname),
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

def _cue_instance_directory_path(ctx):
    if ctx.file.directory_of:
        f = ctx.file.directory_of
        return f.short_path if f.is_directory else f.dirname
    return ctx.label.package

def _cue_instance_impl(ctx):
    if CUEModuleInfo in ctx.attr.ancestor:
        module = ctx.attr.ancestor[CUEModuleInfo]
    else:
        module = ctx.attr.ancestor[CUEInstanceInfo].module
        for dep in ctx.attr.deps:
            instance = dep[CUEInstanceInfo]
            if instance.module != module:
                fail(msg = """dependency {} of instance {} is not part of CUE module "{}"; got "{}" instead""".format(dep, ctx.label, module, dep.module))

    instance_directory_path = _cue_instance_directory_path(ctx)
    if not (instance_directory_path == module.root or
            # The CUE module may be at the root of the Bazel workspace.
            not module.root or
            instance_directory_path.startswith(module.root + "/")):
        fail(msg = "directory {} for instance {} is not dominated by the module root directory {}".format(
            instance_directory_path,
            ctx.label,
            module.root,
        ))

    return [
        CUEInstanceInfo(
            directory_path = instance_directory_path,
            files = ctx.files.srcs,
            module = module,
            package_name = ctx.attr.package_name or _basename(instance_directory_path),
            transitive_instances = depset(
                direct = ctx.attr.deps,
                transitive = [dep[CUEInstanceInfo].transitive_instances for dep in ctx.attr.deps],
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

If left unspecified, use the Bazel package directory defining this
cue_instance.""",
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

def _make_zip_archive_of(ctx, files):
    zip_manifest_file = ctx.actions.declare_file("{}-manifest".format(ctx.label.name))
    ctx.actions.write(
        zip_manifest_file,
        "".join(["{}={}\n".format(_file_path_in_zip_archive(f), f.path) for f in files]),
    )
    source_zip_file = ctx.actions.declare_file(ctx.label.name + ".zip")

    args = ctx.actions.args()
    args.add("c")
    args.add(source_zip_file.path)
    args.add("@" + zip_manifest_file.path)
    ctx.actions.run(
        executable = ctx.executable._zipper,
        arguments = [args],
        inputs = files + [zip_manifest_file],
        outputs = [source_zip_file],
        mnemonic = "CUECollectSourceZIPFile",
        progress_message = "Collecting source files from CUE module for instance \"{}\"".format(ctx.label.name),
    )
    return source_zip_file

def _make_instance_consuming_action(ctx, cue_subcommand, mnemonic, description, augment_args = None):
    files = list(ctx.files.srcs)
    for k, v in ctx.attr.qualified_srcs.items():
        file = _file_from_label_keyed_string_dict_key(k)
        if file not in files:
            files.append(file)

    instance = ctx.attr.instance[CUEInstanceInfo]
    files.extend(instance.files)
    files.append(instance.module.module_file)
    files.extend(instance.module.external_package_sources.to_list())
    for dep in instance.transitive_instances.to_list():
        files.extend(dep[CUEInstanceInfo].files)

    # NB: CUE needs all the source files within the module to sit
    # within the directory that contains the "cue.mod"
    # directory. Bazel splits the static source files from the
    # generated files, and won't present them in a combined directory
    # tree. Creating symbolic links from generated files to the static
    # files or vice versa is difficult, because Bazel actions can only
    # create actions in the target's package.
    #
    # To work around these limitations, we collect all the source
    # files—both static and generated—into a ZIP archive, then expand
    # that archive in the root directory of a new action.
    #
    # One more difficulty arises: CUE requires that its current
    # working directory be within the module's directory tree. We have
    # to change into a directory within that tree, and adjust the
    # various relative paths that Bazel hands us.
    source_zip_file = _make_zip_archive_of(ctx, files)
    args = ctx.actions.args()
    args.add(ctx.executable._cue.path)
    args.add(cue_subcommand)
    args.add(source_zip_file.path)
    args.add(instance.directory_path)
    args.add(instance.package_name)
    stamped_args_file = ctx.actions.declare_file("%s-stamped-args" % ctx.label.name)
    args.add(stamped_args_file.path)
    packageless_files_file = ctx.actions.declare_file("%s-packageless-files" % ctx.label.name)
    args.add(packageless_files_file.path)
    args.add(ctx.outputs.result.path)
    _add_common_instance_consuming_args_to(ctx, args, stamped_args_file, packageless_files_file)

    if augment_args:
        augment_args(ctx, args)

    ctx.actions.run_shell(
        inputs = [
            source_zip_file,
            stamped_args_file,
            packageless_files_file,
        ],
        tools = [ctx.executable._cue],
        outputs = [ctx.outputs.result],
        command = """\
set -e -u -o pipefail

cue=$1; shift
subcommand=$1; shift
source_zip_file=$1; shift
instance_path=$1; shift
package_name=$1; shift
extra_args_file=$1; shift
packageless_files_file=$1; shift
output_file=$1; shift

unzip -q "${source_zip_file}"

oldwd="${PWD}"
cd "${instance_path}"

packageless_file_args=()
qualifier=
while read -r line; do
  if [ -z "${line}" ]; then
    continue
  fi
  if [[ "${line}" =~ .+:$ ]]; then
    qualifier="${line}"
  else
    if [ -n "${qualifier}" ]; then
      packageless_file_args+=("${qualifier}")
      qualifier=
    fi
    packageless_file_args+=("${oldwd}/${line}")
  fi
done < "${oldwd}/${packageless_files_file}"
if [ -n "${qualifier}" ]; then
  echo "No file path followed qualifier \"${qualifier}\"." 1>&2
  exit 1
fi

"${oldwd}/${cue}" "${subcommand}" --outfile "${oldwd}/${output_file}" \
  ".${package_name:+:${package_name}}" \
  "${packageless_file_args[@]}" \
  $(< "${oldwd}/${extra_args_file}") \
  "${@-}"
""",
        arguments = [args],
        mnemonic = mnemonic,
        progress_message = "Capturing the {} CUE configuration for instance \"{}\"".format(description, ctx.label.name),
    )

def _augment_consolidated_instance_args(ctx, args):
    args.add("--out", ctx.attr.output_format)

def _cue_consolidated_instance_impl(ctx):
    _make_instance_consuming_action(ctx, "def", "CUEDef", "consolidated", _augment_consolidated_instance_args)

_cue_consolidated_instance = rule(
    implementation = _cue_consolidated_instance_impl,
    attrs = _add_common_instance_consuming_attrs_to({
        "output_format": attr.string(
            doc = "Output format",
            default = "cue",
            values = [
                # TODO(seh): Consider relaxing this set.
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
    }),
)

def cue_consolidated_instance(name, **kwargs):
    extension_by_format = {
        "cue": "cue",
        "json": "json",
        "text": "txt",
        "yaml": "yaml",
    }
    output_format = kwargs.get("output_format", "cue")
    result = kwargs.pop("result", name + "." + extension_by_format[output_format])

    _cue_consolidated_instance(
        name = name,
        result = result,
        **kwargs
    )

def _augment_exported_instance_args(ctx, args):
    if ctx.attr.escape:
        args.add("--escape")
    args.add("--out", ctx.attr.output_format)

def _cue_exported_instance_impl(ctx):
    _make_instance_consuming_action(ctx, "export", "CUEExport", "exported", _augment_exported_instance_args)

_cue_exported_instance = rule(
    implementation = _cue_exported_instance_impl,
    attrs = _add_common_instance_consuming_attrs_to({
        "escape": attr.bool(
            doc = "Use HTML escaping.",
            default = False,
        ),
        "output_format": attr.string(
            doc = "Output format",
            default = "json",
            values = [
                # TODO(seh): Consider relaxing this set.
                "json",
                "text",
                "yaml",
            ],
        ),
        "result": attr.output(
            doc = """The built result in the format specified in the "output_format" attribute.""",
            mandatory = True,
        ),
    }),
)

def cue_exported_instance(name, **kwargs):
    extension_by_format = {
        "json": "json",
        "text": "txt",
        "yaml": "yaml",
    }
    output_format = kwargs.get("output_format", "json")
    result = kwargs.pop("result", name + "." + extension_by_format[output_format])

    _cue_exported_instance(
        name = name,
        result = result,
        **kwargs
    )
