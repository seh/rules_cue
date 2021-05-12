load(
    "//cue:cue.bzl",
    "cue_instance",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

def cue_test(
        name,
        generated_output_file,
        golden_file = None):
    if not golden_file:
        base, extension = paths.split_extension(generated_output_file)
        parts = base.rpartition(":")
        if parts[1] == ":":
            base = parts[0]
            golden_basename_prefix = parts[2] + "-"
        else:
            base = parts[2]
            golden_basename_prefix = ""
        golden_file = "{}:{}golden{}".format(base, golden_basename_prefix, extension)

    native.sh_test(
        name = name + "_test",
        srcs = ["diff-test-runner"],
        args = [
            "$(location %s)" % golden_file,
            "$(location %s)" % generated_output_file,
        ],
        data = [
            generated_output_file,
            golden_file,
        ],
        #        size = "small",
    )
