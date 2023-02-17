load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@bazel_skylib//rules:diff_test.bzl",
    "diff_test",
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

    diff_test(
        name = name + "_test",
        file1 = generated_output_file,
        file2 = golden_file,
        size = "small",
    )
