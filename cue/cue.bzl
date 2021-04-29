load(
    "@io_bazel_rules_go//go/private:common.bzl",
    "env_execute",
)
load(
    "//cue/private:config.bzl",
    "CUEConfigInfo",
)

CUEPkgInfo = provider(
    doc = "Collects files from cue_library for use in downstream cue_export",
    fields = {
        "transitive_pkgs": "CUE pkg ZIP files for this target and its dependencies",
    },
)

def _path_in_zip_file(f):
    return f.short_path

def _collect_transitive_pkgs(pkg, deps):
    "CUE evaluation requires all transitive .cue source files"
    return depset(
        [pkg],
        transitive = [dep[CUEPkgInfo].transitive_pkgs for dep in deps],
        # Provide .cue sources from dependencies first
        order = "postorder",
    )

def _replacer_if_stamping(stamping_policy):
    # NB: We can't access the "_cue_config" attribute here.
    return Label("//tools/cmd/replace-stamps") if stamping_policy != "Never" else None

def _add_common_attrs_to(attrs):
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
        "srcs": attr.label_list(
            doc = "Input files.",
            mandatory = True,
            allow_empty = False,
            allow_files = True,
        ),
        "deps": attr.label_list(
            doc = "cue_library targets to include in the evaluation",
            providers = [CUEPkgInfo],
            allow_files = False,
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

def _add_common_args(ctx, args, stamped_args_file):
    cue_config = ctx.attr._cue_config[CUEConfigInfo]
    stamping_enabled = ctx.attr.stamping_policy == "Force" or ctx.attr.stamping_policy == "Allow" and cue_config.stamp
    required_stamp_bindings = {}

    # TODO(seh): Consider these:
    #if ctx.attr.simplify:
    #    args.add("--simplify")
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
    args.add_all(ctx.files.srcs, map_each = _path_in_zip_file)

    if len(required_stamp_bindings) == 0:
        # Create an empty file, in order to unify the command that
        # consumes extra arguments when stamping is in effect.
        ctx.actions.write(
            stamped_args_file,
            "",
        )
    else:
        stamp_placeholders_file = ctx.actions.declare_file("%s-stamp-bindings" % ctx.label.name)
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

def _zip_src(ctx, srcs):
    # Generate a ZIP file containing the files in srcs.

    zipper_list_content = "".join([_path_in_zip_file(src) + "=" + src.path + "\n" for src in srcs])
    zipper_list = ctx.actions.declare_file(ctx.label.name + "~zipper.txt")
    ctx.actions.write(zipper_list, zipper_list_content)

    src_zip = ctx.actions.declare_file(ctx.label.name + "~src.zip")

    args = ctx.actions.args()
    args.add("c")
    args.add(src_zip.path)
    args.add("@" + zipper_list.path)

    ctx.actions.run(
        mnemonic = "zipper",
        executable = ctx.executable._zipper,
        arguments = [args],
        inputs = [zipper_list] + srcs,
        outputs = [src_zip],
        use_default_shell_env = True,
    )

    return src_zip

def _pkg_merge(ctx, src_zip):
    merged = ctx.actions.declare_file(ctx.label.name + "~merged.zip")

    args = ctx.actions.args()
    args.add_joined(["-o", merged.path], join_with = "=")
    inputs = depset(
        [src_zip],
        transitive = [dep[CUEPkgInfo].transitive_pkgs for dep in ctx.attr.deps],
        # Provide .cue sources from dependencies first
        order = "postorder",
    )
    for dep in inputs.to_list():
        args.add(dep.path)

    ctx.actions.run(
        mnemonic = "CUEPkgMerge",
        executable = ctx.executable._zipmerge,
        arguments = [args],
        inputs = inputs,
        outputs = [merged],
        use_default_shell_env = True,
    )

    return merged

def _cue_def(ctx):
    "CUE def library"
    srcs_zip = _zip_src(ctx, ctx.files.srcs)
    merged = _pkg_merge(ctx, srcs_zip)
    def_out = ctx.actions.declare_file(ctx.label.name + "~def.cue")

    args = ctx.actions.args()
    args.add(ctx.executable._cue.path)
    args.add(merged.path)
    stamped_args_file = ctx.actions.declare_file("%s-stamped-args" % ctx.label.name)
    args.add(stamped_args_file.path)
    args.add(def_out.path)
    _add_common_args(ctx, args, stamped_args_file)

    ctx.actions.run_shell(
        mnemonic = "CUEDef",
        tools = [ctx.executable._cue],
        arguments = [args],
        command = """\
set -euo pipefail

CUE=$1; shift
PKGZIP=$1; shift
EXTRA_ARGS=$1; shift
OUT=$1; shift

unzip -q "${PKGZIP}"
"${CUE}" def --outfile "${OUT}" $(< "${EXTRA_ARGS}") "${@}"
""",
        inputs = [
            merged,
            stamped_args_file,
        ],
        outputs = [def_out],
        use_default_shell_env = True,
    )

    return def_out

def _cue_library_impl(ctx):
    """cue_library validates a CUE package, bundles up the files into a
    ZIP file, and collects all transitive dependencies' ZIP file.
    Args:
      ctx: The Bazel build context
    Returns:
      The cue_library rule.
    """

    def_out = _cue_def(ctx)

    # Create the manifest input to zipper
    projected_path_prefix = "pkg/" + ctx.attr.importpath.split(":")[0]
    # TODO(seh): Should we include the "def_out" file in this manifest?
    manifest = "".join([projected_path_prefix + "/" + src.basename + "=" + src.path + "\n" for src in ctx.files.srcs])
    manifest_file = ctx.actions.declare_file(ctx.label.name + "~manifest")
    ctx.actions.write(manifest_file, manifest)

    pkg = ctx.actions.declare_file(ctx.label.name + ".zip")

    args = ctx.actions.args()
    args.add("c")
    args.add(pkg.path)
    args.add("@" + manifest_file.path)

    ctx.actions.run(
        mnemonic = "CUEPkg",
        outputs = [pkg],
        inputs = [def_out, manifest_file] + ctx.files.srcs,
        executable = ctx.executable._zipper,
        arguments = [args],
    )

    return [
        DefaultInfo(
            files = depset([pkg]),
            runfiles = ctx.runfiles(files = [pkg]),
        ),
        CUEPkgInfo(
            transitive_pkgs = depset(
                [pkg],
                transitive = [dep[CUEPkgInfo].transitive_pkgs for dep in ctx.attr.deps],
                # Provide .cue sources from dependencies first
                order = "postorder",
            ),
        ),
    ]

_cue_library_attrs = _add_common_attrs_to({
    "importpath": attr.string(
        doc = "CUE import path under pkg/",
        mandatory = True,
    ),
    "_zipper": attr.label(
        default = Label("@bazel_tools//tools/zip:zipper"),
        executable = True,
        allow_single_file = True,
        cfg = "exec",
    ),
    "_zipmerge": attr.label(
        default = Label("@io_rsc_zipmerge//:zipmerge"),
        executable = True,
        allow_single_file = True,
        cfg = "exec",
    ),
})

cue_library = rule(
    implementation = _cue_library_impl,
    attrs = _cue_library_attrs,
)

def _cue_export(ctx, merged, output):
    """_cue_export performs an action to export a set of input files."""

    # The CUE CLI expects inputs like
    # cue export <flags> <input_filename>
    args = ctx.actions.args()
    args.add(ctx.executable._cue.path)
    args.add(merged.path)
    stamped_args_file = ctx.actions.declare_file("%s-stamped-args" % ctx.label.name)
    args.add(stamped_args_file.path)
    args.add(output.path)

    if ctx.attr.escape:
        args.add("--escape")
    args.add("--out=" + ctx.attr.output_format)
    _add_common_args(ctx, args, stamped_args_file)

    ctx.actions.run_shell(
        mnemonic = "CUEExport",
        tools = [ctx.executable._cue],
        arguments = [args],
        command = """
set -euo pipefail

CUE=$1; shift
PKGZIP=$1; shift
EXTRA_ARGS=$1; shift
OUT=$1; shift

unzip -q "${PKGZIP}"
${CUE} export --outfile "${OUT}" $(< "${EXTRA_ARGS}") "${@}"
""",
        inputs = [
            merged,
            stamped_args_file,
        ],
        outputs = [output],
        use_default_shell_env = True,
    )

def _cue_export_impl(ctx):
    src_zip = _zip_src(ctx, ctx.files.srcs)
    merged = _pkg_merge(ctx, src_zip)
    _cue_export(ctx, merged, ctx.outputs.export)
    return DefaultInfo(
        files = depset([ctx.outputs.export]),
        runfiles = ctx.runfiles(files = [ctx.outputs.export]),
    )

def _strip_extension(path):
    """Removes the final extension from a path."""
    components = path.split(".")
    components.pop()
    return ".".join(components)

def _cue_export_outputs(srcs, output_name, output_format):
    """Get map of cue_export outputs.
    Note that the arguments to this function are named after attributes on the rule.
    Args:
      srcs: The rule's `srcs` attribute
      output_name: The rule's `output_name` attribute
      output_format: The rule's `output_format` attribute
    Returns:
      Outputs for the cue_export
    """
    extension_by_format = {
        "json": "json",
        "text": "txt",
        "yaml": "yaml",
    }
    outputs = {
        "export": output_name or _strip_extension(srcs[0].name) + "." + extension_by_format[output_format],
    }

    return outputs

_cue_export_attrs = _add_common_attrs_to({
    "escape": attr.bool(
        doc = "Use HTML escaping.",
        default = False,
    ),

    #debug            give detailed error info
    #ignore           proceed in the presence of errors
    #simplify         simplify output
    #trace            trace computation
    #verbose          print information about progress
    "output_name": attr.string(
        doc = """Name of the output file, including the extension.
By default, this is based on the first entry in the `srcs` attribute:
if `foo.cue` is the first value in `srcs` then the output file is
`foo.json.`.  You can override this to be any other name.  Note that
some tooling may assume that the output name is derived from the input
name, so use this attribute with caution.""",
    ),
    "output_format": attr.string(
        doc = "Output format",
        default = "json",
        values = [
            "json",
            "text",
            "yaml",
        ],
    ),
    "_zipper": attr.label(
        default = Label("@bazel_tools//tools/zip:zipper"),
        executable = True,
        allow_single_file = True,
        cfg = "host",
    ),
    "_zipmerge": attr.label(
        default = Label("@io_rsc_zipmerge//:zipmerge"),
        executable = True,
        allow_single_file = True,
        cfg = "host",
    ),
})

cue_export = rule(
    implementation = _cue_export_impl,
    attrs = _cue_export_attrs,
    outputs = _cue_export_outputs,
)

# Copied from @bazel_tools//tools/build_defs/repo:utils.bzl
def _patch(ctx):
    """Implementation of patching an already extracted repository"""
    bash_exe = ctx.os.environ["BAZEL_SH"] if "BAZEL_SH" in ctx.os.environ else "bash"
    for patchfile in ctx.attr.patches:
        command = "{patchtool} {patch_args} < {patchfile}".format(
            patchtool = ctx.attr.patch_tool,
            patchfile = ctx.path(patchfile),
            patch_args = " ".join([
                "'%s'" % arg
                for arg in ctx.attr.patch_args
            ]),
        )
        st = ctx.execute([bash_exe, "-c", command])
        if st.return_code:
            fail("Error applying patch %s:\n%s%s" %
                 (str(patchfile), st.stderr, st.stdout))
    for cmd in ctx.attr.patch_cmds:
        st = ctx.execute([bash_exe, "-c", cmd])
        if st.return_code:
            fail("Error applying patch command %s:\n%s%s" %
                 (cmd, st.stdout, st.stderr))

# We can't disable timeouts on Bazel, but we can set them to large values.
_CUE_REPOSITORY_TIMEOUT = 86400

def _cue_repository_impl(ctx):
    # Download the repository archive
    ctx.download_and_extract(
        url = ctx.attr.urls,
        sha256 = ctx.attr.sha256,
        stripPrefix = ctx.attr.strip_prefix,
        type = ctx.attr.type,
    )

    # Repository is fetched. Determine if build file generation is needed.
    build_file_names = ctx.attr.build_file_name.split(",")
    existing_build_file = ""
    for name in build_file_names:
        path = ctx.path(name)
        if path.exists and not env_execute(ctx, ["test", "-f", path]).return_code:
            existing_build_file = name
            break

    generate = (ctx.attr.build_file_generation == "on" or (not existing_build_file and ctx.attr.build_file_generation == "auto"))

    if generate:
        # Build file generation is needed. Populate Gazelle directive at root build file
        build_file_name = existing_build_file or build_file_names[0]
        if len(ctx.attr.build_directives) > 0:
            ctx.file(
                build_file_name,
                "\n".join(["# " + d for d in ctx.attr.build_directives]),
            )

        # Run Gazelle
        _gazelle = "@com_github_tnarg_rules_cue//:gazelle_binary"
        gazelle = ctx.path(Label(_gazelle))
        cmd = [
            gazelle,
            "-cue_repository_mode",
            "-cue_prefix",
            ctx.attr.importpath,
            "-mode",
            "fix",
            "-repo_root",
            ctx.path(""),
        ]
        if ctx.attr.build_config:
            cmd.extend(["-repo_config"], ctx.path(ctx.attr.build_config))
        if ctx.attr.build_file_name:
            cmd.extend(["-build_file_name", ctx.attr.build_file_name])
        cmd.extend(ctx.attr.build_extra_args)
        cmd.append(ctx.path(""))
        result = env_execute(ctx, cmd, timeout = _CUE_REPOSITORY_TIMEOUT)
        if result.return_code:
            fail("failed to generate BUILD files for %s: %s" % (
                ctx.attr.importpath,
                result.stderr,
            ))
        if result.stderr:
            print("%s: %s" % (ctx.name, result.stderr))

    _patch(ctx)

cue_repository = repository_rule(
    implementation = _cue_repository_impl,
    attrs = {
        # Fundamental attributes of a CUE repository.
        "importpath": attr.string(mandatory = True),

        # Attributes for a repository that should be downloaded via HTTP.
        "urls": attr.string_list(),
        "strip_prefix": attr.string(),
        "type": attr.string(),
        "sha256": attr.string(),

        # Attributes for a repository that needs automatic BUILD file generation.
        "build_file_name": attr.string(default = "BUILD.bazel,BUILD"),
        "build_file_generation": attr.string(
            default = "auto",
            values = [
                "on",
                "auto",
                "off",
            ],
        ),
        "build_extra_args": attr.string_list(),
        "build_config": attr.label(),
        "build_directives": attr.string_list(default = []),

        # Patches to apply after running gazelle.
        "patches": attr.label_list(),
        "patch_tool": attr.string(default = "patch"),
        "patch_args": attr.string_list(default = ["-p0"]),
        "patch_cmds": attr.string_list(default = []),
    },
)
