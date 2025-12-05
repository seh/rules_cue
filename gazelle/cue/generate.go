package cuelang

import (
	"fmt"
	"log"
	"os"
	"path"
	"path/filepath"
	"sort"
	"strings"

	"cuelang.org/go/cue/ast"
	"cuelang.org/go/cue/parser"
	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/language"
	"github.com/bazelbuild/bazel-gazelle/rule"
	"github.com/iancoleman/strcase"
)

// GenerateRules extracts build metadata from source files in a
// directory.  GenerateRules is called in each directory where an
// update is requested in depth-first post-order.
//
// args contains the arguments for GenerateRules. This is passed as a
// struct to avoid breaking implementations in the future when new
// fields are added.
//
// empty is a list of empty rules that may be deleted after merge.
//
// gen is a list of generated rules that may be updated or added.
//
// Any non-fatal errors this function encounters should be logged
// using log.Print.
func (cl *cueLang) GenerateRules(args language.GenerateArgs) language.GenerateResult {
	// Get the configuration
	conf := GetConfig(args.Config)

	// Parse CUE files
	cueFiles := parseCueFiles(args)
	if len(cueFiles) == 0 {
		return language.GenerateResult{}
	}

	// list cue_test golden files
	cueTestGoldenfiles, err := listGoldenFiles(args, conf.cueTestGoldenSuffix)
	if err != nil {
		log.Printf("error listing golden files: %v", err)
	}
	// Match golden files with their corresponding CUE files

	// Setup context for rule generation
	ctx := &ruleGenerationContext{
		config:                   conf,
		implicitPkgName:          path.Base(args.Rel),
		baseImportPath:           computeImportPath(args),
		isCueModDir:              path.Base(args.Dir) == "cue.mod",
		moduleLabel:              findNearestCueModule(args.Dir, args.Rel),
		instances:                make(map[string]*cueInstance),
		exportedFiles:            make(map[string]*cueExportedFiles),
		exportedInstances:        make(map[string]*cueExportedInstance),
		consolidatedInstances:    make(map[string]*cueConsolidatedInstance),
		exportedGoldenFiles:      make(map[string]*GoldenFile), // key: filename
		cueTestRules:             make(map[string]*cueTest),
		genConsolidatedInstances: true,
		genExportedInstances:     conf.cueGenExportedInstance,
	}

	// Process each CUE file
	for fname, cueFile := range cueFiles {
		pkg := cueFile.ast.PackageName()
		imports := extractImports(cueFile.ast)

		if conf.cueTestGoldenSuffix != "" {
			if gd, found := cueTestGoldenfiles[cueFile.rel]; found {
				// log.Printf("Found golden file %s for CUE file %s", gd.name, cueFile.rel)
				ctx.exportedGoldenFiles[gd.name] = gd
			}
		}

		if pkg == "" {
			processStandaloneFile(ctx, fname, imports)
		} else {
			processPackageFile(ctx, cueFile.rel, fname, pkg, imports)
		}
	}

	// Generate rules
	var res language.GenerateResult

	// Generate cue_module rule if in cue.mod directory
	// log.Printf("DEBUG dir: %s, args: %s\n, modelLabel: %s", args.Dir, args.Rel, ctx.moduleLabel)
	if ctx.isCueModDir {
		moduleRule := generateCueModuleRule(args.Rel)
		res.Gen = append(res.Gen, moduleRule)
	}

	// Generate all rules
	res.Gen = append(res.Gen, generateRules(ctx)...)

	// Set imports for dependency resolution
	res.Imports = make([]any, len(res.Gen))
	for i, r := range res.Gen {
		res.Imports[i] = r.PrivateAttr(config.GazelleImportsKey)
	}

	// Generate empty rules
	res.Empty = generateEmpty(args.File, ctx.isCueModDir, ctx.instances,
		ctx.exportedInstances, ctx.exportedFiles, ctx.consolidatedInstances, ctx.cueTestRules, ctx.exportedGoldenFiles)

	return res
}

// Context to hold all the data needed during rule generation
type ruleGenerationContext struct {
	config                   *cueConfig
	implicitPkgName          string
	baseImportPath           string
	isCueModDir              bool
	moduleLabel              string
	instances                map[string]*cueInstance
	exportedInstances        map[string]*cueExportedInstance
	exportedFiles            map[string]*cueExportedFiles
	cueTestRules             map[string]*cueTest
	exportedGoldenFiles      map[string]*GoldenFile
	consolidatedInstances    map[string]*cueConsolidatedInstance
	genExportedFiles         bool
	genExportedInstances     bool
	genConsolidatedInstances bool
}

