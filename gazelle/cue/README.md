# Gazelle CUE Language Support

This directory contains the Gazelle language extension for CUE, which enables automatic generation of Bazel BUILD files for CUE projects.

## Overview

The Gazelle CUE extension automatically generates:
- `cue_module` rules for `cue.mod` directories
- `cue_instance` rules for CUE packages
- `cue_consolidated_instance` rules for consolidated output
- `cue_exported_instance` rules for exports (with appropriate directives)
- `cue_test` rules for golden file testing (with appropriate directives)

## Usage

See the [examples/gazelle](../../examples/gazelle) directory for a complete working example.

### Quick Start

1. Add dependencies to your `MODULE.bazel`:

```python
bazel_dep(name = "rules_cue", version = "0.0.0")
bazel_dep(name = "gazelle", version = "0.47.0")

go_deps = use_extension("@gazelle//:extensions.bzl", "go_deps")
go_deps.from_file(go_mod = "@rules_cue//:go.mod")
use_repo(go_deps, "com_github_iancoleman_strcase", "org_cuelang_go")
```

2. Create a `BUILD.bazel` file with Gazelle target:

```python
load("@gazelle//:def.bzl", "gazelle")

gazelle(
    name = "gazelle",
    gazelle = "@rules_cue//gazelle:gazelle_binary",
)
```

3. Run Gazelle:

```bash
bazel run //:gazelle
```

## Directives

Configure Gazelle behavior with directives in BUILD files:

- `# gazelle:prefix <import-path>` - Set the import path prefix
- `# gazelle:cue_output_format <format>` - Set output format (json, yaml, text, cue)
- `# gazelle:cue_gen_exported_instance` - Generate cue_exported_instance rules
- `# gazelle:cue_test_golden_suffix <suffix>` - Enable golden file testing with suffix
- `# gazelle:cue_test_golden_filename <filename>` - Specify golden file name

## Implementation

The extension implements the `language.Language` interface from Gazelle:

- `config.go` - Configuration and directive handling
- `cue.go` - Language definition and rule kinds
- `generate.go` - Rule generation logic
- `resolve.go` - Dependency resolution

## Note

This implementation is based on https://github.com/tnarg/rules_cue/tree/master/gazelle/cue with enhancements for `@rules_cue` rules.