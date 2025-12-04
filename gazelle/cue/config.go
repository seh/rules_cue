package cuelang

import (
	"flag"
	"fmt"
	"go/build"
	"log"
	"path"
	"strings"

	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/rule"
)

type cueConfig struct {
	// prefix is a prefix of an import path, used to generate importpath
	// attributes. Set with -go_prefix or # gazelle:prefix.
	prefix    string
	prefixRel string

	// cueTestGoldenSuffix is the suffix used for golden test files in CUE tests.
	// This allows customizing the suffix for generated test files.
	// set with #gazelle:cue_test_golden_suffix <FILE_SUFFIX>
	// example: #gazelle:cue_test_golden_suffix -gen.yml
	cueTestGoldenSuffix string

	// cueTestGoldenFilename is the filename used for golden test files in CUE tests.
	// This allows specifying a custom filename for the golden test file.
	// set with #gazelle:cue_test_golden_filename <FILENAME>
	// example: #gazelle:cue_test_golden_filename main.gen.json
	cueTestGoldenFilename string

	// cueGenExportedInstance controls whether to generate cue_exported_instance rules
	// for each cue_instance. When true, a corresponding cue_exported_instance rule will be created.
	// #gazelle:cue_exported_instance
	cueGenExportedInstance bool

	// cueOutputFormat specifies the output format for CUE exports.
	// Valid values are "json", "yaml", and "text".
	// Default is "json" if not specified.
	cueOutputFormat string
}

// KnownDirectives returns a list of directive keys that this
// Configurer can interpret. Gazelle prints errors for directives that
// are not recognized by any Configurer.
func (s *cueLang) KnownDirectives() []string {
	return []string{"prefix", "cue_test_golden_suffix", "cue_test_golden_filename", "cue_output_format", "cue_gen_exported_instance"}
}

// RegisterFlags registers command-line flags used by the
// extension. This method is called once with the root configuration
// when Gazelle starts. RegisterFlags may set an initial values in
// Config.Exts. When flags are set, they should modify these values.
func (s *cueLang) RegisterFlags(fs *flag.FlagSet, cmd string, c *config.Config) {
	c.Exts[cueName] = &cueConfig{
		cueOutputFormat: "json", // Set default output format to json
	}
}

// CheckFlags validates the configuration after command line flags are
// parsed.  This is called once with the root configuration when
// Gazelle starts.  CheckFlags may set default values in flags or make
// implied changes.
func (s *cueLang) CheckFlags(fs *flag.FlagSet, c *config.Config) error {
	return nil
}

// Configure modifies the configuration using directives and other
// information extracted from a build file. Configure is called in
// each directory.
//
// c is the configuration for the current directory. It starts out as
// a copy of the configuration for the parent directory.
//
// rel is the slash-separated relative path from the repository root
// to the current directory. It is "" for the root directory itself.
//
// f is the build file for the current directory or nil if there is no
// existing build file.
func (s *cueLang) Configure(c *config.Config, rel string, f *rule.File) {
	var conf *cueConfig
	if raw, ok := c.Exts[cueName]; !ok {
		conf = &cueConfig{
			cueOutputFormat: "json", // Set default output format to json
		}
	} else {
		tmp := *(raw.(*cueConfig))
		conf = &tmp
	}
	c.Exts[cueName] = conf

	// We follow the same pattern as the go language to allow
	// vendoring of cue repositories.
	if path.Base(rel) == "vendor" {
		conf.prefix = ""
		conf.prefixRel = rel
	}

	if f != nil {
		for _, d := range f.Directives {
			switch d.Key {
			case "prefix":
				if err := checkPrefix(d.Value); err != nil {
					log.Print(err)
					return
				}
				conf.prefix = d.Value
				conf.prefixRel = rel
			case "cue_test_golden_suffix":
				conf.cueTestGoldenSuffix = d.Value
				// cue_test depends on exported instance
				conf.cueGenExportedInstance = true
			case "cue_test_golden_filename":
				// cue_test depends on exported instance
				conf.cueGenExportedInstance = true
				conf.cueTestGoldenFilename = d.Value
				conf.cueTestGoldenSuffix = strings.TrimPrefix(path.Ext(d.Value), ".")
			case "cue_gen_exported_instance":
				conf.cueGenExportedInstance = true
			case "cue_output_format":
				conf.cueOutputFormat = d.Value
			}
		}
	}
}

// checkPrefix checks that a string may be used as a prefix. We forbid local
// (relative) imports and those beginning with "/". We allow the empty string,
// but generated rules must not have an empty importpath.
func checkPrefix(prefix string) error {
	if strings.HasPrefix(prefix, "/") || build.IsLocalImport(prefix) {
		return fmt.Errorf("invalid prefix: %q", prefix)
	}
	return nil
}

// GetConfig returns the cueConfig from the provided config.Config
func GetConfig(c *config.Config) *cueConfig {
	if raw, ok := c.Exts[cueName]; ok {
		return raw.(*cueConfig)
	}
	return &cueConfig{
		cueOutputFormat: "json", // Set default output format to json
	}
}