// cueFile represents a CUE file with its AST and path information

// GoldenFile represents a golden file used in CUE tests
type GoldenFile struct {
	path string
	rel  string
	name string
}

// ListGoldenFiles finds all golden files in the given directory that match the configured suffix
// Returns a map of base name (without suffix) to GoldenFile
func listGoldenFiles(args language.GenerateArgs, goldenSuffix string) (map[string]*GoldenFile /*key: pth*/, error) {
	result := make(map[string]*GoldenFile)
	if goldenSuffix == "" {
		return result, nil
	}

	for _, f := range args.RegularFiles {
		if !strings.HasSuffix(f, goldenSuffix) {
			continue
		}
		// Extract base name without the golden suffix
		pth := filepath.Join(args.Dir, f)
		rel := args.Rel
		//NOTE(yuan): only supports one golden file per directory
		result[rel] = &GoldenFile{
			path: pth,
			rel:  rel,
			name: f,
		}
	}

	return result, nil
}

type cueFile struct {
	ast *ast.File
	rel string
	pth string
}

// Parse all CUE files in the directory
func parseCueFiles(args language.GenerateArgs) map[string]*cueFile {
	cueFiles := make(map[string]*cueFile)
	for _, f := range append(args.RegularFiles, args.GenFiles...) {
		// Only generate Cue entries for cue files (.cue)
		if !strings.HasSuffix(f, ".cue") {
			continue
		}

		pth := filepath.Join(args.Dir, f)
		a, err := parser.ParseFile(pth, nil)
		if err != nil {
			log.Printf("parsing cue file: path=%q, err=%+v", pth, err)
			continue
		}

		cueFiles[f] = &cueFile{
			ast: a,
			rel: args.Rel,
			pth: pth,
		}
	}
	return cueFiles
}

// Extract imports from a CUE file
func extractImports(cueFile *ast.File) []string {
	var imports []string
	for _, imprt := range cueFile.Imports {
		imports = append(imports, strings.Trim(imprt.Path.Value, "\""))
	}
	return imports
}

// Process a standalone CUE file (no package)
func processStandaloneFile(ctx *ruleGenerationContext, fname string, imports []string) {
	tgt := exportName(fname)

	// if exportedFiles inited, then process exported files
	if ctx.genExportedFiles {
		exportedFilesName := fmt.Sprintf("%s_cue_exported_files", tgt)
		exportedFile, ok := ctx.exportedFiles[exportedFilesName]
		if !ok {
			exportedFile = &cueExportedFiles{
				Name:         exportedFilesName,
				Module:       ctx.moduleLabel,
				Imports:      make(map[string]bool),
				Srcs:         []string{fname},
				OutputFormat: ctx.config.cueOutputFormat,
			}
			ctx.exportedFiles[exportedFilesName] = exportedFile
		}
		for _, imprt := range imports {
			exportedFile.Imports[imprt] = true
		}
	}
}

// Process a CUE file with a package
func processPackageFile(
	ctx *ruleGenerationContext,
	rel string, // relative path of cue file
	fname, pkg string,
	imports []string,
) {
	// Process instance
	instanceTgt := fmt.Sprintf("%s_cue_instance", pkg)
	instance, ok := ctx.instances[instanceTgt]

	if !ok {
		instance = &cueInstance{
			Name:         instanceTgt,
			PackageName:  pkg,
			Imports:      make(map[string]bool),
			Module:       ctx.moduleLabel,
			RelativePath: rel,
		}
		// find parent instance with prefix
		ctx.instances[instanceTgt] = instance
	}

	instance.Srcs = append(instance.Srcs, fname)
	for _, imprt := range imports {
		instance.Imports[imprt] = true
	}

	// Process exported files
	if ctx.genExportedFiles {
		exportedFilesName := fmt.Sprintf("%s_cue_exported_files", pkg)
		exportedFile, ok := ctx.exportedFiles[exportedFilesName]
		if !ok {
			exportedFile = &cueExportedFiles{
				Name:         exportedFilesName,
				Module:       ctx.moduleLabel,
				Imports:      make(map[string]bool),
				OutputFormat: ctx.config.cueOutputFormat,
			}
			ctx.exportedFiles[exportedFilesName] = exportedFile
		}

		for _, imprt := range imports {
			exportedFile.Imports[imprt] = true
		}

		if len(instance.Srcs) > 0 {
			exportedFile.Srcs = instance.Srcs
		}
	}

	if ctx.genConsolidatedInstances {
		// Process consolidated instance
		consolidatedName := fmt.Sprintf("%s_cue_def", pkg)
		consolidated, ok := ctx.consolidatedInstances[consolidatedName]
		if !ok {
			consolidated = &cueConsolidatedInstance{
				Name:        consolidatedName,
				Instance:    instanceTgt,
				PackageName: pkg,
				Imports:     make(map[string]bool),
			}
			ctx.consolidatedInstances[consolidatedName] = consolidated
		}
		for _, imprt := range imports {
			consolidated.Imports[imprt] = true
		}
	}
}

