package main

import (
	"bufio"
	"bytes"
	"errors"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
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
	url := fmt.Sprintf("https://github.com/cue-lang/cue/releases/download/%s/checksums.txt", version)
	resp, err := http.Get(url)
	if err != nil {
		return nil, fmt.Errorf("failed to download checksums.txt: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("bad status getting checksums.txt: %s", resp.Status)
	}

	checksums := make(map[string]string)
	scanner := bufio.NewScanner(resp.Body)
	// cue_v0.14.1_linux_amd64.tar.gz -> linux, amd64
	re := regexp.MustCompile(`cue_` + regexp.QuoteMeta(version) + `_([a-z0-9]+)_([a-z0-9]+)\.(?:tar\.gz|zip)`)

	for scanner.Scan() {
		line := scanner.Text()
		parts := strings.Fields(line)
		if len(parts) != 2 {
			continue
		}
		sha, filename := parts[0], parts[1]
		matches := re.FindStringSubmatch(filename)
		if len(matches) != 3 {
			continue
		}
		os, arch := matches[1], matches[2]
		key := fmt.Sprintf("struct(os = \"%s\", arch = \"%s\")", os, arch)
		checksums[key] = sha
	}

	if len(checksums) == 0 {
		return nil, errors.New("failed to parse any checksums from checksums.txt")
	}

	return checksums, scanner.Err()
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
	fmt.Fprintln(w, "    },")
}

func updateToolchainFile(toolchainFilePath, version string, checksums map[string]string) error {
	content, err := os.ReadFile(toolchainFilePath)
	if err != nil {
		return fmt.Errorf("failed to read %s: %w", toolchainFilePath, err)
	}

	var out bytes.Buffer

	updatedDefault, updatedTools := false, false

	scanner := bufio.NewScanner(bytes.NewReader(content))

	for scanner.Scan() {
		line := scanner.Text()

		// Update default version
		if !updatedDefault && strings.Contains(line, "_DEFAULT_TOOL_VERSION") {
			fmt.Fprintf(&out, "_DEFAULT_TOOL_VERSION = \"%s\"\n", version)
			updatedDefault = true
			continue
		}

		// Add new version checksums
		if strings.Contains(line, "_TOOLS_BY_RELEASE = {") && !updatedTools {
			fmt.Fprintln(&out, line) // Write the `_TOOLS_BY_RELEASE = {` line
			writeNewVersionEntry(&out, version, checksums)
			updatedTools = true
			continue
		}

		fmt.Fprintln(&out, line)
	}

	if !updatedDefault || !updatedTools {
		return errors.New("failed to find update locations in toolchain.bzl")
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
