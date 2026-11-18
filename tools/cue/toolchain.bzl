visibility("public")

CUEInfo = provider(
    doc = 'Details pertaining to the toolchain for the "cue" tool.',
    fields = {
        "tool": 'The "cue" tool to invoke',
        "version": "This tool's released version name",
    },
)

def _toolchain_impl(ctx):
    toolchain_info = platform_common.ToolchainInfo(
        cueinfo = CUEInfo(
            tool = ctx.executable.binary,
            version = ctx.attr.version,
        ),
    )
    return [toolchain_info]

cue_toolchain = rule(
    implementation = _toolchain_impl,
    doc = 'Defines a toolchain for the "cue" tool.',
    attrs = {
        "binary": attr.label(
            mandatory = True,
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = 'The "cue" tool to invoke',
        ),
        "version": attr.string(
            mandatory = True,
            doc = "This tool's released version name",
        ),
    },
)