// Generate a cue_module rule
func generateCueModuleRule(rel string) *rule.Rule {
	cueModule := &cueModule{
		Name: "cue.mod",
	}
	moduleRule := cueModule.ToRule()

	// Register this cue_module for later use in resolution
	RegisterCueModule(fmt.Sprintf("//%s:cue.mod", rel), rel)

	return moduleRule
}

// genCueTestRule generates a cue_test rule for validating CUE code against golden files.
// It creates test rules that compare the output of CUE evaluation with expected results.
func genCueTestRule(ctx *ruleGenerationContext, tgt string, exportedFilesName string) {
	// NOTE(yuan): The cue_test rule will generate a target with suffix _test, so we use _cue as the target name
	// then the final target name will be %s_cue_test
	tn := fmt.Sprintf("%s_cue", tgt)
	if _, ok := ctx.cueTestRules[tn]; ok {
		return
	}
	goldenFileName := ctx.config.cueTestGoldenFilename
	if goldenFileName == "" {
		// If no golden file name is specified, get the first available golden file
		for _, gf := range ctx.exportedGoldenFiles {
			goldenFileName = gf.name
			break
		}
		if goldenFileName == "" {
			return
		}
	}

	if !strings.HasSuffix(goldenFileName, "."+ctx.config.cueOutputFormat) {
		// If the golden file doesn't have the correct output format extension,
		// break and skip this file as the formats don't match
		return
	}

	testRule := &cueTest{
		Name:                tn,
		GoldenFile:          ":" + goldenFileName,
		GeneratedOutputFile: ":" + exportedFilesName + "." + ctx.config.cueOutputFormat,
	}
	ctx.cueTestRules[tn] = testRule
}

// Generate all rules from the context
func generateRules(ctx *ruleGenerationContext) []*rule.Rule {
	var rules []*rule.Rule

	// Generate @rules_cue instance
	for _, instance := range ctx.instances {
		rules = append(rules, instance.ToRule())

		if ctx.genExportedInstances {
			if len(ctx.exportedGoldenFiles) == 0 {
				continue
			}
			// Create a cue_exported_instance rule for each instance
			exportedInstanceName := instance.Name + "_exported"
			if _, ok := ctx.exportedInstances[exportedInstanceName]; !ok {
				exportedInstance := &cueExportedInstance{
					Name:         exportedInstanceName,
					Instance:     instance.TargetName(),
					Imports:      instance.Imports,
					OutputFormat: ctx.config.cueOutputFormat,
				}
				ctx.exportedInstances[exportedInstanceName] = exportedInstance
				// Generate test rule if golden suffix or filename is specified
				// Log the exported golden files for debugging
				// Generate test rule if we have golden files and golden suffix or filename is configured
				if ctx.config.cueTestGoldenSuffix != "" || ctx.config.cueTestGoldenFilename != "" {
					genCueTestRule(ctx, instance.Name, exportedInstanceName)
				}
			}
		}
	}

	for _, exportedInstance := range ctx.exportedInstances {
		rules = append(rules, exportedInstance.ToRule())
	}

	for _, exportedFile := range ctx.exportedFiles {
		rules = append(rules, exportedFile.ToRule())
	}

	for _, consolidated := range ctx.consolidatedInstances {
		rules = append(rules, consolidated.ToRule())
	}

	for _, ts := range ctx.cueTestRules {
		rules = append(rules, ts.ToRule())
	}

	for _, es := range ctx.exportedGoldenFiles {
		r := rule.NewRule("cue_gen_golden", "golden_"+es.name)
		r.SetAttr("srcs", []string{es.name})
		rules = append(rules, r)
	}

	return rules
}

