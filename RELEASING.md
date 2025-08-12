# Releasing a New Version of the CUE Tool

This document outlines the steps required to update the `rules_cue` repository to support a new version of the CUE tool.

## 1. Identify the New Version

Identify the new version number of the CUE tool to be released (e.g., `v0.14.1`).

## 2. Update Toolchain Configuration

1.  **Fetch Checksums:** Download the `checksums.txt` file from the official `cue-lang/cue` GitHub release page for the new version. The URL will be in the format: `https://github.com/cue-lang/cue/releases/download/<version>/checksums.txt`.

2.  **Update `toolchain.bzl`:** Edit the file `cue/private/tools/cue/toolchain.bzl`:
    *   Add a new entry to the `_TOOLS_BY_RELEASE` dictionary for the new version. This entry will contain the SHA-256 hashes for each platform, which can be parsed from the `checksums.txt` file.
    *   Update the `_DEFAULT_TOOL_VERSION` variable to the new version string.

## 3. Test the Changes

Run the full test suite to ensure that the new tool version has not introduced any regressions. It is recommended to clean the cache before running the tests.

```bash
bazelisk clean
bazelisk test //...
```

## 4. Update Bazel Module Configuration

Ensure the Bazel module configuration is up to date by running the following command:

```bash
bazelisk mod deps --lockfile_mode=update
```

## 5. Commit the Changes

Commit the changes using `jj`. The commit message should follow the established convention in this repository.

*   **Headline:** `Update set of available CUE toolchain versions`
*   **Body:** `Introduce version <version>, establishing it as the new default.`

Example:
```
Update set of available CUE toolchain versions

Introduce version v0.14.1, establishing it as the new default.
```

## 6. Set Jujutsu Bookmark

Set the `update-cue-tool-versions` bookmark to the new commit.

```bash
jj bookmark set update-cue-tool-versions
```

## 7. Tag the Release

Create a PGP-signed, annotated Git tag for the new release.

*   **Tag Name:** The version number (e.g., `v0.14.1`).
*   **Tag Message:** The tag message should also follow the established convention.

Example command:
```bash
git tag -a v0.14.1 -m "Update set of available CUE toolchain versions

Introduce [version v0.14.1](https://github.com/cue-lang/cue/releases/tag/v0.14.1), establishing it as the new default." <commit_hash>
```

## 8. Update the `main` Branch

Force the `main` branch to point to the new release commit.

```bash
git branch -f main <commit_hash>
```
