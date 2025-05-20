load(
    "//cue:providers.bzl",
    "CUEModuleInfo",
)

visibility("//cue/...")

def _cue_module_cache_impl(ctx):
    content_lines = []
    content_lines.append(str(ctx.path(".")))
    file_name = "cache.txt"
    ctx.file(file_name, "\n".join(content_lines))
    ctx.file("BUILD.bazel", "exports_files([\"{}\"])".format(file_name))

    # TODO(seh): Download CUE module content.
    ctx.watch(ctx.attr.root.same_package_label("module.cue"))

cue_module_cache = repository_rule(
    implementation = _cue_module_cache_impl,
    doc = "TODO(seh): Document this",
    attrs = {
        "root": attr.label(
            doc = "cue_module target for which to cache CUE modules on which it depends.",
            providers = [CUEModuleInfo],
        ),
        # TODO(seh): Consider Gazelle's "go_repository"'s "local_path" attribute.
    },
)
