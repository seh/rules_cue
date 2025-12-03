# Gazelle Example Summary

This example demonstrates the Gazelle integration for `rules_cue`, showing how to automatically generate Bazel BUILD files for CUE projects.

## What Was Created

### Project Structure

```
examples/gazelle/
├── .bazelversion              # Bazel version specification
├── .gitignore                 # Git ignore file for Bazel artifacts
├── MODULE.bazel               # Bazel module configuration with dependencies
├── BUILD.bazel                # Root BUILD with gazelle targets
├── README.md                  # Comprehensive documentation
├── QUICKSTART.md              # Quick start guide
├── SUMMARY.md                 # This file
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

## Key Features Demonstrated

### 1. Automatic BUILD File Generation

Gazelle automatically generates BUILD.bazel files for all CUE packages:

```bash
bazel run //:gazelle
```

This creates:
- `cue_module` rules for `cue.mod` directories
- `cue_instance` rules for each CUE package
- `cue_consolidated_instance` rules for consolidated output

### 2. Multiple Packages

The example includes three different CUE packages:
- **contacts**: Demonstrates schema validation with contact information
- **config**: Shows application configuration management
- **services/api**: Illustrates service API definitions

### 3. Verification

The `gazelle_check` target verifies BUILD files are up to date:

```bash
bazel run //:gazelle_check
```

This is useful for CI/CD pipelines to ensure developers haven't forgotten to run Gazelle.

### 4. Build Integration

All generated targets can be built with Bazel:

```bash
# Build everything
bazel build //...

# Build specific targets
bazel build //contacts:contacts_cue_def
bazel build //config:config_cue_def
bazel build //services/api:api_cue_def
```

## Generated Rules

### cue_module (in cue.mod/BUILD.bazel)

```python
load("@rules_cue//cue:cue.bzl", "cue_module")

cue_module(
    name = "cue.mod",
    visibility = ["//visibility:public"],
)
```

Defines the CUE module that other packages reference.

### cue_instance (in package BUILD.bazel files)

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

### cue_consolidated_instance (in package BUILD.bazel files)

```python
cue_consolidated_instance(
    name = "contacts_cue_def",
    instance = ":contacts_cue_instance",
    output_format = "cue",
    visibility = ["//visibility:public"],
)
```

Consolidates a CUE instance into a single output file with all values resolved.

## How It Works

1. **Language Extension**: The Gazelle CUE extension is implemented in `//gazelle/cue`
2. **Binary**: A custom `gazelle_binary` target includes the CUE extension
3. **Configuration**: The `gazelle()` rule in `BUILD.bazel` uses this custom binary
4. **Discovery**: Gazelle scans for `.cue` files and parses them
5. **Generation**: Based on package structure, it generates appropriate rules
6. **Resolution**: Dependencies between CUE packages are automatically resolved

## Benefits

1. **Zero Manual Maintenance**: BUILD files are generated automatically
2. **Consistency**: All CUE packages follow the same BUILD file pattern
3. **Type Safety**: CUE schema validation happens at build time
4. **CI Integration**: Can verify BUILD files are current in CI
5. **Hermetic Builds**: All dependencies are explicitly declared

## Customization

You can customize Gazelle behavior with directives in BUILD.bazel files:

```python
# Set import path prefix
# gazelle:prefix your.domain/your-project

# Change output format (json, yaml, text, cue)
# gazelle:cue_output_format yaml

# Enable golden file testing
# gazelle:cue_test_golden_suffix -golden.json
```

## Next Steps

1. Add more CUE packages to see Gazelle handle them automatically
2. Modify existing CUE files and re-run Gazelle to see incremental updates
3. Integrate with CI to ensure BUILD files stay in sync
4. Explore golden file testing for validation
5. Export to different formats (JSON, YAML) using directives

## Related Documentation

- [README.md](README.md) - Full documentation
- [QUICKSTART.md](QUICKSTART.md) - Quick start guide
- [rules_cue Documentation](https://github.com/abcue/rules_cue)
- [Gazelle Documentation](https://github.com/bazelbuild/bazel-gazelle)

