package main

import (
	"bufio"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
)

const usageExitCode = 2

func fatalln(code int, args ...interface{}) {
	fmt.Fprintln(os.Stderr, args...)
	os.Exit(code)
}

func fatalf(code int, format string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, format, args...)
	os.Exit(code)
}

var (
	prohibitedPattern *regexp.Regexp
	once              sync.Once
)

// Adapted from https://github.com/alessio/shellescape/blob/v1.4.1/shellescape.go:
// (Avoid the dependency here.)
func quoteShellArg(s string) string {
	if len(s) == 0 {
		return "''"
	}
	once.Do(func() {
		prohibitedPattern = regexp.MustCompile(`[^\w@%+=:,./-]`)
	})
	if prohibitedPattern.MatchString(s) {
		return "'" + strings.ReplaceAll(s, "'", `'"'"'`) + "'"
	}
	return s
}

func readStampBindings(bindingFile string) (b map[string]string, err error) {
	f, err := os.Open(bindingFile)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil, fmt.Errorf("binding file %q does not exist", bindingFile)
		}
		var pe *os.PathError
		errors.As(err, &pe)
		return nil, fmt.Errorf("failed to determine whether binding file %q exists: %w", bindingFile, pe.Err)
	}
	defer func() {
		if ferr := f.Close(); ferr != nil && err == nil {
			err = ferr
			b = nil
		}
	}()

	// Basis of inspiration:
	// https://github.com/bazelbuild/rules_go/blob/4cd45a2ac59bd00ba54d23ebbdb7e5e2aed69007/go/tools/builders/link.go#L76-L97
	bindings := make(map[string]string, 10)
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.SplitN(scanner.Text(), " ", 2)
		switch len(line) {
		case 0:
			// Blank line
		case 1:
			// Empty binding
			bindings[line[0]] = ""
		case 2:
			bindings[line[0]] = line[1]
		}
	}
	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("failed reading binding file: %q: %w", bindingFile, err)
	}
	return bindings, nil
}

func replacePlaceholderValues(w io.Writer, r io.Reader, stampBindings map[string]string, prefix string) error {
	scanner := bufio.NewScanner(r)
	for scanner.Scan() {
		binding := scanner.Text()
		if len(binding) == 0 {
			continue
		}
		eq := strings.IndexByte(binding, '=')
		switch eq {
		case -1:
			return fmt.Errorf("placeholder line lacks '=': %q", binding)
		case 0:
			return fmt.Errorf("placeholder line has empty key: %q", binding)
		default:
			// Omit replacements for placeholders that match no stamp binding.
			if replacement, ok := stampBindings[binding[eq+1:]]; ok {
				fmt.Fprintf(w, "%s%s\n", prefix, quoteShellArg(binding[:eq]+"="+replacement))
			}
		}

	}
	return scanner.Err()
}

func replacePlaceholderValuesIn(placeholderFile string, w io.Writer, stampBindings map[string]string, prefix string) (err error) {
	consume := func(r io.Reader) error {
		return replacePlaceholderValues(w, r, stampBindings, prefix)
	}
	if placeholderFile == "-" {
		return consume(os.Stdin)
	}
	f, err := os.Open(placeholderFile)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return fmt.Errorf("placeholder file %q does not exist", placeholderFile)
		}
		var pe *os.PathError
		errors.As(err, &pe)
		return fmt.Errorf("failed to determine whether placeholder file %q exists: %w", placeholderFile, pe.Err)
	}
	defer func() {
		if ferr := f.Close(); ferr != nil && err == nil {
			err = ferr
		}
	}()
	return consume(f)
}

func main() {
	prefix := flag.String("prefix", "",
		"Prefix to insert before each emitted line of stamped replacements")
	output := flag.String("output", "",
		"`File path` to which to write output ('-' means standard output)")
	flag.Parse()
	args := flag.Args()

	switch len(args) {
	case 0:
		fatalf(usageExitCode, "%s: at least argument nominating the required replacement file is required.\n", os.Args[0])
	case 1:
		return
	}

	var stampBindings map[string]string
	for _, f := range args[1:] {
		overlay, err := readStampBindings(f)
		if err != nil {
			fatalln(1, err)
		}
		if stampBindings == nil {
			stampBindings = overlay
		} else {
			for k, v := range overlay {
				stampBindings[k] = v
			}
		}
	}

	replace := func(w io.Writer) error {
		return replacePlaceholderValuesIn(args[0], w, stampBindings, *prefix)
	}
	if *output == "" || *output == "-" {
		if err := replace(os.Stdout); err != nil {
			fatalln(1, err)
		}
		return
	}
	// Don't try writing to the directory reported by os.TempDir, as it's likely sitting within a
	// different filesystem from the directory containing the eventual output file. Our later
	// attempt to move a file (via os.Rename) between two different filesystems will fail. Instead,
	// write the temporary file as a sibling to the eventual output file.
	f, err := os.CreateTemp(filepath.Dir(*output), "replace-")
	if err != nil {
		fatalln(1, "failed to create temporary output file:", err)
	}
	if err := replace(f); err != nil {
		if rerr := os.Remove(f.Name()); rerr != nil {
			fmt.Fprintf(os.Stderr, "failed to delete temporary output file %q: %v\n", f.Name(), rerr)
		}
		fatalln(1, err)
	}
	if err := f.Close(); err != nil {
		fatalf(1, "failed to close temporary output file %q: %v\n", f.Name(), err)
	}
	if err := os.Rename(f.Name(), *output); err != nil {
		fatalf(1, "failed to move temporary output file %q to destination file %q: %v\n", f.Name(), *output, err)
	}
}
