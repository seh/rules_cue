CUEConfigInfo = provider(
    doc = "CUE-related build configuration summary",
    fields = {
        "stamp": "Whether stamping is enabled for this build.",
    },
)

def _cue_config_impl(ctx):
    return [CUEConfigInfo(
        stamp = ctx.attr.stamp,
    )]

cue_config = rule(
    doc = "Collects information about the buildsettings in the current configuration.",
    implementation = _cue_config_impl,
    attrs = {
        "stamp": attr.bool(
            doc = "Whether stamping is enabled for this build.",
            mandatory = True,
        ),
    },
    provides = [CUEConfigInfo],
)
