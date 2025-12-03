# Quick Start Guide

This guide will get you up and running with Gazelle for CUE in just a few minutes.

## Prerequisites

- Bazel 7.0 or later
- Basic familiarity with CUE

## Quick Setup

1. **Add dependencies to your MODULE.bazel:**

```python
bazel_dep(name = "rules_cue", version = "0.0.0")
bazel_dep(name = "gazelle", version = "0.47.0")

# Set up Go dependencies for Gazelle CUE extension
go_deps = use_extension("@gazelle//:extensions.bzl", "go_deps")
go_deps.from_file(go_mod = "@rules_cue//:go.mod")
use_repo(
    go_deps,
    "com_github_iancoleman_strcase",
    "org_cuelang_go",
)
```

2. **Create a root BUILD.bazel file:**

```python
load("@gazelle//:def.bzl", "gazelle")

# gazelle:prefix your.domain/your-project

gazelle(
    name = "gazelle",
    gazelle = "@rules_cue//gazelle:gazelle_binary",
)
```

3. **Create a CUE module:**

```bash
mkdir -p cue.mod
cat > cue.mod/module.cue <<EOF
module: "your.domain/your-project"
language: version: "v0.15.1"
EOF
```

4. **Write some CUE code:**

```bash
mkdir config
cat > config/app.cue <<EOF
package config

#Config: {
    name:    string
    version: string
}

config: #Config & {
    name:    "myapp"
    version: "1.0.0"
}
EOF
```

5. **Generate BUILD files:**

```bash
bazel run //:gazelle
```

This will create `config/BUILD.bazel` with:

```python
load("@rules_cue//cue:cue.bzl", "cue_consolidated_instance", "cue_instance")

cue_instance(
    name = "config_cue_instance",
    srcs = ["app.cue"],
    ancestor = "//cue.mod:cue.mod",
    package_name = "config",
    visibility = ["//visibility:public"],
)

cue_consolidated_instance(
    name = "config_cue_def",
    instance = ":config_cue_instance",
    output_format = "cue",
    visibility = ["//visibility:public"],
)
```

6. **Build and test:**

```bash
# Build everything
bazel build //...

# View the output
bazel build //config:config_cue_def
cat bazel-bin/config/config_cue_def.cue
```

## Next Steps

- Add more CUE files and run `bazel run //:gazelle` to update BUILD files
- Configure output formats with `# gazelle:cue_output_format yaml`
- Set up golden file testing with `# gazelle:cue_test_golden_suffix`
- Read the full [README.md](README.md) for more details

## Tips

- Run `bazel run //:gazelle` whenever you add or modify CUE files
- Use `bazel run //:gazelle_check` in CI to verify BUILD files are up to date
- All generated BUILD files can be customized; Gazelle will preserve manual changes where possible

## Example Project Structure

```
your-project/
├── MODULE.bazel
├── BUILD.bazel              # Contains gazelle() target
├── cue.mod/
│   ├── module.cue
│   └── BUILD.bazel          # Generated
├── config/
│   ├── app.cue
│   └── BUILD.bazel          # Generated
└── services/
    ├── api/
    │   ├── spec.cue
    │   └── BUILD.bazel      # Generated
    └── database/
        ├── schema.cue
        └── BUILD.bazel      # Generated
```