// findNearestCueModule searches for a cue.mod directory up the directory tree
// and returns the label to the cue_module rule.
func findNearestCueModule(dir, rel string) string {
	currentDir := dir
	currentRel := rel

	for {
		cueModPath := filepath.Join(currentDir, "cue.mod")
		if info, err := os.Stat(cueModPath); err == nil && info.IsDir() {
			if currentRel == "" || currentRel == "." {
				return "//cue.mod:cue.mod"
			}
			return fmt.Sprintf("//%s/cue.mod:cue.mod", currentRel)
		}

		// If we're at the root, we're done
		if currentRel == "" || currentRel == "." {
			break
		}

		// Move up one directory
		currentDir = filepath.Dir(currentDir)
		currentRel = filepath.Dir(currentRel)
		if currentRel == "." {
			currentRel = ""
		}
	}
	return ""
}

func computeImportPath(args language.GenerateArgs) string {
	conf := GetConfig(args.Config)

	suffix, err := filepath.Rel(conf.prefixRel, args.Rel)
	if err != nil {
		log.Printf("Failed to compute importpath: rel=%q, prefixRel=%q, err=%+v", args.Rel, conf.prefixRel, err)
		return args.Rel
	}
	if suffix == "." {
		return conf.prefix
	}

	return filepath.Join(conf.prefix, suffix)
}

func exportName(basename string) string {
	parts := strings.Split(basename, ".")
	return strcase.ToSnake(strings.Join(parts[:len(parts)-1], "_"))
}

func generateEmpty(
	f *rule.File,
	isCueModDir bool,
	instances map[string]*cueInstance,
	exportedInstances map[string]*cueExportedInstance,
	exportedFiles map[string]*cueExportedFiles,
	consolidatedInstances map[string]*cueConsolidatedInstance,
	cueTestRules map[string]*cueTest,
	goldenFiles map[string]*GoldenFile,
) []*rule.Rule {
	if f == nil {
		return nil
	}

	var empty []*rule.Rule

	// Helper function to check if a rule should be marked as empty
	checkAndMarkEmpty := func(kind, name string, exists bool) {
		if !exists {
			empty = append(empty, rule.NewRule(kind, name))
		}
	}

	for _, r := range f.Rules {
		kind := r.Kind()
		name := r.Name()

		switch kind {
		case "cue_library", "cue_export":
			// NOTE: mark all cue_library and cue_export as empty
			// since cue_library is depreacted
			checkAndMarkEmpty(kind, name, true)
		case "cue_instance":
			_, exists := instances[name]
			checkAndMarkEmpty(kind, name, exists)
		case "cue_consolidated_instance":
			if len(consolidatedInstances) > 0 {
				_, exists := consolidatedInstances[name]
				checkAndMarkEmpty(kind, name, exists)
			}
		case "cue_exported_instance", "cue_exported_standalone_files":
			if len(exportedInstances) > 0 {
				_, exists := exportedInstances[name]
				checkAndMarkEmpty(kind, name, exists)
			}
		case "cue_exported_files":
			if len(exportedFiles) > 0 {
				_, exists := exportedFiles[name]
				checkAndMarkEmpty(kind, name, exists)
			}
		case "cue_gen_golden":
			_, exists := goldenFiles[name]
			checkAndMarkEmpty(kind, name, exists)
		case "cue_test":
			_, exists := cueTestRules[name]
			checkAndMarkEmpty(kind, name, exists)
		case "cue_module":
			if !isCueModDir {
				checkAndMarkEmpty(kind, name, false)
			}
		}
		// Don't mark other rule types as empty
	}

	return empty
}

// @rules_cue rule types
type cueInstance struct {
	Name         string
	PackageName  string
	Srcs         []string
	Imports      map[string]bool
	RelativePath string
	Module       string // Reference to the nearest cue_module
}

func (ci *cueInstance) ToRule() *rule.Rule {
	rule := rule.NewRule("cue_instance", ci.Name)
	sort.Strings(ci.Srcs)
	rule.SetAttr("srcs", ci.Srcs)
	rule.SetAttr("package_name", ci.PackageName)
	rule.SetAttr("visibility", []string{"//visibility:public"})

	// set ancestor to module and update later after resolve
	if ci.Module != "" {
		rule.SetAttr("ancestor", ci.Module)
	}

	var deps []string
	for dep := range ci.Imports {
		deps = append(deps, dep)
	}
	sort.Strings(deps)
	rule.SetPrivateAttr(config.GazelleImportsKey, deps)
	return rule
}

