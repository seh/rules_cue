# CUE Rules for Bazel

## Rules
* [cue_export](#cue_export)
* [cue_library](#cue_library)

## Overview
These build rules are used for building [CUE][cue] projects with Bazel.

[cue]: https://cuelang.org/

## Setup
To use the CUE rules, add the following to your
`WORKSPACE` file to add the external repositories for CUE, making sure to use the latest
published versions:

```py
http_archive(
    name = "com_github_tnarg_rules_cue",
    # Make sure to check for the latest version when you install
    url = "https://github.com/tnarg/rules_cue/archive/b49de6e8b29427e879dff9950ed04d0df2d49f25.zip",
    strip_prefix = "rules_cue-b49de6e8b29427e879dff9950ed04d0df2d49f25",
    sha256 = "dd3f3cd6c1d66cf77e20af60a4c309d34039c2727baeafbad72ddd13aec5414a",
)

load(
    "@com_github_tnarg_rules_cue//cue:deps.bzl",
    "cue_register_toolchains",
    "cue_rules_dependencies",
)

cue_register_toolchains()
cue_rules_dependencies()
```


## Build Rule Reference

<a name="reference-cue_export"></a>
### cue_export

```py
cue_export(name, src, deps=[], output_format=<format>", output_name=<src_filename.cue>)
```

Exports one or more entry-point files. The entry-point files may have
dependencies (`cue_library` rules, see below).

| Attribute             | Description                                                             |
|-----------------------|-------------------------------------------------------------------------|
| `name`                | Unique name for this rule (required).                                   |
| `srcs`                | Entry-point files (required).                                           |
| `deps`                | List of dependencies for the `src`. Each dependency is a `cue_library`. |
| `concatenate_objects` | Concatenate multiple objects into a list.                               |
| `escape`              | Use HTML escaping.                                                      |
| `expression`          | CUE expression selecting a single value to export.                      |
| `inject`              | Keys and values of tagged fields.                                       |
| `inject_shorthand`    | Shorthand values of tagged fields.                                      |
| `merge_other_files`   | Merge non-CUE files.                                                    |
| `path`                | Elements of CUE path at which to place top-level values.                |
| `stamping_policy`     | Whether to stamp tagged field values before injection.                  |
| `with_context`        | Evaluate `path` elements within a struct of contextual data.            |
| `output_format`       | It should be one of `json`, `text`, or `yaml`.                          |
| `output_name`         | Output file name, including extension. Defaults to `<src_name>.json`.   |

### cue_library

```py
cue_library(name, srcs, import_path, deps=[])
```

Defines a collection of Cue files that can be depended on by a `cue_export`. Does not generate any outputs.

| Attribute             | Description                                                                                        |
|-----------------------|----------------------------------------------------------------------------------------------------|
| `name`                | Unique name for this rule (required).                                                              |
| `srcs`                | Entry-point files included in this library (required). Package name MUST match the directory name. |
| `import_path`         | The source import path of this library. Other CUE files can import this library using this path.  |
| `deps`                | Dependencies for the `srcs`. Each dependency is a `cue_library`.                                   |
| `concatenate_objects` | Concatenate multiple objects into a list.                                                          |
| `expression`          | CUE expression selecting a single value to export.                                                 |
| `inject`              | Keys and values of tagged fields.                                                                  |
| `inject_shorthand`    | Shorthand values of tagged fields.                                                                 |
| `merge_other_files`   | Merge non-CUE files.                                                                               |
| `path`                | Elements of CUE path at which to place top-level values.                                           |
| `stamping_policy`     | Whether to stamp tagged field values before injection.                                             |
| `with_context`        | Evaluate `path` elements within a struct of contextual data.                                       |

### Stamping

You can use [Bazel's "stamping" capability](https://docs.bazel.build/versions/master/user-manual.html#workspace_status) for the values supplied to the `inject` attribute accepted by both the `cue_export` and `cue_library` rules. When you enable stamping, these rules will replace any injected values that start with the '{' character and end with the '}' character with the corresponding value from either of the workspace's _bazel-out/stable-status.txt_ or _bazel-out/volatile-status.txt_ files. If there is no such value defined in either of those two files, the rules drop the tag from the injected set, as opposed to injecting it with an empty string as its value. For example, injecting the tag "at" with the value "{BUILD_TIMESTAMP}" will find the key "BUILD_TIMESTAMP" (stripped of its surrounding braces) in the file _bazel-out/volatile-status.txt_, and supply its corresponding value to the _cue_ tool via its `--inject` flag.

These two rules obey the same `stamping_policy` attribute, with a default value of "Allow," leaving it to Bazel's `--stamp` (or its negative companion, `--nostamp`) to control whether to stamp targets. By default, Bazel treats stamping as disabled, requiring one to opt in. The `stamping_policy` attributes accept two values in addition to the default "Allow":
- "Force": Stamp tagged field values unconditionally, even if Bazel's `--stamp` flag is inactive.
- "Prevent": Never stamp tagged field values, even if the Bazel's `--stamp` flag is active.

## Gazelle Extension

To use [Gazelle][gazelle] in your project to generate BUILD.bazel files for your CUE files, add Gazelle to your WORKSPACE, and then add the following to your repository root BUILD.bazel:

[gazelle]: https://github.com/bazelbuild/bazel-gazelle

```py
load("@bazel_gazelle//:def.bzl", "DEFAULT_LANGUAGES", "gazelle_binary", "gazelle")

gazelle_binary(
    name = "gazelle_binary",
    languages = DEFAULT_LANGUAGES + ["@com_github_tnarg_rules_cue//gazelle/cue"],
    visibility = ["//visibility:public"],
)

# gazelle:prefix github.com/example/project
gazelle(
    name = "gazelle",
    gazelle = "//:gazelle_binary",
)
```

Note that Gazelle will generate a separate `cue_export` target for each CUE file it finds with a ".cue" extension, even though it's possible to supply multiple input files—in CUE format or in other formats—to a `cue_export` target. Gazelle won't try to guess any further than this simple one-to-one mapping how those files should map to targets.
