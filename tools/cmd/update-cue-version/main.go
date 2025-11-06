package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"

	"golang.org/x/mod/semver"
)

const (
	usageExitCode = 2
	toolchainFile = "cue/private/tools/cue/toolchain.bzl"
)

func fatalln(code int, args ...interface{}) {
	fmt.Fprintln(os.Stderr, args...)
	os.Exit(code)
}

func fatalf(code int, format string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, format, args...)
	os.Exit(code)
}

func fetchChecksums(version string) (map[string]string, error) {
	cmd := exec.Command("gh", "release", "view", "--repo", "cue-lang/cue", version, "--json", "assets")
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("failed to execute gh command: %w\n%s", err, stderr.String())
	}

	var release struct {
		Assets []struct {
			Name   string `json:"name"`
			Digest string `json:"digest"`
		} `json:"assets"`
	}
	if err := json.Unmarshal(stdout.Bytes(), &release); err != nil {
		return nil, fmt.Errorf("failed to parse gh command output: %w", err)
	}

	checksums := make(map[string]string, 6)
	// cue_v0.14.1_linux_amd64.tar.gz -> linux, amd64
	re := regexp.MustCompile(`cue_` + regexp.QuoteMeta(version) + `_([a-z0-9]+)_([a-z0-9]+)\.(?:tar\.gz|zip)`)

	for _, asset := range release.Assets {
		matches := re.FindStringSubmatch(asset.Name)
		if len(matches) != 3 {
			continue
		}
		os, arch := matches[1], matches[2]
		key := fmt.Sprintf("struct(os = \"%s\", arch = \"%s\")", os, arch)
		sha := strings.TrimPrefix(asset.Digest, "sha256:")
		checksums[key] = sha
	}

	if len(checksums) == 0 {
		return nil, errors.New("failed to parse any checksums from gh command output")
	}

	return checksums, nil
}

func writeNewVersionEntry(w io.Writer, version string, checksums map[string]string) {
	fmt.Fprintf(w, "    \"%s\": {\n", version)
	// Order is important for consistency
	platforms := []string{
		`struct(os = "darwin", arch = "amd64")`,
		`struct(os = "darwin", arch = "arm64")`,
		`struct(os = "linux", arch = "amd64")`,
		`struct(os = "linux", arch = "arm64")`,
		`struct(os = "windows", arch = "amd64")`,
		`struct(os = "windows", arch = "arm64")`,
	}
	for _, p := range platforms {
		if sha, ok := checksums[p]; ok {
			fmt.Fprintf(w, "        %s: \"%s\",\n", p, sha)
		}
	}
	fmt.Fprintf(w, "    }") // No final newline here
}

func updateToolchainFile(toolchainFilePath, version string, checksums map[string]string) error {
	content, err := os.ReadFile(toolchainFilePath)
	if err != nil {
		return fmt.Errorf("failed to read %s: %w", toolchainFilePath, err)
	}

	var out bytes.Buffer

	updatedDefault := false
	inToolsByReleaseBlock := false
	versionSkipped := false // Flag to indicate if the current version's old entry was skipped

	scanner := bufio.NewScanner(bytes.NewReader(content))

	for scanner.Scan() {
		line := scanner.Text()

		// Update default version
		if !updatedDefault && strings.Contains(line, "_DEFAULT_TOOL_VERSION") {
			fmt.Fprintf(&out, "_DEFAULT_TOOL_VERSION = \"%s\"\n", version)
			updatedDefault = true
			continue
		}

		// Detect _TOOLS_BY_RELEASE block
		if strings.Contains(line, "_TOOLS_BY_RELEASE = {") {
			inToolsByReleaseBlock = true
			fmt.Fprintln(&out, line) // Write the `_TOOLS_BY_RELEASE = {` line
			writeNewVersionEntry(&out, version, checksums)
			fmt.Fprintln(&out, ",") // Add a comma after the new entry
			continue
		}

		// If inside _TOOLS_BY_RELEASE block, check for existing version entry
		if inToolsByReleaseBlock {
			// Skip the old entry for the current version
			if strings.Contains(line, fmt.Sprintf("\"%s\": {", version)) {
				versionSkipped = true
				for scanner.Scan() { // Skip lines until the end of the version block
					if strings.Contains(scanner.Text(), "},") || strings.Contains(scanner.Text(), "}") {
						break
					}
				}
				continue
			}

			// If it's a blank line, skip it
			if strings.TrimSpace(line) == "" {
				continue
			}

			// If it's the closing brace of the dictionary, and we skipped the version, don't add a comma
			if strings.Contains(line, "}") && versionSkipped {
				fmt.Fprintln(&out, line)
				inToolsByReleaseBlock = false
				continue
			}

			// Add a comma after each entry, except the last one
			if strings.Contains(line, "},") { // If it's an existing entry, keep its comma
				fmt.Fprintln(&out, line)
			} else if strings.Contains(line, "}") { // If it's the last entry, don't add a comma
				fmt.Fprintln(&out, line)
				inToolsByReleaseBlock = false
			} else { // Otherwise, add a comma
				fmt.Fprintln(&out, line)
			}
			continue
		}

		fmt.Fprintln(&out, line)
	}

	if !updatedDefault {
		return errors.New("failed to find _DEFAULT_TOOL_VERSION in toolchain.bzl")
	}

	return os.WriteFile(toolchainFilePath, out.Bytes(), 0o644)
}

func main() {
	workspaceDir := os.Getenv("BUILD_WORKSPACE_DIRECTORY")
	if workspaceDir == "" {
		fatalln(1, "BUILD_WORKSPACE_DIRECTORY environment variable not set. This tool must be run with 'bazel run'.")
	}
	toolchainFilePath := filepath.Join(workspaceDir, toolchainFile)

	version := flag.String("version", "", "The version of the CUE tool to update to, expressed as a semantic version.")
	flag.Parse()

	if *version == "" || !semver.IsValid(*version) {
		fatalf(usageExitCode, "A valid semantic version must be provided with -version.")
	}

	checksums, err := fetchChecksums(*version)
	if err != nil {
		fatalln(1, "failed to fetch checksums:", err)
	}

	if err := updateToolchainFile(toolchainFilePath, *version, checksums); err != nil {
		fatalln(1, "failed to update toolchain file:", err)
	}

	fmt.Printf("Successfully updated %s to version %s\n", toolchainFile, *version)
}
