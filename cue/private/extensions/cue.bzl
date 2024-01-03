load(
    "//cue/private/tools/cue:toolchain.bzl",
    "download_tool",
    "known_release_versions",
)
load(
    ":download.bzl",
    "make_tag_class",
    "maximal_selected_version",
)

visibility("//cue")

def _cue_impl(ctx):
    download_tool(
        name = "cue_tool",
        version = maximal_selected_version(ctx, "cue"),
    )

cue = module_extension(
    implementation = _cue_impl,
    tag_classes = {
        "download": make_tag_class(known_release_versions()),
    },
)
