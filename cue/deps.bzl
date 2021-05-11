load(
    "@bazel_tools//tools/build_defs/repo:http.bzl",
    "http_archive",
)
load(
    "@bazel_gazelle//:deps.bzl",
    "go_repository",
)
load(
    "@bazel_skylib//:workspace.bzl",
    "bazel_skylib_workspace",
)

def cue_rules_dependencies():
    bazel_skylib_workspace()
