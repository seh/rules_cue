visibility("//cue/...")

# Returns the path of a runfile that can be used to look up its
# absolute path via the rlocation function provided by Bazel's
# runfiles libraries.
#
# See https://github.com/bazelbuild/bazel/issues/17259 for making a
# function like this available within Bazel or Skylib.
#
# Basis of inspiration: https://github.com/bazelbuild/rules_fuzzing/blob/22a866a3c98f374ab3284a7d26fc8318c17a711c/fuzzing/private/util.bzl#L39-L42
def runfile_path(ctx, runfile):
    # For files that sit within the same containing repository, the
    # short path will match the corresponding label's unqualified
    # package name relative to the repository root. For files that sit
    # within a different repository, the short path will start with
    # "../<canonical repository name>" in order to escape upward out
    # of the current repository's directory tree.
    #
    # Alternate implementation:
    # return paths.normalize(paths.join(ctx.workspace_name, runfile.short_path))
    p = runfile.short_path
    return p[3:] if p.startswith("../") else ctx.workspace_name + "/" + p
