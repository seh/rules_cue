load(
    ":semver.bzl",
    "semver",
)

visibility("private")

def make_tag_class(accepted_versions):
    return tag_class(
        attrs = {
            "version": attr.string(values = accepted_versions),
            "tolerate_newer": attr.bool(default = True),
        },
    )

def maximal_selected_version(ctx, tool_name):
    max_version = None
    reached_max_version_limit = False
    for mod in ctx.modules:
        for download in mod.tags.download:
            raw_version = download.version
            c = semver.to_comparable(raw_version[1:] if raw_version.startswith("v") else raw_version)
            if max_version:
                if c > max_version[1]:
                    if reached_max_version_limit:
                        fail("{} version {} requested by module \"{}\" exceeds maximum tolerated version {}".format(tool_name, raw_version, mod.name, max_version[0]))
                    max_version = (raw_version, c)
                    reached_max_version_limit = not download.tolerate_newer
                elif c < max_version[1] and not download.tolerate_newer:
                    # NB: This module's tag may not be the maximum
                    # tolerated version, because a later tag (in this
                    # module or any other) could require an even lower
                    # version. We don't bother sorting the full set
                    # ahead of time.
                    fail("{} version {} exceeds tolerated version {}".format(tool_name, max_version[0], raw_version))
            else:
                max_version = (raw_version, c)
                reached_max_version_limit = not download.tolerate_newer

    return max_version[0] if max_version else None
