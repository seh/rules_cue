package main

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"text/tabwriter"

	"cuelang.org/go/cue/build"
	"cuelang.org/go/cue/load"
	"github.com/spf13/pflag"
)

func fatalln(code int, args ...any) {
	fmt.Fprintln(os.Stderr, args...)
	os.Exit(code)
}

func fatalf(code int, format string, args ...any) {
	fmt.Fprintf(os.Stderr, format, args...)
	fmt.Fprintln(os.Stderr)
	os.Exit(code)
}

func main() {
	var (
		cueImportBaseDirectoryPath        string
		respectBazelBuildWorkingDirectory bool
		cueInstancesArgs                  []string
	)
	{
		flags := pflag.NewFlagSet("main", pflag.ContinueOnError)
		flags.Usage = func() {
			// Emulate pflag's "defaultUsage" function.
			fmt.Fprintf(os.Stderr, "Usage of %s:\n", filepath.Base(os.Args[0]))
			flags.PrintDefaults()
		}
		flags.StringVar(&cueImportBaseDirectoryPath, "import-base-path", "",
			`Directory path for CUE to use as its root for resolving imported packages`)
		flags.BoolVar(&respectBazelBuildWorkingDirectory, "respect-bazel-wd", false,
			`Whether to use the value Bazel's "BUILD_WORKING_DIRECTORY" variable as the working directory`)

		if err := flags.Parse(os.Args[1:]); err != nil {
			if errors.Is(err, pflag.ErrHelp) {
				// The pflag library will have already invoked our function to display the usage.
				return
			}
			flags.Usage()
			fatalln(2, err)
		}
		/*
			if len(cueImportBaseDirectoryPath) == 0 {
				fatalf(2, "base directory path for CUE import resolution must not be empty")
			}
		*/
		cueInstancesArgs = flags.Args()
	}

	if respectBazelBuildWorkingDirectory {
		if bwd, ok := os.LookupEnv("BUILD_WORKING_DIRECTORY"); ok && len(bwd) > 0 {
			cwd, err := os.Getwd()
			if err != nil {
				fatalf(1, "reading working directory: %v", err)
			}
			if bwd != cwd {
				if err := os.Chdir(bwd); err != nil {
					fatalf(1, "changing working directory: %v", err)
				}
			}
		}
	}

	instances := load.Instances(
		cueInstancesArgs,
		&load.Config{
			Dir: cueImportBaseDirectoryPath,
		})
	tw := tabwriter.NewWriter(os.Stdout, 2, 4, 1, ' ', 0)
	for _, inst := range instances {
		if err := inst.Err; err != nil {
			fmt.Fprintf(os.Stderr, "Failed to load instance: %v\n", err)
			continue
		}
		{
			packageDescription := "anonymous package"
			if name := inst.PkgName; len(name) > 0 {
				packageDescription = fmt.Sprintf("package %q", name)
			}
			fmt.Fprintf(tw, "Instance for %s:\n", packageDescription)
		}
		if p := inst.ImportPath; len(p) > 0 {
			fmt.Fprintf(tw, "\tImport Path:\t%s\t\n", p)
		}
		if m := inst.Module; len(m) > 0 {
			fmt.Fprintf(tw, "\tModule:\t%s\t\n", m)
		}
		fmt.Fprintf(tw, "\tRoot Directory:\t%s\t\n", inst.Root)
		fmt.Fprintf(tw, "\tPackage Directory:\t%s\t\n", inst.Dir)
		fmt.Fprintf(tw, "\tDisplay Path:\t%s\t\n", inst.DisplayPath)
		if is := inst.Imports; len(is) > 0 {
			fmt.Fprintln(tw, "\tDirect Imports:")
			for _, imp := range is {
				fmt.Fprint(tw, "\t\t", imp.DisplayPath)
				if m := imp.Module; m != inst.Module {
					fmt.Fprintf(tw, " (in other module %q)", m)
				}
				fmt.Fprintln(tw)
			}
		}
		if ips := inst.ImportPaths; len(ips) > 0 {
			fmt.Fprintln(tw, "\tImport Paths:")
			for _, p := range ips {
				fmt.Fprintf(tw, "\t\t%s\n", p)
			}
		}
		if deps := inst.Deps; len(deps) > 0 {
			fmt.Fprintln(tw, "\tDependencies:")
			for _, d := range deps {
				fmt.Fprintf(tw, "\t\t%s\n", d)
			}
		}
		fmt.Fprintf(tw, "\tComplete:\t%t\t\n", !inst.Incomplete)
		for _, spec := range []struct {
			kind  string
			files []*build.File
		}{
			{"Build", inst.BuildFiles},
			{"Ignored", inst.IgnoredFiles},
			{"Orphaned", inst.OrphanedFiles},
			{"Invalid", inst.InvalidFiles},
			{"Unknown", inst.UnknownFiles},
		} {
			if len(spec.files) == 0 {
				continue
			}
			fmt.Fprintf(tw, "\t%s Files:\n", spec.kind)
			for _, file := range spec.files {
				fmt.Fprint(tw, "\t\t", file.Filename)
				if f := file.Form; len(f) > 0 {
					fmt.Fprintf(tw, " (form %s)", f)
				}
				fmt.Fprintln(tw)
			}
		}
	}
	if err := tw.Flush(); err != nil {
		fatalf(1, "flushing tabwriter stream: %v", err)
	}
}
