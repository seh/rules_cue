# Gazelle Example for rules_cue

This example demonstrates how to use [Gazelle](https://github.com/bazelbuild/bazel-gazelle) to automatically generate Bazel BUILD files for CUE code.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Usage](#usage)
- [Configuration](#configuration)
- [Generated Rules](#generated-rules)
- [Customization](#customization)
- [How It Works](#how-it-works)
- [Benefits](#benefits)
- [Common Issues](#common-issues)
- [Next Steps](#next-steps)
- [Learn More](#learn-more)

## Overview

Gazelle is a build file generator for Bazel projects. The `rules_cue` Gazelle extension can automatically generate:

- `cue_module` rules for `cue.mod` directories
- `cue_instance` rules for CUE packages
- `cue_consolidated_instance` rules for consolidated output
- `cue_exported_instance` rules for exporting to various formats

This example includes three different CUE packages demonstrating various use cases:
- **contacts**: Schema validation with contact information
- **config**: Application configuration management
- **services/api**: Service API definitions

## Quick Start

### Prerequisites

- Bazel 7.0 or later
- Basic familiarity with CUE

### Setup Steps

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

6. **Build and test:**

```bash
# Build everything
bazel build //...

# View the output
bazel build //config:config_cue_def
cat bazel-bin/config/config_cue_def.cue
```

## Project Structure

```
examples/gazelle/
├── .bazelversion              # Bazel version specification
├── .gitignore                 # Git ignore file for Bazel artifacts
├── MODULE.bazel               # Bazel module configuration with dependencies
├── BUILD.bazel                # Root BUILD with gazelle targets
├── README.md                  # This file
│
├── cue.mod/                   # CUE module definition
│   ├── module.cue             # Module metadata
│   └── BUILD.bazel            # Generated: cue_module rule
│
├── contacts/                  # Example: Contact management
│   ├── schema.cue             # Contact schema definition
│   ├── data.cue               # Contact data
│   └── BUILD.bazel            # Generated: cue_instance + cue_consolidated_instance
│
├── config/                    # Example: Application configuration
│   ├── app.cue                # Config schema
│   ├── defaults.cue           # Default configuration values
│   └── BUILD.bazel            # Generated: cue_instance + cue_consolidated_instance
│
└── services/                  # Example: Service definitions
    └── api/
        ├── spec.cue           # API specification schema
        ├── config.cue         # API service configuration
        └── BUILD.bazel        # Generated: cue_instance + cue_consolidated_instance
```

## Usage

### Generate BUILD files

To generate or update BUILD.bazel files for your CUE code:

```bash
bazel run //:gazelle
```

This will scan all `.cue` files in the project and generate appropriate Bazel rules.

### Verify BUILD files are up to date

To check if BUILD files are in sync with your CUE code (useful in CI):

```bash
bazel run //:gazelle_check
```

This is useful for CI/CD pipelines to ensure developers haven't forgotten to run Gazelle.

### Build targets

After generating BUILD files, you can build and test your CUE code:

```bash
# Build everything
bazel build //...

# Build specific targets
bazel build //contacts:contacts_cue_instance
bazel build //contacts:contacts_cue_def
bazel build //config:config_cue_def
bazel build //services/api:api_cue_def

# View the consolidated CUE output
cat bazel-bin/contacts/contacts_cue_def.cue
cat bazel-bin/services/api/api_cue_def.cue

# Run tests (if any)
bazel test //...
```

## Configuration

### Gazelle Directives

You can customize Gazelle behavior using directives in BUILD.bazel files:

```python
# Set the import path prefix
# gazelle:prefix github.com/example/project

# Control output format for CUE exports (json, yaml, text, or cue)
# gazelle:cue_output_format yaml

# Generate cue_exported_instance rules
# gazelle:cue_gen_exported_instance

# Configure golden file testing
# gazelle:cue_test_golden_suffix -golden.json
# gazelle:cue_test_golden_filename main-golden.json
```

### Example with Directives

```python
# In contacts/BUILD.bazel

# gazelle:cue_output_format yaml

# The rules below will be generated by Gazelle with YAML output
```

## Generated Rules

Gazelle automatically generates the following types of rules:

### cue_module

Generated in `cue.mod/BUILD.bazel`:

```python
load("@rules_cue//cue:cue.bzl", "cue_module")

cue_module(
    name = "cue.mod",
    visibility = ["//visibility:public"],
)
```

Defines the CUE module that other packages reference via the `ancestor` attribute.

### cue_instance

Generated for each CUE package:

```python
cue_instance(
    name = "contacts_cue_instance",
    srcs = [
        "data.cue",
        "schema.cue",
    ],
    ancestor = "//cue.mod:cue.mod",
    package_name = "contacts",
    visibility = ["//visibility:public"],
)
```

Represents a CUE package (instance) that can be validated and used as a dependency.

### cue_consolidated_instance

Generated to consolidate CUE instances to a single `.cue` file:

```python
cue_consolidated_instance(
    name = "contacts_cue_def",
    instance = ":contacts_cue_instance",
    output_format = "cue",
    visibility = ["//visibility:public"],
)
```

Consolidates a CUE instance into a single output file with all values resolved.

## Customization

### Modifying the Example

Try adding new CUE files or packages:

1. Create a new `.cue` file in any directory
2. Run `bazel run //:gazelle` to generate BUILD files
3. Build your new target: `bazel build //path/to/package:target_name`

**Example:** Create `inventory/products.cue`:

```cue
package inventory

#Product: {
    id:    string
    name:  string
    price: number & >0
}

products: [...#Product]
products: [
    {id: "001", name: "Widget", price: 9.99},
    {id: "002", name: "Gadget", price: 19.99},
]
```

Then run:

```bash
bazel run //:gazelle
bazel build //inventory:inventory_cue_instance
```

## How It Works

1. **Language Extension**: The Gazelle CUE extension is implemented in `//gazelle/cue`
2. **Binary**: A custom `gazelle_binary` target includes the CUE extension along with Go and Proto extensions
3. **Configuration**: The `gazelle()` rule in `BUILD.bazel` uses this custom binary
4. **Discovery**: Gazelle scans for `.cue` files and parses their package declarations and imports
5. **Generation**: Based on package structure, it generates appropriate `cue_instance` and `cue_consolidated_instance` rules
6. **Module Detection**: Automatically finds the nearest `cue.mod` directory and links it via the `ancestor` attribute
7. **Resolution**: Dependencies between CUE packages are automatically resolved

## Benefits

1. **Zero Manual Maintenance**: BUILD files are generated automatically from CUE code
2. **Consistency**: All CUE packages follow the same BUILD file pattern
3. **Type Safety**: CUE schema validation happens at build time
4. **CI Integration**: Can verify BUILD files are current in CI pipelines using `gazelle_check`
5. **Hermetic Builds**: All dependencies are explicitly declared and managed by Bazel
6. **Easy Updates**: Re-running Gazelle after code changes keeps BUILD files in sync

## Common Issues

### Gazelle not finding CUE files

Make sure your CUE files:
- Have the `.cue` extension
- Contain valid CUE code
- Have a package declaration (except for standalone files)

### Build failures after running Gazelle

If builds fail after running Gazelle:

1. Check that all CUE files in a package have the same package name
2. Verify imports are correct
3. Ensure `cue.mod/module.cue` exists if using module imports
4. Check that the `ancestor` attribute points to the correct `cue_module`

### Version mismatch warnings

If you see warnings about version mismatches between `go.mod` and `MODULE.bazel`, ensure both files specify the same version of Gazelle.

## Next Steps

### For This Example

1. Explore the three included packages (`contacts`, `config`, `services/api`)
2. Modify existing CUE files and re-run Gazelle to see incremental updates
3. Add new packages to see Gazelle handle them automatically
4. Try different output formats using `# gazelle:cue_output_format yaml`

### For Your Projects

1. **Integrate with CI**: Add `bazel run //:gazelle_check` to your CI pipeline to ensure BUILD files stay in sync
2. **Golden File Testing**: Explore `# gazelle:cue_test_golden_suffix` for validation tests
3. **Export to Multiple Formats**: Use directives to export to JSON, YAML, or text
4. **Complex Schemas**: Build larger CUE schemas with imports and dependencies
5. **Module Dependencies**: Add external CUE modules to `cue.mod/pkg/`

### Tips for Success

- Run `bazel run //:gazelle` whenever you add or modify CUE files
- Use `bazel run //:gazelle_check` in CI to verify BUILD files are up to date
- Generated BUILD files can be customized; Gazelle will preserve manual changes where possible
- Use directives to control Gazelle behavior per-package or per-file

## Learn More

### Documentation

- [Gazelle Documentation](https://github.com/bazelbuild/bazel-gazelle) - Official Gazelle documentation
- [rules_cue Documentation](https://github.com/abcue/rules_cue) - CUE rules for Bazel
- [CUE Language](https://cuelang.org/) - Official CUE language website

### Related Files

- `gazelle/cue/README.md` - Implementation details of the Gazelle CUE extension
- `.bazelversion` - Specifies the Bazel version for this example
- `MODULE.bazel` - Bazel module configuration with all dependencies