// Implement TargetName method for cueInstance
func (ci *cueInstance) TargetName() string {
	return ci.Name
}

type cueExportedInstance struct {
	Name         string
	Instance     string
	Src          string
	Imports      map[string]bool
	OutputFormat string
}

func (cei *cueExportedInstance) ToRule() *rule.Rule {
	var r *rule.Rule
	if cei.Instance != "" {
		r = rule.NewRule("cue_exported_instance", cei.Name)
		r.SetAttr("instance", ":"+cei.Instance)
	} else {
		r = rule.NewRule("cue_exported_standalone_files", cei.Name)
		r.SetAttr("srcs", []string{cei.Src})
	}
	r.SetAttr("visibility", []string{"//visibility:public"})

	// Use the outputFormat field
	if cei.OutputFormat != "" {
		r.SetAttr("output_format", cei.OutputFormat)
	}

	return r
}

// cueExportedFiles represents a cue_exported_files rule that exports CUE files to various formats.
// It supports exporting multiple source files with configurable output formats, expressions, and injected values.
//
// Example:
// ```python
// cue_exported_files(
//
//	name = "config_exported",
//	module = ":cue.mod",
//	srcs = [
//	    "config.cue",
//	    "defaults.cue",
//	],
//	qualified_srcs = {
//	    "values.yaml": "yaml",
//	},
//	output_format = "yaml",
//	result = "config.yaml",
//	expression = "config",
//	inject = {
//	    "environment": "production",
//	    "version": "1.2.3",
//	},
//	inject_system_variables = True,
//	with_context = True,
//	visibility = ["//visibility:public"],
//
// )
type cueExportedFiles struct {
	Name         string
	Module       string
	Srcs         []string
	Imports      map[string]bool
	OutputFormat string
}

func (cef *cueExportedFiles) ToRule() *rule.Rule {
	r := rule.NewRule("cue_exported_files", cef.Name)
	r.SetAttr("module", cef.Module)
	r.SetAttr("visibility", []string{"//visibility:public"})
	r.SetAttr("srcs", cef.Srcs)

	// Use the outputFormat field
	if cef.OutputFormat != "" {
		r.SetAttr("output_format", cef.OutputFormat)
	}

	var imprts []string
	for imprt := range cef.Imports {
		imprts = append(imprts, imprt)
	}
	sort.Strings(imprts)
	r.SetPrivateAttr(config.GazelleImportsKey, imprts)
	return r
}

// Add cue_module type
type cueModule struct {
	Name string
}

func (cm *cueModule) ToRule() *rule.Rule {
	r := rule.NewRule("cue_module", cm.Name)
	r.SetAttr("visibility", []string{"//visibility:public"})
	return r
}

// cueConsolidatedInstance definition
type cueConsolidatedInstance struct {
	Name        string
	Instance    string
	Src         string
	PackageName string
	Imports     map[string]bool
}

func (cci *cueConsolidatedInstance) ToRule() *rule.Rule {
	var r *rule.Rule
	if cci.Instance != "" {
		r = rule.NewRule("cue_consolidated_instance", cci.Name)
		r.SetAttr("instance", ":"+cci.Instance)
	} else {
		r = rule.NewRule("cue_consolidated_standalone_files", cci.Name)
		r.SetAttr("srcs", []string{cci.Src})
	}
	r.SetAttr("visibility", []string{"//visibility:public"})

	// Always set output_format to "cue" for consolidated instances
	r.SetAttr("output_format", "cue")
	return r
}

// cueTest represents a CUE test rule that can be used to validate CUE code
// against expected outputs (golden files). It allows for testing CUE configurations
// and ensuring they produce the expected results when evaluated.
type cueTest struct {
	Name                string
	GoldenFile          string
	GeneratedOutputFile string
}

func (ct *cueTest) ToRule() *rule.Rule {
	r := rule.NewRule("cue_test", ct.Name)
	r.SetAttr("generated_output_file", ct.GeneratedOutputFile)
	r.SetAttr("golden_file", ct.GoldenFile)
	return r
}
